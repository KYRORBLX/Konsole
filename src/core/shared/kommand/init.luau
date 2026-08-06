--!strict

--[[
	@name kommand
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local Imports = {
	Ranks = require("./dispatch/ranks"),
	Table = require("@self/table"),
}

local Types = require("../../types/sharedTypes")

--// types
export type Definition = Types.Definition
export type Argument = Types.Argument

export type Command = Types.Command
export type Watcher = Types.Watcher

--// locals
local definitions: { [string]: Command } = {}
local watchers: { Watcher } = {}
local order: { string } = {}

local function normalize(value: any): string
	return string.lower(tostring(value or ""))
end

local function quoteIfNeeded(value: any, isArray: boolean?): string
	local text = tostring(value or "")
	if text == "" then
		return text
	end

	-- a "[...]" bracket literal already tokenizes as a single token, so quoting it
	-- would just wrap the brackets in redundant quotes
	local isBracketLiteral = string.sub(text, 1, 1) == "[" and string.sub(text, -1) == "]"

	if not isBracketLiteral and string.find(text, "%s") then
		-- array args never get quoted strings; a spaced value becomes its own bracket literal
		if isArray then
			return "[" .. text .. "]"
		end

		return string.format("%q", text)
	end

	return text
end

local function notify()
	for _, watcher in watchers do
		task.spawn(watcher)
	end
end

-- a preset group suggestion (e.g. { "debug", "godmode" }) flattens into a single
-- completable bracket literal, "[debug, godmode]", before it ever hits replication
local function flattenSuggestion(value: any): string
	if type(value) == "table" then
		local parts = {}
		for _, entry in value do
			table.insert(parts, tostring(entry))
		end
		return "[" .. table.concat(parts, ", ") .. "]"
	end

	return tostring(value or "")
end

local function normalizeArgSuggestions(args: { any })
	for _, arg in args do
		if type(arg) ~= "table" then
			continue
		end

		-- boolean args always suggest true/false; a custom suggestions list
		-- doesn't make sense when there are only two possible values
		if arg.type == "boolean" then
			arg.suggestions = { "true", "false" }
			continue
		end

		if type(arg.suggestions) == "table" then
			local flat = {}
			local seen: { [string]: boolean } = {}

			local function push(text: string)
				local key = string.lower(text)
				if text ~= "" and not seen[key] then
					seen[key] = true
					table.insert(flat, text)
				end
			end

			for _, entry in arg.suggestions do
				-- a preset group is offered whole (the bracket literal) as well as
				-- spread out, one suggestion per value, deduped against each other
				if type(entry) == "table" then
					push(flattenSuggestion(entry))
					for _, value in entry do
						push(tostring(value))
					end
				else
					push(flattenSuggestion(entry))
				end
			end

			arg.suggestions = flat
		end
	end
end

local function pushUnique(list: { string }, seen: { [string]: boolean }, value: any)
	local text = tostring(value or "")
	if text == "" then
		return
	end

	local key = normalize(text)

	if seen[key] then
		return
	end

	seen[key] = true

	table.insert(list, text)
end

--// public api
local Kommand = {}

--[[
	@description normalizes + registers a cmd, overwrites if name exists, notifies
	watchers after (thats how the console ui refreshes suggestions while ur playing)
	@time June 30, 2026 8:33 PM
]]
function Kommand.define(definition: Definition): Command
	assert(type(definition) == "table", "command definition must be a table")
	assert(type(definition.name) == "string" and definition.name ~= "", "command name must be a string")

	local rank = Imports.Ranks.resolve(definition.rank or 0)
	assert(type(rank) == "number", `command "{definition.name}" has an unresolvable rank`)

	local normalized: Command = {

		cooldown = math.max(0, tonumber(definition.cooldown) or 0),
		description = tostring(definition.description or ""),

		args = type(definition.args) == "table" and Imports.Table.copyList(definition.args) or {},
		server = type(definition.server) == "string" and definition.server or nil,

		run = Imports.Table.callable(definition.run) and definition.run or nil,
		name = normalize(definition.name),
		rank = rank,

		aliases = {},
	}

	normalizeArgSuggestions(normalized.args)

	for _, alias in definition.aliases or {} :: { string } do
		table.insert(normalized.aliases, normalize(alias))
	end

	local existing = definitions[normalized.name]

	if not existing then
		table.insert(order, normalized.name)
	end

	if existing and normalized.run == nil and normalized.server == nil then
		normalized.run = existing.run
	end

	definitions[normalized.name] = normalized

	notify()

	return normalized
end

function Kommand.find(name: any): Command?
	name = normalize(name)

	local direct = definitions[name]

	if direct then
		return direct
	end

	for _, key in order do
		local definition = definitions[key]

		if definition and table.find(definition.aliases, name) then
			return definition
		end
	end

	return nil
end

function Kommand.list(): { Command }
	local out: { Command } = {}

	for _, key in order do
		table.insert(out, definitions[key])
	end

	return out
end

function Kommand.schemas(): { [string]: { Argument } }
	local schemas: { [string]: { Argument } } = {}
	for _, key in order do
		local definition = definitions[key]

		if definition then
			schemas[definition.name] = definition.args

			for _, alias in definition.aliases do
				schemas[alias] = definition.args
			end
		end
	end

	return schemas
end

function Kommand.watch(fn: Watcher?)
	if Imports.Table.callable(fn) then
		table.insert(watchers, fn :: Watcher)
	end
end

function Kommand.suggestions(): { string }
	local seen: { [string]: boolean } = {}
	local suggestions: { string } = {}

	for _, key in order do
		local definition = definitions[key]

		if definition then
			local nameSeen: { [string]: boolean } = {}
			local names: { string } = {}

			pushUnique(names, nameSeen, definition.name)

			for _, alias in definition.aliases do
				pushUnique(names, nameSeen, alias)
			end

			for _, name in names do
				pushUnique(suggestions, seen, name)
			end

			local firstArg = definition.args[1]
			local isArray = type(firstArg) == "table" and firstArg.array == true
			local argSuggestions = type(firstArg) == "table" and firstArg.suggestions or nil
			if type(argSuggestions) == "function" then
				argSuggestions = argSuggestions()
			end

			if type(argSuggestions) == "table" then
				for _, name in names do
					for _, suggestion in argSuggestions do
						pushUnique(suggestions, seen, name .. " " .. quoteIfNeeded(suggestion, isArray))
					end
				end
			end
		end
	end

	table.sort(suggestions, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	return suggestions
end

return table.freeze(Kommand)
