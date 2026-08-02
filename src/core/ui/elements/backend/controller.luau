--!strict

--[[
	@name controller
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Imports = {
	ContextActionService = game:GetService("ContextActionService"),
	UserInputService = game:GetService("UserInputService"),

	TextChatService = game:GetService("TextChatService"),
	Players = game:GetService("Players"),

	Session = require("../frontend/session"),
	Text = require("../misc/text"),

	Result = require("./result"),
}

local Types = require("../../../../types/uiTypes")

--// types
type SessionConstructor = Types.SessionConstructor
type MouseUnlockGetter = Types.MouseUnlockGetter
type MouseUnlockSetter = Types.MouseUnlockSetter

type ControllerState = Types.ControllerState
type RenderResult = Types.RenderResult

type Schemas = Types.Schemas
type Runner = Types.Runner
type Config = Types.Config

export type Controller = Types.Controller

--// locals
local NewSession = (Imports.Session.new :: unknown) :: SessionConstructor
local serial = 0

local function keyList(keys: { Enum.KeyCode }?): { Enum.KeyCode }
	local out: { Enum.KeyCode } = {}

	if keys then
		for _, key in keys do
			table.insert(out, key)
		end
	end

	return out
end

local function typingKey(key: Enum.KeyCode): boolean
	return utf8.len(Imports.UserInputService:GetStringForKeyCode(key)) == 1
end

local function bindActivation(self: Controller): ()
	local toggleActionName = self.toggleActionName

	if not toggleActionName then
		return
	end

	Imports.ContextActionService:UnbindAction(toggleActionName)

	if #self.activationKeys == 0 then
		return
	end

	Imports.ContextActionService:BindActionAtPriority(toggleActionName, function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin or not self.enabled then
			return Enum.ContextActionResult.Pass
		end

		if Imports.UserInputService:GetFocusedTextBox() and not self.open and typingKey(input.KeyCode) then
			return Enum.ContextActionResult.Pass
		end

		self:toggle()

		return Enum.ContextActionResult.Sink
	end, false, self.config.input.activationPriority, table.unpack(self.activationKeys))
end

--// public api
local Controller = {}
Controller.__index = Controller

function Controller.new(config: Config): Controller
	serial += 1

	local input = config.input

	local self = (setmetatable({

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
	} :: ControllerState, Controller) :: unknown) :: Controller

	bindActivation(self)

	return self
end

function Controller.setChatSuppressed(self: Controller, enabled: boolean): ()
	pcall(function()
		local chatWindow = Imports.TextChatService.ChatWindowConfiguration
		local chatInput = Imports.TextChatService.ChatInputBarConfiguration

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

function Controller.readMouseUnlocked(self: Controller): boolean
	local mouseUnlockGet = self.mouseUnlockGet

	if mouseUnlockGet then
		local ok, value = pcall(mouseUnlockGet)

		if ok and type(value) == "boolean" then
			return value
		end
	end

	return Imports.UserInputService.MouseBehavior == Enum.MouseBehavior.Default
end

function Controller.writeMouseUnlocked(self: Controller, enabled: boolean): ()
	local mouseUnlockSet = self.mouseUnlockSet

	if mouseUnlockSet then
		local ok = pcall(mouseUnlockSet, enabled == true)

		if ok then
			return
		end
	end

	if enabled then
		Imports.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		Imports.UserInputService.MouseIconEnabled = true
	elseif self.previousMouseBehavior ~= nil then
		Imports.UserInputService.MouseBehavior = self.previousMouseBehavior
		Imports.UserInputService.MouseIconEnabled = self.previousMouseIconEnabled ~= false
	else
		Imports.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		Imports.UserInputService.MouseIconEnabled = false
	end
end

function Controller.setMouseUnlocked(self: Controller, enabled: boolean): ()
	if enabled then
		if not self.activationUnlocksMouse then
			return
		end

		if self.previousMouseUnlocked == nil then
			self.previousMouseUnlocked = self:readMouseUnlocked()
		end

		if not Imports.Text.callable(self.mouseUnlockSet) and self.previousMouseBehavior == nil then
			self.previousMouseBehavior = Imports.UserInputService.MouseBehavior
			self.previousMouseIconEnabled = Imports.UserInputService.MouseIconEnabled
		end

		self:writeMouseUnlocked(true)
	elseif self.previousMouseUnlocked ~= nil then
		self:writeMouseUnlocked(self.previousMouseUnlocked)

		self.previousMouseIconEnabled = nil
		self.previousMouseBehavior = nil
		self.previousMouseUnlocked = nil
	end
end

function Controller.ensureGui(self: Controller): ScreenGui?
	local player = Imports.Players.LocalPlayer
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

function Controller.invoke(self: Controller, text: string): RenderResult
	local runner = self.runner

	if not runner then
		return Imports.Result.err("no-runner", "No command runner bound.")
	end

	local ok, response = pcall(runner, text)

	if not ok then
		return Imports.Result.err("runner-error", tostring(response))
	end

	return Imports.Result.from(response)
end

function Controller.bindRun(self: Controller, fn: Runner?): ()
	self.runner = fn
end

function Controller.setSuggestions(self: Controller, list: { string }): ()
	self.suggestions = list

	if self.session then
		self.session:setSuggestions(self.suggestions)
	end
end

function Controller.setSchemas(self: Controller, map: Schemas): ()
	self.schemas = map

	if self.session then
		self.session:setSchemas(self.schemas)
	end
end

function Controller.show(self: Controller): ()
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

	local savedSession = self.savedSession
	local savedPosition = savedSession and savedSession.position or nil
	local savedSecondPosition = savedSession and savedSession.secondPosition or nil

	local session = NewSession(gui, self.config, savedPosition, savedSecondPosition)

	if not session then
		gui:Destroy()
		self.gui = nil
		return
	end

	session:bindCloseRequest(function()
		self:hide()
	end)

	session:bindSubmit(function(text: string, channel: number)
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

		if trimmed == "clear" or trimmed == "cls" or trimmed == "clr" then
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

function Controller.hide(self: Controller): ()
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

function Controller.toggle(self: Controller): ()
	if self.open then
		self:hide()
	else
		self:show()
	end
end

function Controller.focus(self: Controller): ()
	if self.session then
		self.session:focus()
	else
		self:show()
	end
end

function Controller.clear(self: Controller): ()
	if self.session then
		self.session:clear()
	end
end

function Controller.getCursorTarget(self: Controller): GuiObject?
	if self.session then
		return self.session:getCursorTarget()
	end

	return nil
end

function Controller.setActivationKeys(self: Controller, keys: { Enum.KeyCode }): ()
	self.activationKeys = keyList(keys)

	bindActivation(self)
end

function Controller.setEnabled(self: Controller, enabled: boolean): ()
	self.enabled = enabled == true

	if not self.enabled then
		self:hide()
	end
end

function Controller.setActivationUnlocksMouse(self: Controller, enabled: boolean): ()
	self.activationUnlocksMouse = enabled == true

	if self.open then
		self:setMouseUnlocked(false)

		self:setMouseUnlocked(true)
	end
end

function Controller.setMouseUnlockDriver(
	self: Controller,
	getFn: MouseUnlockGetter?,
	setFn: MouseUnlockSetter?
): ()
	self.mouseUnlockGet = getFn
	self.mouseUnlockSet = setFn

	if self.open and self.activationUnlocksMouse then
		self:setMouseUnlocked(false)

		self:setMouseUnlocked(true)
	end
end

function Controller.destroy(self: Controller): ()
	self:hide()

	local toggleActionName = self.toggleActionName

	if toggleActionName then
		Imports.ContextActionService:UnbindAction(toggleActionName)
		self.toggleActionName = nil
	end
end

return Controller
