--[[
	@name dispatch
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--!strict

local imports = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	RunService = game:GetService("RunService"),

	Arguments = require("./kommand/arguments"),
	Kommand = require("./kommand"),
	Ranks = require("@self/ranks"),
	Table = require("./kommand/table"),
}

local Types = require("./kommand/types")

export type Command = Types.Command
export type Context = Types.Context
export type Definition = Types.Definition
export type Outcome = Types.Outcome
export type Run = Types.Run

local Dispatch = {
	definitionsRemoteName = "KonsoleDefinitions",
	remoteName = "Konsole",
	timeout = 8,
}

local implementations: { [string]: Run } = {}
local cooldowns: { [string]: { [string]: number } } = {}
local remote: RemoteFunction? = nil
local definitionsRemote: RemoteEvent? = nil

local function ok(message: any?): Outcome
	return { ok = true, message = tostring(message or "Command completed.") }
end

local function fail(code: any?, message: any?): Outcome
	return { ok = false, code = tostring(code or "error"), message = tostring(message or "Command failed.") }
end

local function contextFor(kommand: Command, entity: any, text: string): Context
	return {
		entity = entity,
		kommand = kommand,
		text = text,
		dispatch = Dispatch,
		ranks = imports.Ranks,
		run = function(nextText: any): any
			return Dispatch.execute(nextText, entity)
		end,
		reply = ok,
		err = fail,
	}
end

local function cooldownKey(entity: any): string
	if typeof(entity) == "Instance" and entity:IsA("Player") then
		return tostring(entity.UserId)
	end

	return tostring(entity or "server")
end

local function checkCooldown(kommand: Command, entity: any): Outcome?
	if kommand.cooldown <= 0 then
		return nil
	end

	local now = os.clock()
	local bucket = cooldowns[kommand.name]
	local key = cooldownKey(entity)
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
	if imports.RunService:IsServer() and kommand.server then
		callback = implementations[kommand.server] or callback
	end
	if not imports.Table.callable(callback) then
		return fail("not-implemented", `"{kommand.name}" has no implementation on this side`)
	end
	local parsed, values = imports.Arguments.parse(kommand.args, tokens, entity)
	if not parsed then
		return fail("bad-argument", values)
	end
	local cooldown = checkCooldown(kommand, entity)
	if cooldown then
		return cooldown
	end

	local succeeded, result = pcall(callback :: Run, contextFor(kommand, entity, text), table.unpack(values))
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

	if imports.RunService:IsServer() then
		local bridge = imports.ReplicatedStorage:FindFirstChild(Dispatch.remoteName) or Instance.new("RemoteFunction")
		bridge.Name = Dispatch.remoteName
		bridge.Parent = imports.ReplicatedStorage
		remote = bridge :: RemoteFunction
	else
		remote = imports.ReplicatedStorage:WaitForChild(Dispatch.remoteName, Dispatch.timeout) :: RemoteFunction?
	end

	return remote
end

local function ensureDefinitionsRemote(): RemoteEvent?
	if definitionsRemote and definitionsRemote.Parent then
		return definitionsRemote
	end

	if imports.RunService:IsServer() then
		local bridge = imports.ReplicatedStorage:FindFirstChild(Dispatch.definitionsRemoteName)
			or Instance.new("RemoteEvent")
		bridge.Name = Dispatch.definitionsRemoteName
		bridge.Parent = imports.ReplicatedStorage
		definitionsRemote = bridge :: RemoteEvent
	else
		definitionsRemote =
			imports.ReplicatedStorage:WaitForChild(Dispatch.definitionsRemoteName, Dispatch.timeout) :: RemoteEvent?
	end

	return definitionsRemote
end

--[[ 
	@description fns can't cross a Remote so a kommand is stripped down to its
 	plain-data schema before being sent to clients (server stays authoritative of course
	on `run` clients only need enough to route the call back via `server`)
	
	@time June 4, 2026 11:52 AM
]]
local function currentDefinitions(): { Definition }
	local out: { Definition } = {}
	for _, kommand in imports.Kommand.list() do
		table.insert(out, {
			name = kommand.name,
			rank = kommand.rank,
			aliases = kommand.aliases,
			args = kommand.args,
			description = kommand.description,
			cooldown = kommand.cooldown,
			server = kommand.server,
		})
	end

	return out
end

--[[
	@description what Konsole.host() calls den sets up both remotes
	
	@time June 22, 2026 3:08 PM
]]
function Dispatch.host(serverImplementations: { [string]: Run }?)
	assert(imports.RunService:IsServer(), "Dispatch.host can only be called on the server")

	for name, callback in serverImplementations or {} :: { [string]: Run } do
		if imports.Table.callable(callback) then
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
			definitionsBridge:FireClient(player, currentDefinitions())
		end)
		imports.Kommand.watch(function()
			definitionsBridge:FireAllClients(currentDefinitions())
		end)
	end

	return bridge
end

function Dispatch.implement(name: string, callback: Run)
	assert(type(name) == "string" and name ~= "", "implementation name must be a string")
	assert(imports.Table.callable(callback), "implementation must be callable")
	implementations[name] = callback
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

--[[
	@description single entrypoint both console ui + Konsole.run() go through,
	the client forwards to server over remote unless the cmd has no `server` field
	
	@time June 9, 2026 7:41 PM
]]
function Dispatch.execute(text: any, entity: any): any
	text = tostring(text or "")
	local name, tokens = imports.Arguments.split(text)
	if not name then
		return fail("empty", "Type a command.")
	end

	local kommand = imports.Kommand.find(name)
	if not kommand then
		return fail("unknown-command", `unknown command "{name}"`)
	end

	if imports.RunService:IsServer() then
		if not imports.Ranks.allows(entity, kommand.rank) then
			return fail("not-authorized", `"{kommand.name}" requires rank {kommand.rank}+`)
		end
		return runDefinition(kommand, tokens, entity, text)
	end

	if kommand.server then
		return invokeServer(text)
	end

	return runDefinition(kommand, tokens, imports.Players.LocalPlayer, text)
end

--[[ 
    @description server-defined commands should just work from the client console without
    ppl having to Konsole.define() them a second time on each client and server, as
    soon as this module loads on the client it asks the server for its current
    command list and keeps listening for late additions
    
    @time June 27, 2026 1:15 AM
]]
if imports.RunService:IsClient() then
	task.spawn(function()
		local bridge = ensureDefinitionsRemote()
		if not bridge then
			return
		end

		bridge.OnClientEvent:Connect(function(list: any)
			if type(list) ~= "table" then
				return
			end
			for _, definition in list :: { Definition } do
				imports.Kommand.define(definition)
			end
		end)

		bridge:FireServer()
	end)
end

return table.freeze(Dispatch)
