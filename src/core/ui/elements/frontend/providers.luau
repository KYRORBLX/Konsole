--!strict

--[[
	@name providers
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local imports = {
    Players = game:GetService("Players"),
}

local Types = require("../../../../types/sharedTypes")

--// types
export type Argument = Types.Argument
type Provider = () -> { string }

--// locals
local function playerNames(): { string }
    local out = {
        "others",
        "all",
        "me",
    }
    
    for _, player in imports.Players:GetPlayers() do
        table.insert(out, player.Name)
    end

    return out
end

--// public api
local Providers: { [string]: any } = {}

Providers.players = playerNames
Providers.player = playerNames

function Providers.resolve(arg: Argument): { string }
    
    local seen: { [string]: boolean } = {}
    local out: { string } = {}

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
