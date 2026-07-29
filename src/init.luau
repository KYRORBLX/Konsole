--[[
	@name Konsole
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	RunService = game:GetService("RunService"),

	config = require("@self/config"),
	cmds = require("@self/cmds"),
	core = require("@self/core"),
}

local Types = require("@self/core/shared/kommand/types")

export type Definition = Types.Definition
export type Resolver = Types.Resolver
export type Outcome = Types.Outcome
export type Command = Types.Command
export type Context = Types.Context
export type Run = Types.Run

type Client = any

export type BuiltinName = "bring" | "clear" | "close" | "ranks" | "unban" | "cmds" | "kick" | "kill" | "ban" | "tp"

local Konsole = {
	Arguments = imports.core.shared.arguments,
	Dispatch = imports.core.shared.dispatch,
	Result = imports.core.ui.render.Result,

	Kommand = imports.core.shared.kommand,
	Ranks = imports.core.shared.ranks,
	Chat = imports.core.shared.chat,
	Render = imports.core.ui.render,

	Config = imports.config,
}

local registered = false
local defaultClient: Client = nil
local builtinsExcluded: { [string]: boolean }? = nil
local builtinsIncluded: { [string]: boolean }? = nil

local function registerBuiltins(): ()
	if registered then
		return
	end
	registered = true

	local excluded = builtinsExcluded
	if builtinsIncluded then
		excluded = {}
		for _, definition in imports.cmds.definitions do
			if not builtinsIncluded[definition.name] then
				excluded[definition.name] = true
			end
		end
	end

	imports.cmds.register(imports.core.shared.kommand, excluded)
end

--[[
	@description opt out of specific built-in commands (bring/clear/close/ranks/
	unban/cmds/kick/kill/ban/tp) so they don't register or replicate at all.
	Must be called before Konsole.create/host/run/define first runs.
	@see Konsole.excludeAllBuiltins
	@time July 28, 2026
]]
function Konsole.excludeBuiltins(...: BuiltinName): ()
	assert(not registered, "Konsole.excludeBuiltins must be called before Konsole is used")
	assert(builtinsIncluded == nil, "Konsole.excludeBuiltins cannot be used together with Konsole.includeBuiltins")

	local set = {}
	for _, name in { ... } do
		set[name] = true
	end
	builtinsExcluded = set
end

--[[
	@description drops every built-in command. Must be called before Konsole
	is used.
	@time July 28, 2026
]]
function Konsole.excludeAllBuiltins(): ()
	assert(not registered, "Konsole.excludeAllBuiltins must be called before Konsole is used")
	assert(builtinsIncluded == nil, "Konsole.excludeAllBuiltins cannot be used together with Konsole.includeBuiltins")
	builtinsExcluded = { all = true }
end

--[[
	@description opposite of excludeBuiltins: drops every built-in EXCEPT the
	names passed, e.g. Konsole.includeBuiltins("ban", "tp") keeps only those two.
	cmds/clear stay registered regardless. Must be called before Konsole is used.
	@time July 28, 2026
]]
function Konsole.includeBuiltins(...: BuiltinName): ()
	assert(not registered, "Konsole.includeBuiltins must be called before Konsole is used")
	assert(builtinsExcluded == nil, "Konsole.includeBuiltins cannot be used together with Konsole.excludeBuiltins")

	local set = {}
	for _, name in { ... } do
		set[name] = true
	end
	builtinsIncluded = set
end

local function getDefaultClient(): Client
	if defaultClient then
		return defaultClient
	end

	assert(imports.RunService:IsClient(), "Konsole, can only be created on the client!")
	registerBuiltins()

	local client: Client = imports.core.ui.render.new()
	client:bindRun(function(text: string)
		return imports.core.shared.dispatch.execute(text)
	end)
	client:setSuggestions(imports.core.shared.kommand.suggestions())
	client:setSchemas(imports.core.shared.kommand.schemas())
	imports.core.shared.kommand.watch(function()
		if defaultClient == client then
			client:setSuggestions(imports.core.shared.kommand.suggestions())
			client:setSchemas(imports.core.shared.kommand.schemas())
		end
	end)

	defaultClient = client
	return client
end

local function callDefault(method: string, ...: any): ...any
	local client = getDefaultClient()
	return client[method](client, ...)
end

--[[
	@description register a custom argument type usable in `args = { { type = name } }`,
	e.g. Konsole.registerType("team", function(token, caller) ... end).
	Converter shape matches the built-ins: (token, caller) -> (ok, valueOrError).
	@time July 28, 2026
]]
function Konsole.registerType(name: string, converter: (token: string, caller: Player?) -> (boolean, any)): ()
	imports.core.shared.arguments.register(name, converter)
end

function Konsole.create(options: any?): Client
	registerBuiltins()
	return imports.core.ui.render.new(options)
end

--[[
	@description server only, soo we only call once this wires the remote bridge + registrars built ins,
	pass a name -> fn table here as a shortcut instead of calling implement() per cmd
	@time June 30, 2026 8:50 PM
]]
function Konsole.host(serverImplementations: { [string]: Run }?): RemoteFunction?
	registerBuiltins()
	local implementations = table.clone(imports.cmds.server) :: { [string]: Run }
	for name, callback in serverImplementations or {} :: { [string]: Run } do
		implementations[name] = callback
	end

	return imports.core.shared.dispatch.host(implementations)
end

--[[
	@description registers a cmd's schema, doesn't run anything itself so server cmds
	auto replicate to clients now ^_^ only client only cmds (inline run) need defining client side too
	@see Konsole.implement
	@time June 30, 2026 9:20 PM
]]
function Konsole.define(definition: Definition): Command
	return imports.core.shared.kommand.define(definition)
end

--[[
	@description server only, binds the handler for a cmd's `server` name
	@see Konsole.define
	@time June 30, 2026 9:26 PM
]]
function Konsole.implement(name: string, callback: Run): ()
	imports.core.shared.dispatch.implement(name, callback)
end

--[[
	@description runs a cmd string programmatically, same path as typing it in console
	@time June 13, 2026 6:30 AM	
]]
function Konsole.run(text: string): Outcome
	registerBuiltins()
	return imports.core.shared.dispatch.execute(text)
end

function Konsole.setRank(userId: any, rank: any): number
	return imports.core.shared.ranks.set(userId, rank)
end

function Konsole.getRank(entity: any): number
	return imports.core.shared.ranks.get(entity)
end

--[[
	@description server ONLY !! plug in your own rank resolver instead of the built in store if u want tho,
	return nil to fall through to setRank/defaults
	@time June 13, 2026 6:58 AM
]]
function Konsole.bindRanks(resolver: Resolver?): ()
	imports.core.shared.ranks.bind(resolver)
end

function Konsole.destroy(): ()
	if defaultClient then
		defaultClient:destroy()
		defaultClient = nil
	end
end

function Konsole.setActivationUnlocksMouse(enabled: boolean): ()
	callDefault("setActivationUnlocksMouse", enabled)
end

function Konsole.setMouseUnlockDriver(getFn: (() -> boolean)?, setFn: ((boolean) -> ())?): ()
	callDefault("setMouseUnlockDriver", getFn, setFn)
end

function Konsole.setActivationKeys(keys: { Enum.KeyCode }): ()
	callDefault("setActivationKeys", keys)
end

function Konsole.setSuggestions(list: { string }): ()
	callDefault("setSuggestions", list)
end

function Konsole.getCursorTarget(): Instance?
	return callDefault("getCursorTarget")
end

function Konsole.setEnabled(enabled: boolean): ()
	callDefault("setEnabled", enabled)
end

function Konsole.setSchemas(map: { [string]: any }): ()
	callDefault("setSchemas", map)
end

function Konsole.bindRun(callback: (text: string) -> any): ()
	callDefault("bindRun", callback)
end

function Konsole.toggle(): ()
	callDefault("toggle")
end

function Konsole.focus(): ()
	callDefault("focus")
end

function Konsole.clear(): ()
	callDefault("clear")
end

function Konsole.show(): ()
	callDefault("show")
end

function Konsole.hide(): ()
	callDefault("hide")
end

export type Api = typeof(Konsole)

if imports.RunService:IsClient() then
	imports.core.shared.chat.bindKonsoleOpen(function()
		callDefault("show")
	end)
end

return table.freeze(Konsole)
