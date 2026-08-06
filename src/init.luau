--!strict

--[[
	@name Konsole
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Imports = {
	RunService = game:GetService("RunService"),

	Config = require("@self/config"),
	Cmds = require("@self/cmds"),
	Core = require("@self/core"),
}

local Types = require("@self/types/sharedTypes")
local UITypes = require("@self/types/uiTypes")

--// types
export type Definition = Types.Definition
export type Resolver = Types.Resolver
export type Outcome = Types.Outcome

export type Command = Types.Command
export type Context = Types.Context
export type Run = Types.Run

type Client = UITypes.Client

--// locals
local defaultClient: Client? = nil
local registered = false
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
		for _, definition in Imports.Cmds.definitions do
			if not builtinsIncluded[definition.name] then
				excluded[definition.name] = true
			end
		end
	end

	Imports.Cmds.register(Imports.Core.shared.kommand, excluded)
end

local function getDefaultClient(): Client
	if defaultClient then
		return defaultClient
	end

	assert(Imports.RunService:IsClient(), "Konsole, can only be created on the client!")

	registerBuiltins()
	local client: Client = Imports.Core.ui.render.new()

	client:bindRun(function(text: string)
		return Imports.Core.shared.dispatch.execute(text)
	end)

	client:setSuggestions(Imports.Core.shared.kommand.suggestions())
	client:setSchemas(Imports.Core.shared.kommand.schemas())

	Imports.Core.shared.kommand.watch(function()
		if defaultClient == client then
			client:setSuggestions(Imports.Core.shared.kommand.suggestions())

			client:setSchemas(Imports.Core.shared.kommand.schemas())
		end
	end)

	defaultClient = client
	return client
end

local function callDefault(method: string, ...: any): ...any
	local client = getDefaultClient()
	return client[method](client, ...)
end

--// public api
local Konsole = {
	Arguments = Imports.Core.shared.arguments,
	Dispatch = Imports.Core.shared.dispatch,
	Result = Imports.Core.ui.render.Result,

	Kommand = Imports.Core.shared.kommand,
	Ranks = Imports.Core.shared.ranks,
	Chat = Imports.Core.shared.chat,

	Render = Imports.Core.ui.render,
	Config = Imports.Config,
}

function Konsole.create(options: any?): Client
	registerBuiltins()
	return Imports.Core.ui.render.new(options)
end

--[[
	@description opt out of specific built-in commands (bring/clear/close/ranks/
	unban/cmds/kick/kill/ban/tp) so they don't register or replicate at all.
	Must be called before Konsole.create/host/run/define first runs.
	@see Konsole.excludeAllBuiltins
	@time July 28, 2026
]]
function Konsole.excludeBuiltins(...: string): ()
	assert(not registered, "Konsole.excludeBuiltins must be called before Konsole is used")
	assert(builtinsIncluded == nil, "Konsole.excludeBuiltins cannot be used together with Konsole.includeBuiltins")

	if Imports.RunService:IsClient() then
		warn("Konsole.excludeBuiltins does nothing on the client, the server's definition list is what replicates. Call it on the server.")
	end

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

	if Imports.RunService:IsClient() then
		warn("Konsole.excludeAllBuiltins does nothing on the client, the server's definition list is what replicates. Call it on the server.")
	end

	builtinsExcluded = { all = true }
end

--[[
	@description opposite of excludeBuiltins: drops every built-in EXCEPT the
	names passed, e.g. Konsole.includeBuiltins("ban", "tp") keeps only those two.
	cmds/clear stay registered regardless. Must be called before Konsole is used.
	@time July 28, 2026
]]
function Konsole.includeBuiltins(...: string): ()
	assert(not registered, "Konsole.includeBuiltins must be called before Konsole is used")
	assert(builtinsExcluded == nil, "Konsole.includeBuiltins cannot be used together with Konsole.excludeBuiltins")

	if Imports.RunService:IsClient() then
		warn("Konsole.includeBuiltins does nothing on the client, the server's definition list is what replicates. Call it on the server.")
	end

	local set = {}
	for _, name in { ... } do
		set[name] = true
	end
	builtinsIncluded = set
end

--[[
	@description server only, so we only call once this wires the remote bridge + registers built ins,
	pass a name -> fn table here as a shortcut instead of calling implement() per cmd
	@time June 30, 2026 8:50 PM
]]
function Konsole.host(serverImplementations: { [string]: Run }?): RemoteFunction?
	registerBuiltins()

	local implementations = table.clone(Imports.Cmds.server) :: { [string]: Run }

	for name, callback in serverImplementations or {} :: { [string]: Run } do
		implementations[name] = callback
	end

	return Imports.Core.shared.dispatch.host(implementations)
end

--[[
	@description registers a cmd's schema, doesn't run anything itself so server cmds
	auto replicate to clients now ^_^ only client only cmds (inline run) need defining client side too
	@see Konsole.implement
	@time June 30, 2026 9:20 PM
]]
function Konsole.define(definition: Definition): Command
	return Imports.Core.shared.kommand.define(definition)
end

--[[
	@description server only, binds the handler for a cmd's `server` name
	@see Konsole.define
	@time June 30, 2026 9:26 PM
]]
function Konsole.implement(name: string, callback: Run): ()
	Imports.Core.shared.dispatch.implement(name, callback)
end

--[[
	@description runs a cmd string programmatically, same path as typing it in console
	@time June 13, 2026 6:30 AM
]]
function Konsole.run(text: string): Outcome
	registerBuiltins()
	return Imports.Core.shared.dispatch.execute(text)
end

--[[
	@description sets a user's konsole rank, accepts either a user id or anything the rank system can resolve,
	the rank can be its number directly or the name of a registered rank
	@see Konsole.getRank
	@time August 1, 2026 1:04 PM
]]
function Konsole.setRank(userId: any, rank: number | string): number
	return Imports.Core.shared.ranks.set(userId, rank)
end

--[[
	@description gets the resolved konsole rank for a player, user id, or any other supported entity,
	returns the rank's numeric level
	@see Konsole.setRank
	@time August 1, 2026 1:04 PM
]]
function Konsole.getRank(entity: any): number
	return Imports.Core.shared.ranks.get(entity)
end

--[[
	@description server ONLY !! plug in your own rank resolver instead of the built in store if u want tho,
	return nil to fall through to setRank/defaults
	@time June 13, 2026 6:58 AM
]]
function Konsole.bindRanks(resolver: Resolver?): ()
	Imports.Core.shared.ranks.bind(resolver)
end

--[[
	@description destroys the default konsole client and cleans up its ui, connections, and other resources,
	does nothing if a default client hasn't been created
	@time August 1, 2026 1:04 PM
]]
function Konsole.destroy(): ()
	if defaultClient then
		defaultClient:destroy()
		defaultClient = nil
	end
end

--[[
	@description controls whether opening konsole automatically unlocks the player's mouse,
	disable this if your game handles mouse behavior itself
	@see Konsole.setMouseUnlockDriver
	@time August 1, 2026 1:04 PM
]]
function Konsole.setActivationUnlocksMouse(enabled: boolean): ()
	callDefault("setActivationUnlocksMouse", enabled)
end

--[[
	@description replaces the default mouse unlock logic with your own getter and setter,
	getFn should return whether the mouse is unlocked and setFn should apply the new state
	@see Konsole.setActivationUnlocksMouse
	@time August 1, 2026 1:04 PM
]]
function Konsole.setMouseUnlockDriver(getFn: (() -> boolean)?, setFn: ((boolean) -> ())?): ()
	callDefault("setMouseUnlockDriver", getFn, setFn)
end

--[[
	@description changes which keyboard keys can open or close konsole,
	pass every key u want accepted as an array of Enum.KeyCode values
	@time August 1, 2026 1:04 PM
]]
function Konsole.setActivationKeys(keys: { Enum.KeyCode }): ()
	callDefault("setActivationKeys", keys)
end

--[[
	@description replaces the current autocomplete suggestion list shown while typing,
	use this for custom words or values that aren't already supplied by command schemas
	@see Konsole.setSchemas
	@time August 1, 2026 1:04 PM
]]
function Konsole.setSuggestions(list: { string }): ()
	callDefault("setSuggestions", list)
end

--[[
	@description gets the instance currently underneath the player's cursor,
	returns nil if the cursor isn't targeting anything or the default client doesn't exist
	@time August 1, 2026 1:04 PM
]]
function Konsole.getCursorTarget(): Instance?
	return callDefault("getCursorTarget")
end

--[[
	@description controls whether the default konsole client can be opened and interacted with,
	disabling it also prevents normal activation keys from opening the console
	@time August 1, 2026 1:04 PM
]]
function Konsole.setEnabled(enabled: boolean): ()
	callDefault("setEnabled", enabled)
end

--[[
	@description replaces the command schema map used by the client for autocomplete, argument hints,
	and other command information shown while the player is typing
	@see Konsole.define
	@see Konsole.setSuggestions
	@time August 1, 2026 1:04 PM
]]
function Konsole.setSchemas(map: { [string]: any }): ()
	callDefault("setSchemas", map)
end

--[[
	@description binds the callback used whenever text is submitted through the default konsole client,
	the full entered command string is passed into the callback
	@see Konsole.run
	@time August 1, 2026 1:04 PM
]]
function Konsole.bindRun(callback: (text: string) -> any): ()
	callDefault("bindRun", callback)
end

--[[
	@description toggles the default konsole between shown and hidden,
	so open becomes closed and closed becomes open
	@see Konsole.show
	@see Konsole.hide
	@time August 1, 2026 1:04 PM
]]
function Konsole.toggle(): ()
	callDefault("toggle")
end

--[[
	@description focuses the default konsole's input box so the player can instantly start typing,
	normally useful after manually showing the console
	@see Konsole.show
	@time August 1, 2026 1:04 PM
]]
function Konsole.focus(): ()
	callDefault("focus")
end

--[[
	@description clears all currently displayed output from the default konsole,
	this only clears the visible history and doesn't remove cmds or schemas
	@time August 1, 2026 1:04 PM
]]
function Konsole.clear(): ()
	callDefault("clear")
end

--[[
	@description shows the default konsole ui without changing its enabled state,
	use focus() after if u also want the input box selected
	@see Konsole.focus
	@see Konsole.hide
	@time August 1, 2026 1:04 PM
]]
function Konsole.show(): ()
	callDefault("show")
end

--[[
	@description hides the default konsole ui without fully disabling or destroying it,
	it can still be opened again through show(), toggle(), or its activation keys
	@see Konsole.show
	@see Konsole.toggle
	@time August 1, 2026 1:04 PM
]]
function Konsole.hide(): ()
	callDefault("hide")
end

export type Api = typeof(Konsole)

if Imports.RunService:IsClient() then
	Imports.Core.shared.chat.bindKonsoleOpen(function()
		callDefault("show")
	end)
end

return table.freeze(Konsole)
