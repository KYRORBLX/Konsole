--[[
	@name session
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

local imports = {
	UserInputService = game:GetService("UserInputService"),

	Reveal = require("../../motion/suggest/reveal"),
	Shape = require("../../motion/math/shape"),
	Slide = require("../../motion/math/slide"),

	Suggest = require("../../motion/suggest"),
	History = require("../backend/history"),
	Suggestions = require("./suggestions"),

	View = require("../misc/view"),
	Text = require("../misc/text"),
	Hints = require("./hints"),

	Panel = require("./panel"),
}

local Session = {}
Session.__index = Session

imports.Suggestions.attach(Session)
imports.Panel.attach(Session)
imports.Hints.attach(Session)

local UIS = imports.UserInputService
local Suggest = imports.Suggest
local History = imports.History
local Reveal = imports.Reveal
local Shape = imports.Shape
local Slide = imports.Slide
local View = imports.View
local Text = imports.Text

local function ch(value)
	return value == 2 and 2 or 1
end

local function mainBox(self, channel)
	return ch(channel) == 2 and self.refs.SecondInputBox or self.refs.InputBox
end

local function placeholder(self, channel)
	return ch(channel) == 2 and self.refs.SecondPlaceholder or self.refs.Placeholder
end

local function clean(value)
	return Text.cleanStart((string.gsub(tostring(value or ""), "\t", "")))
end

local function copyHistory(items)
	local out = {}
	for index, item in items or {} do
		out[index] = {
			wide = item.wide == true,
			kind = item.kind,
			text = item.text,
		}
	end
	return out
end

local function setRecall(self, channel, input, text)
	self:clearHintChips(channel)
	self.recallingCommand[channel] = true
	input.Text = text
	input.CursorPosition = #input.Text + 1
	input:CaptureFocus()
	task.defer(function()
		self.recallingCommand[channel] = nil
	end)
end

local function activationText(self, input)
	local text = tostring(input.Text or "")
	local suppressing = self.suppressNextInputText
	local untilTime = self.suppressNextInputUntil or 0

	if suppressing and text ~= "" and os.clock() <= untilTime then
		self.suppressNextInputText = false
		input.Text = ""
		return true
	end
	if suppressing and os.clock() > untilTime then
		self.suppressNextInputText = false
	end

	if not string.find(text, "`", 1, true) then
		return false
	end

	input.Text = string.gsub(text, "`", "")
	if self.suppressActivation then
		self.suppressActivation = false
		return true
	end
	if Text.callable(self.onActivationText) then
		task.defer(self.onActivationText)
	end
	return true
end

local function keyInput(self, input)
	if not self.isExpanded then
		return false
	end

	local key = input.KeyCode
	if key == Enum.KeyCode.Tab then
		return self:acceptSuggestion()
	elseif key == Enum.KeyCode.Down then
		return self:recallCommand(1) or self:moveSelection(1)
	elseif key == Enum.KeyCode.Up then
		return self:recallCommand(-1) or self:moveSelection(-1)
	elseif key == Enum.KeyCode.Right then
		return self:moveArgument(1)
	elseif key == Enum.KeyCode.Left then
		return self:moveArgument(-1)
	end
	return false
end

local function inShell(refs, point)
	return View.pointIn(refs.pill, point)
		or View.pointIn(refs.addChatPill, point)
		or View.pointIn(refs.secondPill, point)
		or View.pointIn(refs.suggList, point)
end

local function clickInput(self)
	local refs = self.refs
	local point = UIS:GetMouseLocation()

	if not inShell(refs, point) then
		if self.config.input.forceclose and Text.callable(self.onCloseRequest) then
			self.onCloseRequest()
		else
			self:collapse()
		end
		return
	end

	if View.pointIn(refs.secondPill, point) then
		self.activeChannel = 2
		refs.SecondInputBox:CaptureFocus()
	else
		self.activeChannel = 1
		refs.InputBox:CaptureFocus()
	end
end

local function bindText(self, input, channel)
	return input:GetPropertyChangedSignal("Text"):Connect(function()
		if activationText(self, input) then
			return
		end

		local text = clean(input.Text)
		if input.Text ~= text then
			input.Text = text
			return
		end

		self.activeChannel = channel
		if not self.recallingCommand[channel] then
			self.commandHistoryIndex[channel] = nil
			self.commandDraft[channel] = nil
		end

		self:setPlaceholder(channel, text == "")
		if self.recallingCommand[channel] then
			self:hideSuggestions()
			self:queueVisibleWidthRefresh()
			return
		end

		self:onCommandText(channel, text)
		self:queueVisibleWidthRefresh()
	end)
end

local function bindInput(self)
	local refs = self.refs

	return UIS.InputBegan:Connect(function(input, processed)
		if keyInput(self, input) then
			return
		end
		if processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			self:collapse()
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not self.isExpanded then
			return
		end
		if not self.config.input.forceclose and (refs.InputBox:IsFocused() or refs.SecondInputBox:IsFocused()) then
			return
		end

		clickInput(self)
	end)
end

local function bindRefs(self)
	local refs = self.refs
	local motion = self.config.motion

	local function track(conn)
		table.insert(self.connections, conn)
	end

	track(refs.pillBtn.Activated:Connect(function()
		self:expand()
	end))

	track(refs.addChatPill.MouseEnter:Connect(function()
		self:setAddChatHover(true)
	end))
	track(refs.addChatPill.MouseLeave:Connect(function()
		self:setAddChatHover(false)
	end))
	track(refs.addChatPill.Activated:Connect(function()
		if self.hasSecondChat then
			return
		end

		self.secondOpeningFromAdd = true
		self.addChatHover = false
		self.hasSecondChat = true
		self.activeChannel = 2
		self:hideSuggestions()
		self:layoutStack(motion.openSmoothTime or motion.expandSmoothTime)
		task.defer(function()
			refs.SecondInputBox.Visible = true
			refs.SecondInputBox.Text = ""
			self.placeholderVisible[2] = true
			refs.SecondInputBox:CaptureFocus()
		end)
	end))

	for channel, input in { refs.InputBox, refs.SecondInputBox } do
		track(input.Focused:Connect(function()
			self:releaseActiveChip(channel)
		end))
		track(input.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				self:submit(channel)
			end
		end))
		track(bindText(self, input, channel))
	end

	for _, signal in
		{
			refs.pill:GetPropertyChangedSignal("Size"),
			refs.pill:GetPropertyChangedSignal("Position"),
			refs.addChatPill:GetPropertyChangedSignal("Size"),
			refs.secondPill:GetPropertyChangedSignal("Size"),
			refs.suggList:GetPropertyChangedSignal("Size"),
		}
	do
		track(signal:Connect(function()
			self:queueShadowUpdate()
		end))
	end

	for channel, row in { refs.commandRow, refs.secondCommandRow } do
		track(row:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if self.syncingScroll[channel] then
				return
			end
			self.autoScroll[channel] = false
			self.savedScroll[channel] = row.CanvasPosition.Y
			self:renderHistory(channel)
			self:queueVisibleWidthRefresh()
		end))
	end

	track(bindInput(self))
end

local function baseState(config)
	return {
		connections = {},
		config = config,
		refs = {},

		suggestionSource = {},
		hintConnections = {},
		channelChips = {},
		argSchemas = {},

		commandWord = {},
		activeChip = nil,
		structured = {},
		hintToken = 0,
		hintKey = {},

		historyDirty = { true, true },
		commandHistory = { {}, {} },
		commandHistoryIndex = {},
		measuredLineHeight = nil,
		recallingCommand = {},
		renderedVersion = {},
		historyVersion = {},
		secondHistory = {},
		commandDraft = {},
		lineCache = {},
		history = {},

		hasSecondOutput = false,
		hasSecondChat = false,
		isDestroying = false,
		isExpanded = false,
		hasOutput = false,
		isClosing = false,
		activeChannel = 1,

		suggestionConnections = {},
		currentSuggestions = {},
		selectedSuggestion = nil,
		suggestionsHiding = false,
		suggestionQuery = "",
		suggestToken = 0,

		placeholderVisible = { false, false },
		autoScroll = { true, true },
		savedScroll = { 0, 0 },
		refreshMeasuredToken = {},
		scrollSyncToken = {},
		syncingScroll = {},

		secondOpeningFromAdd = false,
		secondClosingToAdd = false,
		layoutTargetWidth = nil,
		stackShadowHiding = false,
		widthRefreshToken = 0,
		addChatHover = false,
		restoredWidth = nil,
		shadowQueued = false,
		queuedWidth = nil,
		layoutSeq = 0,

		suppressNextInputUntil = 0,
		suppressNextInputText = false,
		suppressActivation = false,
		onActivationText = nil,
		onCloseRequest = nil,
		onSubmit = nil,
	}
end	

function Session.new(gui, config)
	if typeof(gui) ~= "Instance" then
		return nil
	end

	local self = setmetatable(baseState(config), Session)
	View.createTree(self, gui)
	bindRefs(self)

	Reveal.prepare(self)
	task.defer(function()
		Reveal.open(self)
		self.placeholderVisible[1] = self.refs.InputBox.Text == ""
		self:updateShadows()
	end)

	return self
end

function Session:activeInput()
	local chip = self.activeChip
	if chip and chip.channel == self.activeChannel and typeof(chip.box) == "Instance" and chip.box.Parent then
		return chip.box
	end
	return mainBox(self, self.activeChannel)
end

function Session:bindSubmit(fn)
	self.onSubmit = Text.callable(fn) and fn or nil
end

function Session:bindActivationText(fn)
	self.onActivationText = Text.callable(fn) and fn or nil
end

function Session:bindCloseRequest(fn)
	self.onCloseRequest = Text.callable(fn) and fn or nil
end

function Session:suppressNextActivationText()
	self.suppressActivation = true
	self.suppressNextInputText = true
	self.suppressNextInputUntil = os.clock() + 0.12
end

function Session:setSuggestions(list)
	local seen = {}
	local out = {}

	local function push(value)
		local text = tostring(value or "")
		if text == "" or seen[text] then
			return
		end
		seen[text] = true
		table.insert(out, text)
	end

	for _, item in type(list) == "table" and list or {} do
		push(item)
	end
	for alias, target in self.config.commands.aliases or {} do
		push(alias)
		push(target)
	end

	table.sort(out)
	self.suggestionSource = out
end

function Session:setPlaceholder(channel, visible)
	channel = ch(channel)
	local label = placeholder(self, channel)
	if typeof(label) ~= "Instance" or self.placeholderVisible[channel] == visible then
		return
	end

	self.placeholderVisible[channel] = visible
	if not visible then
		label.TextTransparency = 1
		label.Visible = false
		return
	end

	Suggest.placeholder(self, label, visible)
end

function Session:pushCommandHistory(channel, text)
	channel = ch(channel)
	text = tostring(text or "")
	if text == "" then
		return
	end

	local list = self.commandHistory[channel]
	if type(list) ~= "table" then
		list = {}
		self.commandHistory[channel] = list
	end
	if list[#list] ~= text then
		table.insert(list, text)
	end
	self.commandHistoryIndex[channel] = nil
	self.commandDraft[channel] = nil
end

function Session:recallCommand(delta)
	local channel = ch(self.activeChannel)
	if self.activeChip and self.activeChip.channel then
		channel = ch(self.activeChip.channel)
	end
	if self.structured[channel] then
		return false
	end

	local input = mainBox(self, channel)
	local chipFocused = self.activeChip and self.activeChip.channel == channel
	if typeof(input) ~= "Instance" or (not input:IsFocused() and not chipFocused) then
		return false
	end

	local list = self.commandHistory[channel]
	if type(list) ~= "table" or #list == 0 then
		return false
	end

	local index = self.commandHistoryIndex[channel]
	if index == nil then
		if delta > 0 then
			return false
		end
		self.commandDraft[channel] = self:assembleCommand(channel)
		index = #list
	elseif delta < 0 then
		index = math.max(1, index - 1)
	else
		index += 1
		if index > #list then
			self.commandHistoryIndex[channel] = nil
			setRecall(self, channel, input, tostring(self.commandDraft[channel] or ""))
			return true
		end
	end

	self.commandHistoryIndex[channel] = index
	setRecall(self, channel, input, list[index])
	return true
end

function Session:submit(channel)
	channel = ch(channel)
	local input = mainBox(self, channel)
	if typeof(input) ~= "Instance" then
		return
	end

	local text = Text.trim(self:assembleCommand(channel))
	if text == "" then
		return
	end

	self:pushCommandHistory(channel, text)
	input.Text = ""
	self:exitStructured(channel)
	self:setPlaceholder(channel, true)
	self:hideSuggestions()
	self:hideHints(channel)
	if Text.callable(self.onSubmit) then
		self.onSubmit(text, channel)
	end
	task.defer(function()
		if typeof(input) == "Instance" then
			input:CaptureFocus()
		end
	end)
end

function Session:expand()
	if self.isExpanded or self.isClosing then
		return
	end

	self.isExpanded = true
	self.isClosing = false
	self.refs.InputBox.Visible = true
	self.refs.pillBtn.Visible = false
	if not self.hasSecondChat then
		self.activeChannel = 1
	end

	Shape.expand(self)
	task.defer(function()
		local input = self:activeInput()
		if typeof(input) == "Instance" then
			input.Visible = true
			input:CaptureFocus()
		end
	end)
end

function Session:collapse()
	if not self.isExpanded then
		return
	end

	self:saveScroll()
	self.isClosing = true
	self.isExpanded = false
	self:hideSuggestions()
	self:hideHints()
	Shape.collapse(self)

	task.delay(self.config.motion.textFadeTime * 0.55, function()
		if not self.isExpanded and typeof(self.refs.InputBox) == "Instance" then
			self.refs.InputBox.Visible = false
			self:setPlaceholder(1, self.refs.InputBox.Text == "")
		end
	end)
	task.delay(self.config.motion.collapseSmoothTime, function()
		if not self.isExpanded and typeof(self.refs.pillBtn) == "Instance" then
			self.refs.pillBtn.Visible = true
			self.isClosing = false
		end
	end)
end

function Session:focus()
	task.defer(function()
		if self.refs then
			self:expand()
		end
	end)
end

function Session:getCursorTarget()
	local input = self:activeInput()
	if typeof(input) == "Instance" and input.Parent and input.Visible then
		return input
	end
	if typeof(self.refs.pillBtn) == "Instance" and self.refs.pillBtn.Parent then
		return self.refs.pillBtn
	end
	return nil
end

function Session:clear(channel)
	if channel == nil then
		self.history = {}
		self.secondHistory = {}
		self.hasOutput = false
		self.hasSecondChat = false
		self.hasSecondOutput = false
		self.lineCache = {}
		self.renderedVersion = {}
		self.autoScroll = { true, true }
		self.savedScroll = { 0, 0 }
		self:markHistoryDirty(1)
		self:markHistoryDirty(2)
		self:exitStructured(1)
		self:exitStructured(2)
		self.activeChannel = 1
		self:layoutStack(self.config.motion.collapseSmoothTime or self.config.motion.outputSmoothTime)
		return
	end

	channel = ch(channel)
	if channel == 2 then
		self.secondHistory = {}
		self.hasSecondOutput = false
	else
		self.history = {}
		self.hasOutput = false
		if not self.hasSecondOutput then
			self.hasSecondChat = false
		end
	end

	self.lineCache = {}
	self.renderedVersion = {}
	self.autoScroll[channel] = true
	self.savedScroll[channel] = 0
	self:markHistoryDirty(channel)
	self:renderHistory(channel)
	self:exitStructured(channel)
	self.activeChannel = channel
	self:layoutStack(self.config.motion.collapseSmoothTime or self.config.motion.outputSmoothTime)
end

function Session:closeSecond()
	self.secondHistory = {}
	self.commandHistory[2] = {}
	self.commandHistoryIndex[2] = nil
	self.commandDraft[2] = nil
	self.secondClosingToAdd = true
	self.hasSecondChat = false
	self.hasSecondOutput = false
	self.lineCache[2] = nil
	self.renderedVersion[2] = nil
	self.autoScroll[2] = true
	self.savedScroll[2] = 0
	self:markHistoryDirty(2)
	self:renderHistory(2)
	self:exitStructured(2)
	self.activeChannel = 1
	self:hideSuggestions()
	self:hideHints(2)
	self:layoutStack(self.config.motion.collapseSmoothTime or self.config.motion.outputSmoothTime)
end

function Session:snapshot()
	return {
		history = copyHistory(self.history),
		secondHistory = copyHistory(self.secondHistory),
		commandHistory = {
			table.clone(self.commandHistory[1] or {}),
			table.clone(self.commandHistory[2] or {}),
		},
		hasOutput = self.hasOutput == true,
		hasSecondChat = self.hasSecondChat == true,
		hasSecondOutput = self.hasSecondOutput == true,
		activeChannel = ch(self.activeChannel),
		autoScroll = { self.autoScroll[1] ~= false, self.autoScroll[2] ~= false },
		scroll = { self.savedScroll[1] or 0, self.savedScroll[2] or 0 },
		width = self.layoutTargetWidth or self.restoredWidth or self:activeWidth(),
		inputText = {
			typeof(self.refs.InputBox) == "Instance" and self.refs.InputBox.Text or "",
			typeof(self.refs.SecondInputBox) == "Instance" and self.refs.SecondInputBox.Text or "",
		},
	}
end

function Session:restoreSnapshot(data)
	if type(data) ~= "table" then
		return
	end

	self.history = copyHistory(data.history)
	self.secondHistory = copyHistory(data.secondHistory)
	self.commandHistory = type(data.commandHistory) == "table"
			and {
				table.clone(data.commandHistory[1] or {}),
				table.clone(data.commandHistory[2] or {}),
			}
		or { {}, {} }
	self.commandHistoryIndex = {}
	self.commandDraft = {}
	self.hasOutput = data.hasOutput == true or #self.history > 0
	self.hasSecondChat = data.hasSecondChat == true or #self.secondHistory > 0
	self.hasSecondOutput = data.hasSecondOutput == true or #self.secondHistory > 0
	self.activeChannel = ch(data.activeChannel)
	self.autoScroll = type(data.autoScroll) == "table"
			and {
				data.autoScroll[1] ~= false,
				data.autoScroll[2] ~= false,
			}
		or { true, true }
	self.savedScroll = type(data.scroll) == "table"
			and {
				tonumber(data.scroll[1]) or 0,
				tonumber(data.scroll[2]) or 0,
			}
		or { 0, 0 }
	self.restoredWidth = tonumber(data.width)
	self.layoutTargetWidth = self.restoredWidth
	self.lineCache = {}
	self.renderedVersion = {}

	local inputText = type(data.inputText) == "table" and data.inputText or {}
	for channel = 1, 2 do
		local input = mainBox(self, channel)
		if typeof(input) == "Instance" then
			input.Text = tostring(inputText[channel] or "")
			self.placeholderVisible[channel] = nil
			self:setPlaceholder(channel, input.Text == "")
		end
	end

	self:markHistoryDirty(1)
	self:markHistoryDirty(2)
	if self.hasSecondChat and typeof(self.refs.SecondInputBox) == "Instance" then
		self.refs.SecondInputBox.Visible = true
	end

	task.defer(function()
		if not self.refs then
			return
		end
		self:renderHistory(1)
		self:renderHistory(2)
		self:layoutStack(self.config.motion.outputSmoothTime or 0.24, self:activeWidth())
		task.defer(function()
			self.restoredWidth = nil
			self:queueWidthRefresh()
		end)
	end)
end

local function append(self, channel, item)
	channel = ch(channel)
	if channel == 2 then
		self.hasSecondChat = true
		self.hasSecondOutput = true
	else
		self.hasOutput = true
	end

	self.autoScroll[channel] = true
	History.append(channel == 2 and self.secondHistory or self.history, item)
	self:markHistoryDirty(channel)
	self:layoutStack(self.config.motion.outputSmoothTime)
	task.defer(function()
		if self.refs then
			Slide.history(self, channel)
		end
	end)
	self:refreshMeasured(channel)
	self:queueVisibleWidthRefresh()
end

function Session:appendPending(text, channel)
	append(self, channel, {
		kind = "cmd",
		text = tostring(text or ""),
	})
end

function Session:appendResult(result, channel)
	append(self, channel, {
		kind = History.resultKind(result),
		text = History.resultText(result),
		wide = type(result) == "table" and result.width == "wide",
	})
end

function Session:destroy()
	self.isClosing = true
	self.isExpanded = false
	self.isDestroying = true
	self.shadowQueued = false
	self.stackShadowHiding = true
	self:hideSuggestions()
	View.clearSuggestionConnections(self)

	for _, input in { self.refs.InputBox, self.refs.SecondInputBox } do
		if typeof(input) == "Instance" then
			input:ReleaseFocus()
		end
	end

	local delay = Reveal.close(self)
	task.delay(delay, function()
		View.clearSuggestionConnections(self)
		for _, conn in self.connections do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		self.connections = {}
		if self.refs.root then
			self.refs.root:Destroy()
		end
	end)
end

return Session
