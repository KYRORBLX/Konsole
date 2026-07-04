--[[
	@name session
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

local imports = {
	ContextActionService = game:GetService("ContextActionService"),
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

imports.Panel.attach(Session)
imports.Suggestions.attach(Session)
imports.Hints.attach(Session)

local function cleanFieldText(value)
	return imports.Text.cleanStart((string.gsub(tostring(value or ""), "\t", "")))
end

local function handleActivationText(self, input)
	local text = tostring(input.Text or "")
	if self.suppressNextInputText and text ~= "" and os.clock() <= (self.suppressNextInputUntil or 0) then
		self.suppressNextInputText = false
		input.Text = ""
		return true
	end
	if self.suppressNextInputText and os.clock() > (self.suppressNextInputUntil or 0) then
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

	if imports.Text.callable(self.onActivationText) then
		task.defer(self.onActivationText)
	end

	return true
end

local function cloneHistory(items)
	local out = {}
	for index, item in items or {} do
		out[index] = {
			kind = item.kind,
			text = item.text,
			wide = item.wide == true,
		}
	end

	return out
end

local function bindInputAction(self)
	self.inputActionName = "KonsoleTerminalInput_" .. string.gsub(tostring(self), "%W", "")
	imports.ContextActionService:BindActionAtPriority(self.inputActionName, function(_, inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if not self.isExpanded or self.isClosing then
			return Enum.ContextActionResult.Pass
		end

		if inputObject.KeyCode == Enum.KeyCode.Tab then
			self:acceptSuggestion()
			return Enum.ContextActionResult.Sink
		end
		if inputObject.KeyCode == Enum.KeyCode.Down and self:moveSelection(1) then
			return Enum.ContextActionResult.Sink
		end
		if inputObject.KeyCode == Enum.KeyCode.Up and self:moveSelection(-1) then
			return Enum.ContextActionResult.Sink
		end
		if inputObject.KeyCode == Enum.KeyCode.Right and self:moveArgument(1) then
			return Enum.ContextActionResult.Sink
		end
		if inputObject.KeyCode == Enum.KeyCode.Left and self:moveArgument(-1) then
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end, false, 10000, Enum.KeyCode.Tab, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)
end

local function bindFieldChannel(self, input, channel)
	return input:GetPropertyChangedSignal("Text"):Connect(function()
		if handleActivationText(self, input) then
			return
		end

		local cleaned = cleanFieldText(input.Text)
		if input.Text ~= cleaned then
			input.Text = cleaned
			return
		end

		self.activeChannel = channel
		self:setPlaceholder(channel, cleaned == "")
		self:onCommandText(channel, cleaned)
		self:queueVisibleWidthRefresh()
	end)
end

local function bindGlobalInput(self)
	local refs = self.refs

	return imports.UserInputService.InputBegan:Connect(function(inputObject, processed)
		if self.isExpanded then
			if inputObject.KeyCode == Enum.KeyCode.Tab and self:acceptSuggestion() then
				return
			end
			if inputObject.KeyCode == Enum.KeyCode.Down and self:moveSelection(1) then
				return
			end
			if inputObject.KeyCode == Enum.KeyCode.Up and self:moveSelection(-1) then
				return
			end
			if inputObject.KeyCode == Enum.KeyCode.Right and self:moveArgument(1) then
				return
			end
			if inputObject.KeyCode == Enum.KeyCode.Left and self:moveArgument(-1) then
				return
			end
		end
		if processed then
			return
		end

		if inputObject.KeyCode == Enum.KeyCode.Escape then
			self:collapse()
			return
		end
		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 or not self.isExpanded then
			return
		end
		if refs.InputBox:IsFocused() or refs.SecondInputBox:IsFocused() then
			return
		end

		local point = imports.UserInputService:GetMouseLocation()
		local inTerminal = imports.View.pointIn(refs.pill, point)
			or imports.View.pointIn(refs.addChatPill, point)
			or imports.View.pointIn(refs.secondPill, point)
			or imports.View.pointIn(refs.suggList, point)
		if not inTerminal then
			self:collapse()
		elseif imports.View.pointIn(refs.secondPill, point) then
			self.activeChannel = 2
			refs.SecondInputBox:CaptureFocus()
		else
			self.activeChannel = 1
			refs.InputBox:CaptureFocus()
		end
	end)
end

local function bindRefs(self)
	local refs = self.refs
	local motion = self.config.motion

	local function track(connection)
		table.insert(self.connections, connection)
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
	track(refs.InputBox.Focused:Connect(function()
		self:releaseActiveChip(1)
	end))
	track(refs.SecondInputBox.Focused:Connect(function()
		self:releaseActiveChip(2)
	end))
	track(refs.InputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:submit(1)
		end
	end))
	track(refs.SecondInputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:submit(2)
		end
	end))
	track(bindFieldChannel(self, refs.InputBox, 1))
	track(bindFieldChannel(self, refs.SecondInputBox, 2))

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

	track(bindGlobalInput(self))
end

function Session.new(gui, config)
	if typeof(gui) ~= "Instance" then
		return nil
	end

	local self = setmetatable({
		config = config,
		refs = {},
		connections = {},
		suggestionSource = {},
		argSchemas = {},
		channelChips = {},
		hintConnections = {},
		hintKey = {},
		hintToken = 0,
		structured = {},
		commandWord = {},
		activeChip = nil,
		history = {},
		secondHistory = {},
		lineCache = {},
		historyDirty = { true, true },
		historyVersion = {},
		renderedVersion = {},
		measuredLineHeight = nil,
		hasOutput = false,
		hasSecondChat = false,
		hasSecondOutput = false,
		isExpanded = false,
		isClosing = false,
		isDestroying = false,
		activeChannel = 1,
		suggestToken = 0,
		currentSuggestions = {},
		selectedSuggestion = nil,
		suggestionQuery = "",
		suggestionsHiding = false,
		suggestionConnections = {},
		autoScroll = { true, true },
		savedScroll = { 0, 0 },
		syncingScroll = {},
		scrollSyncToken = {},
		refreshMeasuredToken = {},
		placeholderVisible = { false, false },
		addChatHover = false,
		layoutSeq = 0,
		layoutTargetWidth = nil,
		restoredWidth = nil,
		queuedWidth = nil,
		widthRefreshToken = 0,
		shadowQueued = false,
		stackShadowHiding = false,
		secondOpeningFromAdd = false,
		secondClosingToAdd = false,
		onSubmit = nil,
		onActivationText = nil,
		suppressActivation = false,
		suppressNextInputText = false,
		suppressNextInputUntil = 0,
		inputActionName = nil,
	}, Session)

	imports.View.createTree(self, gui)
	bindInputAction(self)
	bindRefs(self)

	imports.Reveal.prepare(self)
	task.defer(function()
		imports.Reveal.open(self)
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

	return self.activeChannel == 2 and self.refs.SecondInputBox or self.refs.InputBox
end

function Session:bindSubmit(fn)
	self.onSubmit = imports.Text.callable(fn) and fn or nil
end

function Session:bindActivationText(callback)
	self.onActivationText = imports.Text.callable(callback) and callback or nil
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
		if text ~= "" and not seen[text] then
			seen[text] = true
			table.insert(out, text)
		end
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
	local placeholder = channel == 2 and self.refs.SecondPlaceholder or self.refs.Placeholder
	if typeof(placeholder) ~= "Instance" or self.placeholderVisible[channel] == visible then
		return
	end

	self.placeholderVisible[channel] = visible
	if not visible then
		placeholder.TextTransparency = 1
		placeholder.Visible = false
		return
	end

	imports.Suggest.placeholder(self, placeholder, visible)
end

function Session:submit(channel)
	local input = channel == 2 and self.refs.SecondInputBox or self.refs.InputBox
	if typeof(input) ~= "Instance" then
		return
	end

	local text = imports.Text.trim(self:assembleCommand(channel))
	if text == "" then
		return
	end

	input.Text = ""
	self:exitStructured(channel)
	self:setPlaceholder(channel, true)
	self:hideSuggestions()
	self:hideHints(channel)
	if imports.Text.callable(self.onSubmit) then
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

	imports.Shape.expand(self)
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
	imports.Shape.collapse(self)

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

	channel = channel == 2 and 2 or 1
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
		history = cloneHistory(self.history),
		secondHistory = cloneHistory(self.secondHistory),
		hasOutput = self.hasOutput == true,
		hasSecondChat = self.hasSecondChat == true,
		hasSecondOutput = self.hasSecondOutput == true,
		activeChannel = self.activeChannel == 2 and 2 or 1,
		autoScroll = { self.autoScroll[1] ~= false, self.autoScroll[2] ~= false },
		scroll = { self.savedScroll[1] or 0, self.savedScroll[2] or 0 },
		width = self.layoutTargetWidth or self.restoredWidth or self:activeWidth(),
		inputText = {
			typeof(self.refs.InputBox) == "Instance" and self.refs.InputBox.Text or "",
			typeof(self.refs.SecondInputBox) == "Instance" and self.refs.SecondInputBox.Text or "",
		},
	}
end

function Session:restoreSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	self.history = cloneHistory(snapshot.history)
	self.secondHistory = cloneHistory(snapshot.secondHistory)
	self.hasOutput = snapshot.hasOutput == true or #self.history > 0
	self.hasSecondChat = snapshot.hasSecondChat == true or #self.secondHistory > 0
	self.hasSecondOutput = snapshot.hasSecondOutput == true or #self.secondHistory > 0
	self.activeChannel = snapshot.activeChannel == 2 and 2 or 1
	self.autoScroll = type(snapshot.autoScroll) == "table"
			and {
				snapshot.autoScroll[1] ~= false,
				snapshot.autoScroll[2] ~= false,
			}
		or { true, true }
	self.savedScroll = type(snapshot.scroll) == "table"
			and {
				tonumber(snapshot.scroll[1]) or 0,
				tonumber(snapshot.scroll[2]) or 0,
			}
		or { 0, 0 }
	self.restoredWidth = tonumber(snapshot.width)
	self.layoutTargetWidth = self.restoredWidth
	self.lineCache = {}
	self.renderedVersion = {}
	local inputText = type(snapshot.inputText) == "table" and snapshot.inputText or {}
	if typeof(self.refs.InputBox) == "Instance" then
		self.refs.InputBox.Text = tostring(inputText[1] or "")
		self.placeholderVisible[1] = nil
		self:setPlaceholder(1, self.refs.InputBox.Text == "")
	end
	if typeof(self.refs.SecondInputBox) == "Instance" then
		self.refs.SecondInputBox.Text = tostring(inputText[2] or "")
		self.placeholderVisible[2] = nil
		self:setPlaceholder(2, self.refs.SecondInputBox.Text == "")
	end
	self:markHistoryDirty(1)
	self:markHistoryDirty(2)
	if self.hasSecondChat and typeof(self.refs.SecondInputBox) == "Instance" then
		self.refs.SecondInputBox.Visible = true
	end

	task.defer(function()
		if self.refs then
			self:renderHistory(1)
			self:renderHistory(2)
			self:layoutStack(self.config.motion.outputSmoothTime or 0.24, self:activeWidth())
			task.defer(function()
				self.restoredWidth = nil
				self:queueWidthRefresh()
			end)
		end
	end)
end

local function appendItem(self, channel, item)
	channel = channel == 2 and 2 or 1
	if channel == 2 then
		self.hasSecondChat = true
		self.hasSecondOutput = true
	else
		self.hasOutput = true
	end

	self.autoScroll[channel] = true
	imports.History.append(channel == 2 and self.secondHistory or self.history, item)
	self:markHistoryDirty(channel)
	self:layoutStack(self.config.motion.outputSmoothTime)
	task.defer(function()
		if self.refs then
			imports.Slide.history(self, channel)
		end
	end)
	self:refreshMeasured(channel)
	self:queueVisibleWidthRefresh()
end

function Session:appendPending(text, channel)
	appendItem(self, channel, {
		kind = "cmd",
		text = tostring(text or ""),
	})
end

function Session:appendResult(result, channel)
	appendItem(self, channel, {
		kind = imports.History.resultKind(result),
		text = imports.History.resultText(result),
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
	imports.View.clearSuggestionConnections(self)
	if self.inputActionName then
		imports.ContextActionService:UnbindAction(self.inputActionName)
		self.inputActionName = nil
	end
	if typeof(self.refs.InputBox) == "Instance" then
		self.refs.InputBox:ReleaseFocus()
	end

	local cleanupDelay = imports.Reveal.close(self)
	task.delay(cleanupDelay, function()
		imports.View.clearSuggestionConnections(self)
		for _, connection in self.connections do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		self.connections = {}
		if self.refs.root then
			self.refs.root:Destroy()
		end
	end)
end

return Session
