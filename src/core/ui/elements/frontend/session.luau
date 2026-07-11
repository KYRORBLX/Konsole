--[[
	@name session
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--// imports
local imports = {
    UserInputService = game:GetService("UserInputService"),

    Dragging = require("../../motion/math/dragging"),
    Reveal = require("../../motion/suggest/reveal"),
    Shape = require("../../motion/math/shape"),
    Slide = require("../../motion/math/slide"),
    Tween = require("../../motion/math/tween"),

    Suggest = require("../../motion/suggest"),
    History = require("../backend/history"),
    Suggestions = require("./suggestions"),

    View = require("../misc/view"),
    Text = require("../misc/text"),
    Hints = require("./hints"),

    Panel = require("./panel"),
}

--// locals
local userInputService = imports.UserInputService
local Dragging = imports.Dragging
local Suggest = imports.Suggest
local History = imports.History

local Reveal = imports.Reveal
local Shape = imports.Shape
local Slide = imports.Slide
local Tween = imports.Tween

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

local function shifted(position, offset)
    return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + offset)
end

local function setDraggingEnabled(self, enabled)
    local refs = self.refs

    refs.mainDragging.setEnabled(enabled)
    refs.secondDragging.setEnabled(enabled and self.hasSecondChat)
end

local function syncAttachedSecond(self)
    if self.secondDetached or not self.hasSecondChat then
        return
    end

    local position = self.refs.root.Position

    self.refs.secondRoot.Position = position
    self.secondRootPosition = position
end

local function detachSecond(self)
    if self.secondDetached or not self.hasSecondChat then
        return
    end

    local refs = self.refs
    local width = self.layoutTargetWidth or refs.root.Size.X.Offset
    
    local secondWidth = self:activeWidth(2)
    
    local rootPosition = refs.root.Position
    local duration = self.config.motion.outputSmoothTime

    local stackExtra = self:stackExtra()

    self.secondDetached = true
    self.secondLayoutTargetWidth = secondWidth
 
    refs.secondRoot.Visible = true
    refs.secondPill.Visible = true

    refs.secondPill.BackgroundTransparency = refs.addChatPill.BackgroundTransparency

    refs.secondDragging.setPosition(rootPosition)

    local mainPosition = shifted(rootPosition, -stackExtra)

    Tween.to(refs.root, { Position = mainPosition }, duration)

    if typeof(refs.secondShadow) == "Instance" then
        refs.secondShadow.ImageTransparency = refs.stackShadow.ImageTransparency
        View.setShadowBounds(refs.secondShadow, refs.secondPill)
    end

    refs.stackShadow.Visible = false
    refs.addChatPill.Visible = false

    self:layoutStack(duration, width)
    self:placeSuggestions()

    Shape.layoutDetachedSecond(self, duration, secondWidth)
end

local function attachAddChat(self, savedMainPosition)
    if not self.isExpanded then
        return
    end

    local refs = self.refs
    local mainPosition = savedMainPosition or refs.root.Position

    if not self.hasOutput then
        refs.mainDragging.setPosition(mainPosition)
        return
    end

    local width = self.layoutTargetWidth or refs.root.Size.X.Offset
    local panel = self.config.panel

    local stackExtra = panel.height + (panel.stackGap or 8)

    refs.root.Size = UDim2.fromOffset(width, refs.pill.Size.Y.Offset + stackExtra)

    refs.pillBtn.Position = UDim2.new(0.5, 0, 1, -stackExtra)
    refs.pill.Position = UDim2.new(0.5, 0, 1, -stackExtra)

    local rootPosition = shifted(mainPosition, stackExtra)

    refs.mainDragging.setPosition(rootPosition)
end

local function setRecall(self, channel, input, text)
    self:clearHintChips(channel)

    self.recallingCommand[channel] = true

    input.CursorPosition = #input.Text + 1
    input.Text = text

    input:CaptureFocus()

    task.defer(function()
        self.recallingCommand[channel] = nil
    end)
end

local function activationText(self, input)
    local text = tostring(input.Text or "")

    local untilTime = self.suppressNextInputUntil or 0
    local suppressing = self.suppressNextInputText

    if suppressing and os.clock() <= untilTime then
        self.suppressNextInputText = false

        if #text == 1 then
            input.Text = ""
            return true
        end

        self.suppressActivation = false

        return false
    end

    if suppressing and os.clock() > untilTime then
        self.suppressNextInputText = false

        self.suppressActivation = false
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
        return self:moveSelection(1) or self:recallCommand(1)

    elseif key == Enum.KeyCode.Up then
        return self:moveSelection(-1) or self:recallCommand(-1)

    elseif key == Enum.KeyCode.Right then
        return self:moveArgument(1)

    elseif key == Enum.KeyCode.Left then
        return self:moveArgument(-1)
    end

    return false
end

local function inShell(refs, point)

    return View.pointIn(refs.pill, point)
        or View.pointIn(refs.suggList, point)
        or View.pointIn(refs.secondPill, point)
        or View.pointIn(refs.addChatPill, point)

end

local function clickInput(self)
    local refs = self.refs
    local point = userInputService:GetMouseLocation()

    if not inShell(refs, point) then
        if self.config.input.forceclose and Text.callable(self.onCloseRequest) then
            self.onCloseRequest()

        else
            self:collapse()
        end

        return
    end

    if View.pointIn(refs.commandRow, point) or View.pointIn(refs.secondCommandRow, point) then
        local focused = userInputService:GetFocusedTextBox()

        if focused then
            focused:ReleaseFocus()
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

            self:queueVisibleWidthRefresh(channel)
            self:hideSuggestions()

            return
        end

        self:onCommandText(channel, text)

        self:queueVisibleWidthRefresh(channel)
    end)
end

local function bindInput(self)
    local refs = self.refs

    return userInputService.InputBegan:Connect(function(input, processed)
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

    refs.mainDragging = Dragging.attach(refs.root, { refs.commandRow }, function(position)
        self.rootPosition = position
    end)

    refs.secondDragging = Dragging.attach(refs.secondRoot, { refs.secondCommandRow }, function(position)
        self.secondRootPosition = position
    end, function()

        detachSecond(self)
    end)

    track(refs.root:GetPropertyChangedSignal("Position"):Connect(function()
        syncAttachedSecond(self)
    end))

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

        self:hideSuggestions()

        self.secondDetached = false
        self.addChatHover = false
        self.hasSecondChat = true

        refs.secondRoot.Visible = true
        refs.secondPill.Visible = true

        refs.secondRoot.Position = refs.root.Position
        refs.secondRoot.Size = refs.addChatPill.Size


        refs.secondPill.BackgroundTransparency = refs.addChatPill.BackgroundTransparency
        refs.secondPill.Size = refs.addChatPill.Size

        self.secondRootPosition = refs.root.Position
        self.activeChannel = 2

        refs.secondPill.Position = UDim2.new(0.5, 0, 1, 0)

        setDraggingEnabled(self, true)

        self:layoutStack(motion.openSmoothTime or motion.expandSmoothTime)

        task.defer(function()
            self.placeholderVisible[2] = true

            refs.SecondInputBox.Visible = true
            refs.SecondInputBox.Text = ""

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
            refs.addChatPill:GetPropertyChangedSignal("Size"),
            refs.secondPill:GetPropertyChangedSignal("Size"),
            refs.pill:GetPropertyChangedSignal("Position"),

            refs.suggList:GetPropertyChangedSignal("Size"),
            refs.pill:GetPropertyChangedSignal("Size"),
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

            self.savedScroll[channel] = row.CanvasPosition.Y
            self.autoScroll[channel] = false

            self:renderHistory(channel)

            self:queueVisibleWidthRefresh(channel)
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
        secondDetached = false,
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

        layoutTargetWidth = nil,
        secondLayoutTargetWidth = nil,
        secondRootPosition = nil,
        rootPosition = nil,

        secondShadowHiding = false,
        stackShadowHiding = false,
        widthRefreshToken = 0,
        secondWidthRefreshToken = 0,

        addChatHover = false,
        restoredWidth = nil,
        shadowQueued = false,

        queuedWidth = nil,
        secondQueuedWidth = nil,
        layoutSeq = 0,

        suppressNextInputUntil = 0,
        suppressNextInputText = false,
        suppressActivation = false,

        onActivationText = nil,
        onCloseRequest = nil,
        onSubmit = nil,
    }
end

local function append(self, channel, item)
    channel = ch(channel)

    if channel == 2 then
        if not self.hasSecondChat then
            
            self.secondDetached = false
            self.hasSecondChat = true

            syncAttachedSecond(self)
        end

        self.hasSecondOutput = true
    else
        self.hasOutput = true
    end

    self.autoScroll[channel] = true

    History.append(channel == 2 and self.secondHistory or self.history, item)

    self:markHistoryDirty(channel)

    if channel == 2 and self.secondDetached then
        Shape.layoutDetachedSecond(self, self.config.motion.outputSmoothTime)
    else
        self:layoutStack(self.config.motion.outputSmoothTime)
    end

    task.defer(function()
        if self.refs then
            Slide.history(self, channel)
        end
    end)

    self:refreshMeasured(channel)

    self:queueVisibleWidthRefresh(channel)
end

--// public api
local Session = {}
Session.__index = Session

imports.Suggestions.attach(Session)
imports.Panel.attach(Session)
imports.Hints.attach(Session)

function Session.new(gui, config, rootPosition, secondRootPosition)
    if typeof(gui) ~= "Instance" then
        return nil
    end

    local self = setmetatable(baseState(config), Session)

    if typeof(rootPosition) == "UDim2" then
        self.rootPosition = rootPosition
    end

    if typeof(secondRootPosition) == "UDim2" then
        self.secondRootPosition = secondRootPosition
    end

    View.createTree(self, gui)
    bindRefs(self)

    Reveal.prepare(self)

    task.defer(function()
        Reveal.open(self)

        self.placeholderVisible[1] = self.refs.InputBox.Text == ""
        self:updateShadows()

        task.delay(self.config.motion.openSmoothTime or self.config.motion.expandSmoothTime, function()
            if self.isDestroying or not self.refs then
                return
            end

            setDraggingEnabled(self, true)
        end)
    end)

    return self
end

function Session:activeInput()
    local chip = if Text.callable(self.focusedChip) then self:focusedChip() else self.activeChip

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
        push(target)
        push(alias)
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

    local chipFocused = self.activeChip and self.activeChip.channel == channel
    local input = mainBox(self, channel)

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

    self:setPlaceholder(channel, true)
    self:exitStructured(channel)
    self:hideHints(channel)

    self:hideSuggestions()

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
    
    self.refs.pillBtn.Visible = false
    self.isClosing = false

    self.refs.InputBox.Visible = true
    self.isExpanded = true
    

    if not self.hasSecondChat then
        self.activeChannel = 1
    end

    local duration = self.config.motion.expandSmoothTime
    local rootPosition = typeof(self.rootPosition) == "UDim2" and self.rootPosition or self.refs.root.Position

    Tween.to(self.refs.root, { Position = rootPosition }, duration)

    if self.hasSecondChat then
        local secondPosition = self.secondDetached
                and (typeof(self.secondRootPosition) == "UDim2" and self.secondRootPosition or self.refs.secondRoot.Position)
            or rootPosition

        self.secondRootPosition = secondPosition

        Tween.to(self.refs.secondRoot, { Position = secondPosition }, duration)
    end

    Shape.expand(self)

    if self.secondDetached and self.hasSecondChat then
        Shape.layoutDetachedSecond(self, duration, self:activeWidth(2))
    end

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

    self.isExpanded = false
    self.isClosing = true

    self:hideSuggestions()
    self:saveScroll()
    self:hideHints()

    local input = self.refs.InputBox
    local empty = input.Text == ""

    input.Visible = not empty

    self:setPlaceholder(1, empty)
    Shape.collapse(self)

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
        self.renderedVersion = {}
        self.secondHistory = {}
        self.lineCache = {}
        self.history = {}
        
        self.hasSecondOutput = false
        self.secondDetached = false
        self.hasSecondChat = false
        self.hasOutput = false
       
        self.secondLayoutTargetWidth = nil
        self.secondQueuedWidth = nil
        
        self.autoScroll = { true, true }
        self.savedScroll = { 0, 0 }

        self:markHistoryDirty(1)
        self:markHistoryDirty(2)

        self:exitStructured(1)
        self:exitStructured(2)

        self.activeChannel = 1

        setDraggingEnabled(self, true)

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
            self.secondDetached = false
        end
    end

    self.renderedVersion = {}
    self.lineCache = {}

    self.autoScroll[channel] = true
    self.savedScroll[channel] = 0

    self:markHistoryDirty(channel)
    self:renderHistory(channel)

    self:exitStructured(channel)
    self.activeChannel = channel

    setDraggingEnabled(self, true)

    local duration = self.config.motion.collapseSmoothTime or self.config.motion.outputSmoothTime

    if channel == 2 and self.secondDetached then
        Shape.layoutDetachedSecond(self, duration)
    else
        self:layoutStack(duration)
    end
end

function Session:closeSecond()
    local mainPosition = self.refs.root.Position

    if not self.secondDetached then
        mainPosition = shifted(mainPosition, -self:stackExtra())
    end

    self.commandHistory[2] = {}
    self.secondHistory = {}

    self.hasSecondOutput = false
    self.secondDetached = false
    self.hasSecondChat = false
    
    self.secondLayoutTargetWidth = nil
    self.secondQueuedWidth = nil

    self.commandHistoryIndex[2] = nil
    self.renderedVersion[2] = nil
    self.commandDraft[2] = nil
    self.lineCache[2] = nil

    self.autoScroll[2] = true
    self.savedScroll[2] = 0

    self.activeChannel = 1

    self:markHistoryDirty(2)
    self:exitStructured(2)
    self:renderHistory(2)

    self:hideSuggestions()
    self:hideHints(2)

    attachAddChat(self, mainPosition)

    setDraggingEnabled(self, true)

    self:layoutStack(self.config.motion.collapseSmoothTime or self.config.motion.outputSmoothTime)
end

function Session:snapshot()
    return {
        secondHistory = copyHistory(self.secondHistory),
        commandHistory = {
            table.clone(self.commandHistory[1] or {}),
            table.clone(self.commandHistory[2] or {}),
        },
        history = copyHistory(self.history),

        hasSecondOutput = self.hasSecondOutput == true,
        secondDetached = self.secondDetached == true,
        hasSecondChat = self.hasSecondChat == true,

        activeChannel = ch(self.activeChannel),
        hasOutput = self.hasOutput == true,

        autoScroll = { self.autoScroll[1] ~= false, self.autoScroll[2] ~= false },
        secondPosition = self.secondRootPosition,
        position = self.rootPosition,

        inputText = {
            typeof(self.refs.InputBox) == "Instance" and self.refs.InputBox.Text or "",
            typeof(self.refs.SecondInputBox) == "Instance" and self.refs.SecondInputBox.Text or "",
        },

        width = self.layoutTargetWidth or self.restoredWidth or self:activeWidth(),
        scroll = { self.savedScroll[1] or 0, self.savedScroll[2] or 0 },
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

    self.secondDetached = if type(data.secondDetached) == "boolean" then data.secondDetached else self.hasSecondChat
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

    if typeof(data.position) == "UDim2" then
        self.rootPosition = data.position
    end

    if typeof(data.secondPosition) == "UDim2" then
        self.secondRootPosition = data.secondPosition
    end

    if self.hasSecondChat and not self.secondDetached and typeof(self.rootPosition) == "UDim2" then
        self.secondRootPosition = self.rootPosition
    end

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

        task.defer(function()
            self.restoredWidth = nil

            self:queueWidthRefresh()

            if self.secondDetached then
                self:queueWidthRefresh(2)
            end
        end)
    end)
end

function Session:appendPending(text, channel)
    append(self, channel, {
        text = tostring(text or ""),
        kind = "cmd",
    })
end

function Session:appendResult(result, channel)
    append(self, channel, {
        wide = type(result) == "table" and result.width == "wide",

        kind = History.resultKind(result),
        text = History.resultText(result),
    })
end

function Session:destroy()

    self.stackShadowHiding = true
    self.isDestroying = true
    self.isClosing = true

    self.shadowQueued = false
    self.isExpanded = false

    self:hideSuggestions()

    View.clearSuggestionConnections(self)

    setDraggingEnabled(self, false)

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

        if self.refs.secondRoot then
            self.refs.secondRoot:Destroy()
        end
    end)
end

return Session
