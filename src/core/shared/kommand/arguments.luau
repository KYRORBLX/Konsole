--!strict

--[[
	@name arguments
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local Imports = {
	Players = game:GetService("Players"),
}

local Types = require("../../../types/sharedTypes")

--// types
export type Converters = Types.Converters
export type Converter = Types.Converter

export type Argument = Types.Argument
export type Caller = Types.Caller

--// locals
local function findPlayers(token: string?, caller: Caller): { Player }
	local query = string.lower(tostring(token or ""))

	if query == "me" and caller then
		return { caller }
	end

	if query == "all" or query == "*" then
		return Imports.Players:GetPlayers()
	end

	if query == "others" then
		local others: { Player } = {}

		for _, player in Imports.Players:GetPlayers() do
			if player ~= caller then
				table.insert(others, player)
			end
		end

		return others
	end

	local matches: { Player } = {}
	for _, player in Imports.Players:GetPlayers() do
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

local function isCollectiveKeyword(token: string): boolean
	local lower = string.lower(token)
	return lower == "all" or lower == "others" or lower == "*"
end

local function dedupe(players: { Player }): { Player }
	local seen: { [number]: boolean } = {}
	local result: { Player } = {}

	for _, player in players do
		if not seen[player.UserId] then
			seen[player.UserId] = true
			table.insert(result, player)
		end
	end

	return result
end

local function bracketEntries(raw: string): { string }?
	if string.sub(raw, 1, 1) ~= "[" then
		return nil
	end

	local inner = string.gsub(string.gsub(raw, "^%[", ""), "%]$", "")
	local entries = {}

	for entry in string.gmatch(inner, "[^,]+") do
		local trimmed = string.match(entry, "^%s*(.-)%s*$") or entry
		if trimmed ~= "" then
			table.insert(entries, trimmed)
		end
	end

	return entries
end

--// public api
local Arguments = {}

Arguments.isCollectiveKeyword = isCollectiveKeyword

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
		elseif char == "[" then
			local closing = string.find(source, "]", nextStart + 1, true)

			if closing then
				table.insert(tokens, string.sub(source, nextStart, closing))
				cursor = closing + 1
			else
				table.insert(tokens, string.sub(source, nextStart))
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
		local raw = tostring(token or "")
		local entries = bracketEntries(raw)

		if entries then
			local matches: { Player } = {}
			local entryCount = 0
			local sawCollective = false

			for _, trimmed in entries do
				entryCount += 1
				local collective = isCollectiveKeyword(trimmed)

				if collective then
					sawCollective = true
				end

				local entryMatches = findPlayers(trimmed, caller)

				if #entryMatches == 0 then
					return false, `no player matching "{trimmed}"`
				end

				if #entryMatches > 1 and not collective then
					return false, `"{trimmed}" matches more than one player`
				end

				for _, player in entryMatches do
					table.insert(matches, player)
				end
			end

			if sawCollective and entryCount > 1 then
				return false, `"all"/"others" can't be combined with other players`
			end

			matches = dedupe(matches)

			if #matches == 0 then
				return false, "no players given"
			end

			return true, matches
		end

		local matches = findPlayers(raw, caller)

		if #matches == 0 then
			if string.lower(raw) == "others" then
				return false, "no other players"
			end

			return false, `no players matching "{raw}"`
		end

		return true, dedupe(matches)
	end,
} :: Converters

function Arguments.parseArray(token: string, typeName: string, caller: Caller): (boolean, any)
	local raw = tostring(token or "")
	local entries: { string } = bracketEntries(raw) or { raw }
	local convert: Converter = Arguments.types[typeName] or asString

	local values: { any } = {}
	for _, entry in entries do
		local ok, value = convert(entry, caller)

		if not ok then
			return false, value
		end

		table.insert(values, value)
	end

	if #values == 0 then
		return false, "no values given"
	end

	return true, values
end

function Arguments.parse(argDefinitions: { Argument }?, tokens: { string }, caller: Caller): (boolean, any)
	local definitions: { Argument } = if type(argDefinitions) == "table" then argDefinitions else {}

	local function parseFrom(index: number, tokenIndex: number): (boolean, any)
		if index > #definitions then
			return true, { n = 0 }
		end

		local definition = definitions[index]
		local token = tokens[tokenIndex]

		local optional = definition.required == false or definition.default ~= nil

		if token == nil or token == "" then
			if definition.default ~= nil then
				local ok, values = parseFrom(index + 1, tokenIndex)
				if not ok then
					return false, values
				end

				values[index] = definition.default
				values.n = math.max(values.n or 0, index)

				return true, values
			end

			if optional then
				return parseFrom(index + 1, tokenIndex)
			end

			return false, `missing argument "{definition.name or index}"`
		end

		local typeName = string.lower(tostring(definition.type or "string"))

		local ok, value
		if definition.array then
			ok, value = Arguments.parseArray(token, typeName, caller)
		else
			local convert: Converter = Arguments.types[typeName] or asString
			ok, value = convert(token, caller)
		end

		if not ok then
			if optional and index < #definitions then
				local skipped, values = parseFrom(index + 1, tokenIndex)

				if skipped then
					if definition.default ~= nil then
						values[index] = definition.default
						values.n = math.max(values.n or 0, index)
					end

					return true, values
				end
			end

			return false, `argument "{definition.name or index}": {value}`
		end

		local parsed, values = parseFrom(index + 1, tokenIndex + 1)

		if not parsed then
			return false, values
		end

		values[index] = value
		values.n = math.max(values.n or 0, index)

		return true, values
	end

	return parseFrom(1, 1)
end

return table.freeze(Arguments)
