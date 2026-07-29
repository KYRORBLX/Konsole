--!strict

--[[
	@name dispatch
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local Imports = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),

	RunService = game:GetService("RunService"),
	Players = game:GetService("Players"),

	Arguments = require("./kommand/arguments"),
	Table = require("./kommand/table"),
	Ranks = require("@self/ranks"),

	Kommand = require("./kommand"),
}

local Types = require("../../types/sharedTypes")

--// types
export type Definition = Types.Definition
export type Command = Types.Command
export type Context = Types.Context

export type Outcome = Types.Outcome
export type Run = Types.Run
type Argument = Types.Argument

--// locals
local Dispatch = {
	definitionsRemoteName = "KonsoleDefinitions",
	remoteName = "KonsoleRemote",
	timeout = 8,
}

local cooldowns: { [string]: { [string]: number } } = {}
local implementations: { [string]: Run } = {}

local definitionsRemote: RemoteEvent? = nil
local remote: RemoteFunction? = nil

local function ok(message: any?): Outcome
	return { ok = true, message = tostring(message or "Command completed.") }
end

local function fail(code: any?, message: any?): Outcome
	return { ok = false, code = tostring(code or "error"), message = tostring(message or "Command failed.") }
end

local function contextFor(kommand: Command, entity: any, text: string): Context
	return {
		dispatch = Dispatch,
		kommand = kommand,
		entity = entity,

		ranks = Imports.Ranks :: any,

		run = function(nextText: any): any
			return Dispatch.execute(nextText, entity)
		end,

		text = text,
		reply = ok,
		err = fail,
	}
end

local function cooldownKey(entity: any): string
	if typeof(entity) == "Instance" then
		local instance = entity :: Instance

		if instance:IsA("Player") then
			return tostring((instance :: Player).UserId)
		end
	end

	return tostring(entity or "server")
end

local function checkCooldown(kommand: Command, entity: any): Outcome?
	if kommand.cooldown <= 0 then
		return nil
	end

	local bucket = cooldowns[kommand.name]
	local key = cooldownKey(entity)
	local now = os.clock()

	local nextAllowed = bucket and bucket[key] or 0

	if nextAllowed > now then
		return fail("cooldown", `"{kommand.name}" is on cooldown for {math.ceil(nextAllowed - now)}s`)
	end

	if not bucket then
		bucket = {}
		cooldowns[kommand.name] = bucket
	end

	bucket[key] = now + kommand.cooldown

	return nil
end

local function runDefinition(kommand: Command, tokens: { string }, entity: any, text: string): any
	local callback = kommand.run

	if Imports.RunService:IsServer() and kommand.server then
		callback = implementations[kommand.server] or callback
	end

	if not Imports.Table.callable(callback) then
		return fail("not-implemented", `"{kommand.name}" has no implementation on this side`)
	end

	local parsed, values = Imports.Arguments.parse(kommand.args, tokens, entity)

	if not parsed then
		return fail("bad-argument", values)
	end

	local cooldown = checkCooldown(kommand, entity)

	if cooldown then
		return cooldown
	end

	local succeeded, result =
		pcall(callback :: Run, contextFor(kommand, entity, text), table.unpack(values, 1, values.n or #values))
	if not succeeded then
		return fail("command-error", tostring(result))
	end

	if type(result) == "table" then
		return result
	end

	if result == nil then
		return ok()
	end

	return ok(tostring(result))
end

local function ensureRemote(): RemoteFunction?
	if remote and remote.Parent then
		return remote
	end

	if Imports.RunService:IsServer() then
		local bridge = (Imports.ReplicatedStorage:FindFirstChild(Dispatch.remoteName)
			or Instance.new("RemoteFunction")) :: RemoteFunction

		bridge.Parent = Imports.ReplicatedStorage
		bridge.Name = Dispatch.remoteName

		remote = bridge :: RemoteFunction
	else
		remote = Imports.ReplicatedStorage:WaitForChild(Dispatch.remoteName, Dispatch.timeout) :: RemoteFunction?
	end

	return remote
end

local function ensureDefinitionsRemote(): RemoteEvent?
	if definitionsRemote and definitionsRemote.Parent then
		return definitionsRemote
	end

	if Imports.RunService:IsServer() then
		local bridge = (Imports.ReplicatedStorage:FindFirstChild(Dispatch.definitionsRemoteName)
			or Instance.new("RemoteEvent")) :: RemoteEvent

		bridge.Name = Dispatch.definitionsRemoteName
		bridge.Parent = Imports.ReplicatedStorage
		definitionsRemote = bridge :: RemoteEvent
	else
		definitionsRemote =
			Imports.ReplicatedStorage:WaitForChild(Dispatch.definitionsRemoteName, Dispatch.timeout) :: RemoteEvent?
	end

	return definitionsRemote
end

--[[ 
	@description fns can't cross a Remote so a kommand is stripped down to its
 	plain-data schema before being sent to clients (server stays authoritative of course
	on `run` clients only need enough to route the call back via `server`)

	@time June 4, 2026 11:52 AM
]]

--[[
	@description binary codec for the definitions list -- fixed field order so
	no key names ever hit the wire (unlike JSON), string.pack/unpack are
	built into Luau so this needs nothing outside the engine. An empty string
	is used as the "absent" sentinel for optional string fields (name/
	description/server) rather than a separate tag byte, since none of those
	are meaningfully used as an actual empty string vs unset.
]]
--[[
	@description names, rank strings, and suggestion strings repeat a lot across
	a real command set (e.g. rank = "admin" on half the commands, arg name
	"player"/"target" reused everywhere) -- pooling them once and referencing by
	index instead of re-sending the literal text each time cuts real bytes.
	Descriptions are intentionally NOT pooled: they're long, mostly-unique
	sentences, so a pool entry would cost more than just inlining them.
]]
type Pool = { list: { string }, index: { [string]: number } }

local function internString(pool: Pool, value: string?): ()
	if value and not pool.index[value] then
		table.insert(pool.list, value)
		pool.index[value] = #pool.list
	end
end

local function buildPool(list: { Definition }): Pool
	local pool: Pool = { list = {}, index = {} }

	for _, definition in list do
		if type(definition.rank) == "string" then
			internString(pool, definition.rank :: string)
		end
		internString(pool, definition.server)

		if definition.aliases then
			for _, alias in definition.aliases do
				internString(pool, alias)
			end
		end

		if definition.args then
			for _, arg in definition.args do
				internString(pool, arg.name)
				if type(arg.suggestions) == "string" then
					internString(pool, arg.suggestions :: string)
				elseif type(arg.suggestions) == "table" then
					for _, s in arg.suggestions :: { string } do
						internString(pool, s)
					end
				end
			end
		end
	end

	return pool
end

local function packPool(pool: Pool): string
	local out = string.pack("<H", #pool.list)
	for _, s in pool.list do
		out ..= string.pack("<s1", s)
	end
	return out
end

local function unpackPool(data: string, pos: number): ({ string }, number)
	local count
	count, pos = string.unpack("<H", data, pos)
	local list = {}
	for i = 1, count do
		list[i], pos = string.unpack("<s1", data, pos)
	end
	return list, pos
end

local function packStringArray(list: { string }?, pool: Pool): string
	local out = string.pack("<B", list and #list or 0)
	if list then
		for _, s in list do
			out ..= string.pack("<H", pool.index[s])
		end
	end
	return out
end

local function unpackStringArray(data: string, pos: number, pool: { string }): ({ string }, number)
	local count
	count, pos = string.unpack("<B", data, pos)
	local out = {}
	for i = 1, count do
		local idx
		idx, pos = string.unpack("<H", data, pos)
		out[i] = pool[idx]
	end
	return out, pos
end

local function packRank(rank: (number | string)?, pool: Pool): string
	if type(rank) == "number" then
		return string.pack("<Bd", 1, rank)
	elseif type(rank) == "string" then
		return string.pack("<BH", 2, pool.index[rank])
	end
	return string.pack("<B", 0)
end

local function unpackRank(data: string, pos: number, pool: { string }): (any, number)
	local tag
	tag, pos = string.unpack("<B", data, pos)
	if tag == 1 then
		return string.unpack("<d", data, pos)
	elseif tag == 2 then
		local idx
		idx, pos = string.unpack("<H", data, pos)
		return pool[idx], pos
	end
	return nil, pos
end

-- shared by Argument.default (string | number | boolean | nil); default values
-- are typically unique per-argument so they're inlined, not pooled
local function packAny(value: any): string
	if type(value) == "string" then
		return string.pack("<B", 1) .. string.pack("<s1", value)
	elseif type(value) == "number" then
		return string.pack("<Bd", 2, value)
	elseif type(value) == "boolean" then
		return string.pack("<BB", 3, if value then 1 else 0)
	end
	return string.pack("<B", 0)
end

local function unpackAny(data: string, pos: number): (any, number)
	local tag
	tag, pos = string.unpack("<B", data, pos)
	if tag == 1 then
		return string.unpack("<s1", data, pos)
	elseif tag == 2 then
		return string.unpack("<d", data, pos)
	elseif tag == 3 then
		local n
		n, pos = string.unpack("<B", data, pos)
		return n == 1, pos
	end
	return nil, pos
end

local argumentTypeTags: { [string]: number } = { string = 1, number = 2, boolean = 3, player = 4, players = 5 }
local argumentTypeNames: { [number]: string } = { "string", "number", "boolean", "player", "players" }

local function packArgument(arg: Argument, pool: Pool): string
	local typeTag = (arg.type and argumentTypeTags[arg.type]) or 0
	local flags = bit32.bor(bit32.lshift(typeTag, 1), if arg.required then 1 else 0)
	local nameIdx = if arg.name then pool.index[arg.name] else 0
	local out = string.pack("<H", nameIdx) .. string.pack("<B", flags) .. packAny(arg.default)

	if type(arg.suggestions) == "table" then
		out ..= string.pack("<B", 2) .. packStringArray(arg.suggestions :: { string }, pool)
	elseif type(arg.suggestions) == "string" then
		out ..= string.pack("<BH", 1, pool.index[arg.suggestions])
	else
		out ..= string.pack("<B", 0)
	end

	return out
end

local function unpackArgument(data: string, pos: number, pool: { string }): (Argument, number)
	local nameIdx, flags, suggestionsTag: number
	nameIdx, pos = string.unpack("<H", data, pos)
	flags, pos = string.unpack("<B", data, pos)
	local argType = bit32.rshift(flags, 1)
	local required = bit32.band(flags, 1)
	local default
	default, pos = unpackAny(data, pos)
	suggestionsTag, pos = string.unpack("<B", data, pos)

	local suggestions: any = nil
	if suggestionsTag == 2 then
		suggestions, pos = unpackStringArray(data, pos, pool)
	elseif suggestionsTag == 1 then
		local idx
		idx, pos = string.unpack("<H", data, pos)
		suggestions = pool[idx]
	end

	return {
		name = if nameIdx ~= 0 then pool[nameIdx] else nil,
		type = argumentTypeNames[argType],
		default = default,
		required = required == 1,
		suggestions = suggestions,
	}, pos
end

local function packDefinition(definition: Definition, pool: Pool): string
	local out = string.pack("<s1", definition.name)
		.. packRank(definition.rank, pool)
		.. packStringArray(definition.aliases, pool)

	local args = definition.args
	out ..= string.pack("<B", args and #args or 0)
	if args then
		for _, arg in args do
			out ..= packArgument(arg, pool)
		end
	end

	out ..= string.pack("<s1", definition.description or "")

	if definition.cooldown and definition.cooldown > 0 then
		out ..= string.pack("<Bf", 1, definition.cooldown)
	else
		out ..= string.pack("<B", 0)
	end

	if definition.server then
		out ..= string.pack("<BH", 1, pool.index[definition.server])
	else
		out ..= string.pack("<B", 0)
	end

	return out
end

local function unpackDefinition(data: string, pos: number, pool: { string }): (Definition, number)
	local name: string
	local argCount: number
	local description: string
	local cooldown: number
	name, pos = string.unpack("<s1", data, pos)

	local rank
	rank, pos = unpackRank(data, pos, pool)

	local aliases
	aliases, pos = unpackStringArray(data, pos, pool)

	argCount, pos = string.unpack("<B", data, pos)
	local args = {}
	for i = 1, argCount do
		args[i], pos = unpackArgument(data, pos, pool)
	end

	description, pos = string.unpack("<s1", data, pos)

	local cooldownTag: number
	cooldownTag, pos = string.unpack("<B", data, pos)
	if cooldownTag == 1 then
		cooldown, pos = string.unpack("<f", data, pos)
	else
		cooldown = 0
	end

	local serverTag: number
	serverTag, pos = string.unpack("<B", data, pos)
	local serverName: string?
	if serverTag == 1 then
		local idx
		idx, pos = string.unpack("<H", data, pos)
		serverName = pool[idx]
	end

	return {
		name = name,
		rank = rank,
		aliases = aliases,
		args = args,
		description = if description ~= "" then description else nil,
		cooldown = cooldown,
		server = serverName,
	}, pos
end

--[[
	@description a small dependency-free LZSS pass over the final packed bytes.
	Matches minMatch=4+ so a match (3-byte token, amortized ~3.125 with its
	control-bit) never costs more than the literals it replaces. Repeated
	byte sequences show up a lot here (e.g. many arguments share the same
	trailing type/flags/default/suggestions tag bytes), so this squeezes
	real repetition string.pack's fixed schema can't see on its own.
]]
local lzWindow = 4096
local lzMinMatch = 4
local lzMaxMatch = 255

local function lzCompress(data: string): string
	local n = #data
	local out = {}
	local controlIndex = 0
	local controlByte = 0
	local bitCount = 0

	local i = 1
	while i <= n do
		if bitCount == 0 then
			table.insert(out, "\0")
			controlIndex = #out
			controlByte = 0
		end

		local bestLen = 0
		local bestOffset = 0
		local limit = math.min(lzMaxMatch, n - i + 1)
		if limit >= lzMinMatch then
			local searchStart = math.max(1, i - lzWindow)
			for j = i - 1, searchStart, -1 do
				local len = 0
				while len < limit and string.byte(data, j + len) == string.byte(data, i + len) do
					len += 1
				end
				if len > bestLen then
					bestLen = len
					bestOffset = i - j
					if len == limit then
						break
					end
				end
			end
		end

		if bestLen >= lzMinMatch then
			table.insert(out, string.pack("<HB", bestOffset, bestLen))
			i += bestLen
		else
			controlByte = bit32.bor(controlByte, bit32.lshift(1, bitCount))
			table.insert(out, string.char(string.byte(data, i)))
			i += 1
		end

		bitCount += 1
		out[controlIndex] = string.char(controlByte)
		if bitCount == 8 then
			bitCount = 0
		end
	end

	return table.concat(out)
end

local function lzDecompress(data: string): string
	local n = #data
	local outChars = {}
	local outLen = 0
	local pos = 1

	while pos <= n do
		local control: number
		control, pos = string.unpack("<B", data, pos)
		for bitIndex = 0, 7 do
			if pos > n then
				break
			end
			if bit32.band(bit32.rshift(control, bitIndex), 1) == 1 then
				local byte
				byte, pos = string.unpack("<B", data, pos)
				outLen += 1
				outChars[outLen] = string.char(byte)
			else
				local offset, len
				offset, len, pos = string.unpack("<HB", data, pos)
				local start = outLen - offset
				for k = 1, len do
					outLen += 1
					outChars[outLen] = outChars[start + k]
				end
			end
		end
	end

	return table.concat(outChars, "", 1, outLen)
end

local function encodeDefinitions(list: { Definition }): buffer
	local pool = buildPool(list)
	local out = packPool(pool) .. string.pack("<H", #list)
	for _, definition in list do
		out ..= packDefinition(definition, pool)
	end
	return buffer.fromstring(lzCompress(out))
end

local function decodeDefinitions(payload: buffer): { Definition }
	local data = lzDecompress(buffer.tostring(payload))
	local pool, pos = unpackPool(data, 1)
	local count
	count, pos = string.unpack("<H", data, pos)
	local out = {}
	for i = 1, count do
		out[i], pos = unpackDefinition(data, pos, pool)
	end
	return out
end

local function currentDefinitions(): { Definition }
	local out: { Definition } = {}

	for _, kommand in Imports.Kommand.list() do
		table.insert(out, {
			description = kommand.description,

			cooldown = kommand.cooldown,
			aliases = kommand.aliases,
			server = kommand.server,

			name = kommand.name,
			rank = kommand.rank,
			args = kommand.args,
		})
	end

	return out
end

local function invokeServer(text: string): any
	local bridge = ensureRemote()

	if not bridge then
		return fail("no-bridge", "Command bridge is unavailable.")
	end

	local succeeded, response = pcall(function()
		return (bridge :: RemoteFunction):InvokeServer(text)
	end)

	if not succeeded then
		return fail("network-error", tostring(response))
	end

	if type(response) == "table" then
		return response
	end

	return ok(tostring(response or ""))
end

--// public api
--[[
	@description what Konsole.host() calls den sets up both remotes
	
	@time June 22, 2026 3:08 PM
]]
function Dispatch.host(serverImplementations: { [string]: Run }?)
	assert(Imports.RunService:IsServer(), "Dispatch.host can only be called on the server")

	for name, callback in serverImplementations or {} :: { [string]: Run } do
		if Imports.Table.callable(callback) then
			implementations[name] = callback
		end
	end

	local bridge = ensureRemote()

	if bridge then
		bridge.OnServerInvoke = function(player, text)
			return Dispatch.execute(text, player)
		end
	end

	local definitionsBridge = ensureDefinitionsRemote()

	if definitionsBridge then
		definitionsBridge.OnServerEvent:Connect(function(player)
			definitionsBridge:FireClient(player, encodeDefinitions(currentDefinitions()))
		end)

		Imports.Kommand.watch(function()
			definitionsBridge:FireAllClients(encodeDefinitions(currentDefinitions()))
		end)
	end

	return bridge
end

function Dispatch.implement(name: string, callback: Run)
	assert(type(name) == "string" and name ~= "", "implementation name must be a string")
	assert(Imports.Table.callable(callback), "implementation must be callable")

	implementations[name] = callback
end

--[[
	@description single entrypoint both console ui + Konsole.run() go through,
	the client forwards to server over remote unless the cmd has no `server` field
	
	@time June 9, 2026 7:41 PM
]]
function Dispatch.execute(text: any, entity: any): any
	text = tostring(text or "")

	local name, tokens = Imports.Arguments.split(text)

	if not name then
		return fail("empty", "Type a command.")
	end

	local kommand = Imports.Kommand.find(name)

	if not kommand then
		return fail("unknown-command", `unknown command "{name}"`)
	end

	if Imports.RunService:IsServer() then
		if not Imports.Ranks.allows(entity, kommand.rank) then
			return fail("not-authorized", `"{kommand.name}" requires rank {kommand.rank}+`)
		end

		return runDefinition(kommand, tokens, entity, text)
	end

	if kommand.server then
		return invokeServer(text)
	end

	local player = Imports.Players.LocalPlayer

	if not Imports.Ranks.allows(player, kommand.rank) then
		return fail("not-authorized", `"{kommand.name}" requires rank {kommand.rank}+`)
	end

	return runDefinition(kommand, tokens, player, text)
end

--[[ 
    @description server-defined commands should just work from the client console without
    ppl having to Konsole.define() them a second time on each client and server, as
    soon as this module loads on the client it asks the server for its current
    command list and keeps listening for late additions
    
    @time June 27, 2026 1:15 AM
]]
if Imports.RunService:IsClient() then
	task.spawn(function()
		local bridge = ensureDefinitionsRemote()

		if not bridge then
			return
		end

		bridge.OnClientEvent:Connect(function(payload: any)
			if typeof(payload) ~= "buffer" then
				return
			end

			local list = decodeDefinitions(payload)
			for _, definition in list :: { Definition } do
				Imports.Kommand.define(definition)
			end
		end)

		bridge:FireServer()
	end)
end

return table.freeze(Dispatch)
