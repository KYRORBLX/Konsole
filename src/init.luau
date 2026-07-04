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

local Konsole = {
	Arguments = imports.core.shared.arguments,
	Dispatch = imports.core.shared.dispatch,
	Result = imports.core.ui.render.Result,

	Kommand = imports.core.shared.kommand,
	Ranks = imports.core.shared.ranks,
	Chat = imports.core.shared.chat,
	Render = imports.core.ui.render,

	Config = imports.config,
} :: { [string]: any }

local registered = false
local defaultClient: Client = nil

local function registerBuiltins(): ()
	if registered then
		return
	end
	registered = true
	imports.cmds.register(imports.core.shared.kommand)
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

local function forward(method: string)
	Konsole[method] = function(...: any): ...any
		return callDefault(method, ...)
	end
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

for _, method in
	{
		"setActivationUnlocksMouse",
		"setMouseUnlockDriver",
		"setActivationKeys",
		"setSuggestions",
		"getCursorTarget",
		"setEnabled",
		"setSchemas",
		"bindRun",
		"toggle",
		"focus",
		"clear",
		"show",
		"hide",
	}
do
	forward(method)
end

if imports.RunService:IsClient() then
	imports.core.shared.chat.bindKonsoleOpen(function()
		callDefault("show")
	end)
end

return table.freeze(Konsole)
