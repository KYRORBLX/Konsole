--[[
	@name arguments
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--!strict

local imports = {
	Players = game:GetService("Players"),
}

local Types = require("./types")

export type Converters = Types.Converters
export type Converter = Types.Converter
export type Argument = Types.Argument
export type Caller = Types.Caller

local Arguments = {}

function Arguments.tokenize(text: string?): { string }
	local tokens: { string } = {}
	local source = tostring(text or "")
	local cursor = 1

	while cursor <= #source do
		local nextStart = string.find(source, "%S", cursor)
		if not nextStart then
			break
		end

		local char = string.sub(source, nextStart, nextStart)
		if char == '"' or char == "'" then
			local closing = string.find(source, char, nextStart + 1, true)
			if closing then
				table.insert(tokens, string.sub(source, nextStart + 1, closing - 1))
				cursor = closing + 1
			else
				table.insert(tokens, string.sub(source, nextStart + 1))
				cursor = #source + 1
			end
		else
			local wordEnd = string.find(source, "%s", nextStart) or (#source + 1)
			table.insert(tokens, string.sub(source, nextStart, wordEnd - 1))
			cursor = wordEnd
		end
	end

	return tokens
end

function Arguments.split(text: string?): (string?, { string })
	local tokens = Arguments.tokenize(text)
	local name = table.remove(tokens, 1)
	return name, tokens
end

local function findPlayers(token: string?, caller: Caller): { Player }
	local query = string.lower(tostring(token or ""))
	if query == "me" and caller then
		return { caller }
	end
	if query == "all" or query == "*" then
		return imports.Players:GetPlayers()
	end
	if query == "others" then
		local others: { Player } = {}
		for _, player in imports.Players:GetPlayers() do
			if player ~= caller then
				table.insert(others, player)
			end
		end
		return others
	end

	local matches: { Player } = {}
	for _, player in imports.Players:GetPlayers() do
		local name = string.lower(player.Name)
		local display = string.lower(player.DisplayName)
		if name == query or display == query then
			return { player }
		end
		if string.sub(name, 1, #query) == query or string.sub(display, 1, #query) == query then
			table.insert(matches, player)
		end
	end

	return matches
end

local function asString(token: string, _caller: Caller): (boolean, any)
	return true, tostring(token)
end

Arguments.types = {
	string = asString,

	number = function(token: string): (boolean, any)
		local value = tonumber(token)
		if value == nil then
			return false, `expected a number, got "{token}"`
		end
		return true, value
	end,

	boolean = function(token: string): (boolean, any)
		local lowered = string.lower(tostring(token or ""))
		if lowered == "true" or lowered == "yes" or lowered == "on" or lowered == "1" then
			return true, true
		end
		if lowered == "false" or lowered == "no" or lowered == "off" or lowered == "0" then
			return true, false
		end
		return false, `expected true or false, got "{token}"`
	end,

	player = function(token: string, caller: Caller): (boolean, any)
		local matches = findPlayers(token, caller)
		if #matches == 0 then
			return false, `no player matching "{token}"`
		end
		if #matches > 1 then
			return false, `"{token}" matches more than one player`
		end
		return true, matches[1]
	end,

	players = function(token: string, caller: Caller): (boolean, any)
		local matches = findPlayers(token, caller)
		if #matches == 0 then
			if string.lower(tostring(token or "")) == "others" then
				return false, "no other players"
			end
			return false, `no players matching "{token}"`
		end
		return true, matches
	end,
} :: Converters

function Arguments.parse(argDefinitions: { Argument }?, tokens: { string }, caller: Caller): (boolean, any)
	local values = {}
	local definitions: { Argument } = if type(argDefinitions) == "table" then argDefinitions else {}

	for index, definition in definitions do
		local token = tokens[index]
		if token == nil or token == "" then
			if definition.default ~= nil then
				table.insert(values, definition.default)
				continue
			end
			if definition.required == false then
				continue
			end
			return false, `missing argument "{definition.name or index}"`
		end

		local typeName = string.lower(tostring(definition.type or "string"))
		local convert: Converter = Arguments.types[typeName] or asString
		local ok, value = convert(token, caller)
		if not ok then
			return false, `argument "{definition.name or index}": {value}`
		end

		table.insert(values, value)
	end

	return true, values
end

return table.freeze(Arguments)
