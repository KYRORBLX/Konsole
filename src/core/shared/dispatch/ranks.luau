--!strict

--[[
	@name ranks
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
    RunService = game:GetService("RunService"),
}

local Types = require("../kommand/types")

--// types
export type Resolver = Types.Resolver
export type Rank = Types.Rank

--// locals
local assignments: { [number]: number } = {}
local registry: { [number]: Rank } = {}
local labels: { [string]: number } = {}

local resolver: Resolver? = nil

local function normalize(value: any): string
    return string.lower(tostring(value or ""))
end

local function userIdOf(entity: any): number?

    if typeof(entity) == "Instance" and entity:IsA("Player") then
        return entity.UserId
    end

    return tonumber(entity)
end

--// public api
local Ranks = {}

function Ranks.define(id: number, name: string, aliases: { string }?): Rank
    assert(type(id) == "number", "rank id must be a number")
    assert(type(name) == "string" and name ~= "", "rank name must be a string")

    local definition: Rank = {
        id = id,
        name = name,
        aliases = {},
    }
    
    for _, alias in aliases or {} :: { string } do
        table.insert(definition.aliases, normalize(alias))
    end

    labels[normalize(name)] = id
    registry[id] = definition

    for _, alias in definition.aliases do
        labels[alias] = id
    end

    return definition
end

function Ranks.resolve(value: any): number?

    if type(value) == "number" then
        return value
    end

    if type(value) == "string" then
        local numeric = tonumber(value)
        if numeric then
            return numeric
        end

        return labels[normalize(value)]
    end

    return nil
end

function Ranks.label(id: number): string
    local definition = registry[id]
    
    if definition then
        return definition.name
    end

    return tostring(id)
end

function Ranks.list(): { Rank }
    local out: { Rank } = {}
    
    for _, definition in registry do
        table.insert(out, definition)
    end
    
    table.sort(out, function(a: Rank, b: Rank)
        return a.id < b.id
    end)

    return out
end

function Ranks.set(userId: any, rank: any): number
    local id = Ranks.resolve(rank)
    
    assert(type(id) == "number", "rank must resolve to a number")
    
    assignments[tonumber(userId) or 0] = id
    return id
end

function Ranks.bind(fn: Resolver?)
    resolver = type(fn) == "function" and fn or nil
end

function Ranks.get(entity: any): number
    local userId = userIdOf(entity)
    
    if not userId then
        return 0
    end

    if resolver then
        local ok, value = pcall(resolver, entity)
        
        if ok and type(value) == "number" then
            return value
        end
    end

    local assigned = assignments[userId]
    
    if assigned then
        return assigned
    end

    if game.CreatorType == Enum.CreatorType.User and userId == game.CreatorId then
        return math.huge
    end
    
    if imports.RunService:IsStudio() then
        return math.huge
    end

    return 0
end

function Ranks.allows(entity: any, required: any): boolean
    local requiredId = Ranks.resolve(required)
    
    if requiredId == nil or requiredId <= 0 then
        return true
    end

    return Ranks.get(entity) >= requiredId
end

local defaults: { { id: number, name: string, aliases: { string }? } } = {
    { id = 0, name = "player" }, -- def
    { id = 10, name = "helper", aliases = { "lowmod", "trial" } },
    { id = 50, name = "moderator", aliases = { "mod" } },
    { id = 100, name = "admin", aliases = { "administrator" } },
    { id = 1000, name = "creator", aliases = { "owner" } },
}
for _, rank in defaults do
    Ranks.define(rank.id, rank.name, rank.aliases).builtin = true
end

return table.freeze(Ranks)
