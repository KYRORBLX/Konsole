--!strict

--[[
	@name chat
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

--// imports
local imports = {
	RunService = game:GetService("RunService"),
	TextChatService = game:GetService("TextChatService"),

	Config = require("../../config"),
}

--// types
export type OpenCallback = () -> ()
export type Disconnect = () -> ()

--// locals
local connection: RBXScriptConnection? = nil

local function command(): TextChatCommand
	local config = imports.Config.groups.input
	local existing = imports.TextChatService:FindFirstChild(config.command)

	if existing and existing:IsA("TextChatCommand") then
		
		local found = existing :: TextChatCommand

		found.PrimaryAlias = config.alias
		found.SecondaryAlias = ""

		found.AutocompleteVisible = true
		found.Enabled = true

		return found
	end
	
	local created = Instance.new("TextChatCommand")

	created.Parent = imports.TextChatService
	created.Name = config.command
	
	created.PrimaryAlias = config.alias
	created.SecondaryAlias = ""

	created.AutocompleteVisible = true
	created.Enabled = true

	return created
end

--// public api
local Chat = {}

function Chat.unbindKonsoleOpen()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function Chat.bindKonsoleOpen(callback: OpenCallback): Disconnect
	Chat.unbindKonsoleOpen()

	if not imports.RunService:IsClient() then
		return function() end
	end

	connection = command().Triggered:Connect(function(_originTextSource: TextSource, _unfilteredText: string)
		callback()
	end)

	return Chat.unbindKonsoleOpen
end

return table.freeze(Chat)
