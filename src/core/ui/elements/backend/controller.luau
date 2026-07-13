--[[
	@name controller
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--// imports
local imports = {
    ContextActionService = game:GetService("ContextActionService"),
    UserInputService = game:GetService("UserInputService"),
    TextChatService = game:GetService("TextChatService"),
    Players = game:GetService("Players"),

    Session = require("../frontend/session"),
    Text = require("../misc/text"),
    Result = require("./result"),
}

--// locals
local serial = 0

local function keyList(keys)
    local out = {}

    for _, key in keys or {} do
        if typeof(key) == "EnumItem" then
            table.insert(out, key)
        end
    end

    return out
end

local function typingKey(key)
    return utf8.len(imports.UserInputService:GetStringForKeyCode(key)) == 1
end

local function bindActivation(self)
    imports.ContextActionService:UnbindAction(self.toggleActionName)

    if #self.activationKeys == 0 then
        return
    end

    imports.ContextActionService:BindActionAtPriority(
        self.toggleActionName,
        function(_, inputState, input)
            if inputState ~= Enum.UserInputState.Begin or not self.enabled then
                return Enum.ContextActionResult.Pass
            end

            if imports.UserInputService:GetFocusedTextBox() and not self.open and typingKey(input.KeyCode) then
                return Enum.ContextActionResult.Pass
            end

            self:toggle()

            return Enum.ContextActionResult.Sink
        end,
        false,
        
        self.config.input.activationPriority,
        table.unpack(self.activationKeys)
    )
end

--// public api
local Controller = {}
Controller.__index = Controller

function Controller.new(config)
    serial += 1

    local input = config.input

    local self = setmetatable({
        
        previousChatWindowEnabled = nil,
        previousMouseIconEnabled = nil,
        previousChatInputEnabled = nil,
        
        previousMouseBehavior = nil,
        previousMouseUnlocked = nil,
        mouseUnlockGet = nil,
        
        mouseUnlockSet = nil,
        savedSession = nil,
        session = nil,
        
        runner = nil,
        gui = nil,
        
        activationKeys = keyList(input.activationKeys),
        toggleActionName = `KonsoleToggle_{serial}`,
        
        activationUnlocksMouse = false,
        enabled = true,
        open = false,
        
        config = config,
        
        suggestions = {},
        schemas = {},
 
    }, Controller)

    bindActivation(self)

    return self
end

function Controller:setChatSuppressed(enabled)
    pcall(function()
        local chatWindow = imports.TextChatService.ChatWindowConfiguration
        local chatInput = imports.TextChatService.ChatInputBarConfiguration

        if enabled then
            if self.previousChatWindowEnabled == nil then
                self.previousChatWindowEnabled = chatWindow.Enabled
            end

            if self.previousChatInputEnabled == nil then
                self.previousChatInputEnabled = chatInput.Enabled
            end

            chatWindow.Enabled = false
            chatInput.Enabled = false

            return
        end

        if self.previousChatWindowEnabled ~= nil then
            chatWindow.Enabled = self.previousChatWindowEnabled
        end

        if self.previousChatInputEnabled ~= nil then
            chatInput.Enabled = self.previousChatInputEnabled
        end

        self.previousChatWindowEnabled = nil
        self.previousChatInputEnabled = nil
    end)
end

function Controller:readMouseUnlocked()
    if imports.Text.callable(self.mouseUnlockGet) then
        local ok, value = pcall(self.mouseUnlockGet)

        if ok and type(value) == "boolean" then
            return value
        end
    end

    return imports.UserInputService.MouseBehavior == Enum.MouseBehavior.Default
end

function Controller:writeMouseUnlocked(enabled)
    if imports.Text.callable(self.mouseUnlockSet) then
        local ok = pcall(self.mouseUnlockSet, enabled == true)

        if ok then
            return
        end
    end

    if enabled then
        imports.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        imports.UserInputService.MouseIconEnabled = true
        
    elseif self.previousMouseBehavior ~= nil then
        imports.UserInputService.MouseBehavior = self.previousMouseBehavior
        imports.UserInputService.MouseIconEnabled = self.previousMouseIconEnabled ~= false
        
    else
        imports.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        imports.UserInputService.MouseIconEnabled = false
    end
end

function Controller:setMouseUnlocked(enabled)
    if enabled then
        if not self.activationUnlocksMouse then
            return
        end

        if self.previousMouseUnlocked == nil then
            self.previousMouseUnlocked = self:readMouseUnlocked()
        end

        if not imports.Text.callable(self.mouseUnlockSet) and self.previousMouseBehavior == nil then
            self.previousMouseBehavior = imports.UserInputService.MouseBehavior
            self.previousMouseIconEnabled = imports.UserInputService.MouseIconEnabled
        end

        self:writeMouseUnlocked(true)
        
    elseif self.previousMouseUnlocked ~= nil then
        self:writeMouseUnlocked(self.previousMouseUnlocked)

        self.previousMouseIconEnabled = nil
        self.previousMouseBehavior = nil
        self.previousMouseUnlocked = nil
    end
end

function Controller:ensureGui()
    local player = imports.Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

    if not playerGui then
        return nil
    end

    local existing = playerGui:FindFirstChild("Konsole")

    if existing then
        existing:Destroy()
    end

    local gui = Instance.new("ScreenGui")

    gui.Parent = playerGui
    gui.Name = "Konsole"
    
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    
    gui.DisplayOrder = self.config.panel.displayOrder
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    self.gui = gui

    return gui
end

function Controller:invoke(text)
    if not imports.Text.callable(self.runner) then
        return imports.Result.err("no-runner", "No command runner bound.")
    end

    local ok, response = pcall(self.runner, text)

    if not ok then
        return imports.Result.err("runner-error", tostring(response))
    end

    return imports.Result.from(response)
end

function Controller:bindRun(fn)
    self.runner = imports.Text.callable(fn) and fn or nil
end

function Controller:setSuggestions(list)
    self.suggestions = type(list) == "table" and list or {}

    if self.session then
        self.session:setSuggestions(self.suggestions)
    end
end

function Controller:setSchemas(map)
    self.schemas = type(map) == "table" and map or {}

    if self.session then
        self.session:setSchemas(self.schemas)
    end
end

function Controller:show()
    if not self.enabled then
        return
    end

    if self.session and self.gui and self.gui.Parent then
        self.session:focus()
        return
    end

    local gui = self:ensureGui()

    if not gui then
        return
    end

    local savedPosition = type(self.savedSession) == "table" and self.savedSession.position or nil
    local savedSecondPosition = type(self.savedSession) == "table" and self.savedSession.secondPosition or nil

    local session = imports.Session.new(gui, self.config, savedPosition, savedSecondPosition)

    session:bindCloseRequest(function()
        self:hide()
    end)

    session:bindSubmit(function(text, channel)
        local trimmed = string.lower(string.match(text, "^%s*(%S*)") or "")

        if trimmed == "close" or trimmed == "exit" then
            if channel == 2 then
                session:closeSecond()
            else
                self:hide()
                self.savedSession = nil
            end

            return
        end

        if trimmed == "clear" or trimmed == "cls" then
            session:clear(channel)
            return
        end

        session:appendPending(text, channel)

        task.spawn(function()
            local result = self:invoke(text)

            if self.session == session then
                session:appendResult(result, channel)
            end
        end)
    end)

    session:restoreSnapshot(self.savedSession)
    session:setSuggestions(self.suggestions)
    session:setSchemas(self.schemas)

    self.session = session
    self.open = true

    self:setChatSuppressed(true)
    self:setMouseUnlocked(true)

    session:focus()
end

function Controller:hide()
    local session = self.session
    local gui = self.gui

    if session then
        self.savedSession = session:snapshot()
    end

    self.session = nil
    self.open = false
    self.gui = nil

    self:setChatSuppressed(false)
    self:setMouseUnlocked(false)

    if session then
        session:destroy()

        task.delay(0.04 + (self.config.motion.openSmoothTime or 0.46) + 0.08, function()
            if gui and gui.Parent then
                gui:Destroy()
            end
        end)
        
    elseif gui and gui.Parent then
        gui:Destroy()
    end
end

function Controller:toggle()
    if self.open then
        self:hide()
        
    else
        self:show()
    end
end

function Controller:focus()
    if self.session then
        self.session:focus()
        
    else
        self:show()
    end
end

function Controller:clear()
    if self.session then
        self.session:clear()
    end
end

function Controller:getCursorTarget()
    if self.session then
        return self.session:getCursorTarget()
    end

    return nil
end

function Controller:setActivationKeys(keys)
    self.activationKeys = keyList(keys)

    bindActivation(self)
end

function Controller:setEnabled(enabled)
    self.enabled = enabled == true

    if not self.enabled then
        self:hide()
    end
end

function Controller:setActivationUnlocksMouse(enabled)
    self.activationUnlocksMouse = enabled == true

    if self.open then
        self:setMouseUnlocked(false)
        
        self:setMouseUnlocked(true)
    end
end

function Controller:setMouseUnlockDriver(getFn, setFn)
    self.mouseUnlockGet = imports.Text.callable(getFn) and getFn or nil
    self.mouseUnlockSet = imports.Text.callable(setFn) and setFn or nil

    if self.open and self.activationUnlocksMouse then
        self:setMouseUnlocked(false)
        
        self:setMouseUnlocked(true)
    end
end

function Controller:destroy()
    self:hide()

    if self.toggleActionName then
        
        imports.ContextActionService:UnbindAction(self.toggleActionName)
        self.toggleActionName = nil
    end
end

return Controller
