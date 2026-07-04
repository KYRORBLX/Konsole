--[[
	@name chat
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

--!strict

local imports = {
	RunService = game:GetService("RunService"),
	TextChatService = game:GetService("TextChatService"),

	Config = require("../../config"),
}

export type OpenCallback = () -> ()
export type Disconnect = () -> ()

local connection: RBXScriptConnection? = nil

local Chat = {}

local function command(): TextChatCommand
	local config = imports.Config.groups.input
	local existing = imports.TextChatService:FindFirstChild(config.command)
	if existing and existing:IsA("TextChatCommand") then
		local found = existing :: TextChatCommand
		found.PrimaryAlias = config.alias
		found.SecondaryAlias = ""
		found.Enabled = true
		found.AutocompleteVisible = true
		return found
	end

	local created = Instance.new("TextChatCommand")
	created.Name = config.command
	created.PrimaryAlias = config.alias
	created.SecondaryAlias = ""
	created.Enabled = true
	created.AutocompleteVisible = true
	created.Parent = imports.TextChatService
	return created
end

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
