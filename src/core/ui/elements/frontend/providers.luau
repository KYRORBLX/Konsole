--!strict

--[[
	@name providers
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
	Players = game:GetService("Players"),
}

local Types = require("../../../shared/kommand/types")

--// types
export type Argument = Types.Argument
type Provider = () -> { string }

--// locals
local function playerNames(): { string }
	local out = { "me", "all", "others" }
	for _, player in imports.Players:GetPlayers() do
		table.insert(out, player.Name)
	end

	return out
end

--// public api
local Providers: { [string]: any } = {}

Providers.player = playerNames
Providers.players = playerNames

function Providers.resolve(arg: Argument): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local function push(value: any)
		local text = tostring(value or "")
		local key = string.lower(text)
		if text ~= "" and not seen[key] then
			seen[key] = true
			table.insert(out, text)
		end
	end

	local suggestions = arg.suggestions
	if type(suggestions) == "table" then
		for _, value in suggestions do
			push(value)
		end
	elseif type(suggestions) == "string" then
		local provider = Providers[string.lower(suggestions)] :: Provider?
		if type(provider) == "function" then
			for _, value in provider() do
				push(value)
			end
		end
	end

	local provider = Providers[string.lower(tostring(arg.type or ""))] :: Provider?
	if type(provider) == "function" then
		for _, value in provider() do
			push(value)
		end
	end

	return out
end

return Providers
