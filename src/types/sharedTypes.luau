--!strict

--[[
	@name sharedTypes
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// types
export type Converter = (token: string, caller: Caller) -> (boolean, any)

export type Converters = { [string]: Converter }

export type Caller = Player?

export type Argument = {
	suggestions: ({ string } | string)?,
	required: boolean?,
	default: any,

	name: string?,
	type: string?,
}

export type Schemas = { [string]: { Argument } }
export type Provider = () -> { string }

export type Outcome = {
	message: string,
	code: string?,
	ok: boolean,
}

export type DispatchModule = {
	host: (serverImplementations: { [string]: Run }?) -> RemoteFunction?,
	implement: (name: string, callback: Run) -> (),
	execute: (text: any, entity: any) -> any,

	remoteName: string,
	timeout: number,
}

export type RanksModule = {
	define: (id: number, name: string, aliases: { string }?) -> Rank,
	set: (userId: any, rank: number | string) -> number,
	allows: (entity: any, required: any) -> boolean,

	resolve: (value: any) -> number?,
	get: (entity: any) -> number,
	bind: (fn: Resolver?) -> (),

	label: (id: number) -> string,
	list: () -> { Rank },
}

export type Context = {
	dispatch: DispatchModule,
	ranks: RanksModule,
	kommand: Command,

	err: (code: any?, message: any?) -> Outcome,
	reply: (message: any?) -> Outcome,
	run: (text: any) -> any,

	entity: Player?,
	text: string,
}

export type Run = (context: Context, ...any) -> any

export type OpenCallback = () -> ()
export type Disconnect = () -> ()
export type Watcher = () -> ()

export type Definition = {
	description: string?,
	aliases: { string }?,
	cooldown: number?,

	rank: (number | string)?,
	args: { Argument }?,
	server: string?,

	name: string,
	run: Run?,
}

export type Command = {
	description: string,
	aliases: { string },
	cooldown: number,

	args: { Argument },
	server: string?,
	rank: number,

	name: string,
	run: Run?,
}

export type Rank = {
	aliases: { string },
	builtin: boolean?,

	name: string,
	id: number,
}

export type DefaultRank = {
	aliases: { string }?,
	name: string,
	id: number,
}

export type Resolver = (entity: any) -> number?

return {}
