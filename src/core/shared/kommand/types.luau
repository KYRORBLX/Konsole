--[[
	@name types
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--!strict

export type Caller = Player?

export type Converter = (token: string, caller: Caller) -> (boolean, any)

export type Converters = { [string]: Converter }

export type Argument = {
	name: string?,
	type: string?,
	default: any,
	required: boolean?,
	suggestions: ({ string } | string)?,
}

export type Outcome = {
	ok: boolean,
	code: string?,
	message: string,
}

export type DispatchModule = {
	read remoteName: string,
	read timeout: number,
	read host: (serverImplementations: { [string]: Run }?) -> RemoteFunction?,
	read implement: (name: string, callback: Run) -> (),
	read execute: (text: any, entity: any) -> any,
}

export type RanksModule = {
	read define: (id: number, name: string, aliases: { string }?) -> Rank,
	read resolve: (value: any) -> number?,
	read label: (id: number) -> string,
	read list: () -> { Rank },
	read set: (userId: any, rank: any) -> number,
	read bind: (fn: Resolver?) -> (),
	read get: (entity: any) -> number,
	read allows: (entity: any, required: any) -> boolean,
}

export type Context = {
	entity: Player?,
	kommand: Command,
	text: string,
	dispatch: DispatchModule,
	ranks: RanksModule,
	run: (text: any) -> any,
	reply: (message: any?) -> Outcome,
	err: (code: any?, message: any?) -> Outcome,
}

export type Run = (context: Context, ...any) -> any

export type Watcher = () -> ()

export type Definition = {
	name: string,
	rank: (number | string)?,
	aliases: { string }?,
	args: { Argument }?,
	description: string?,
	cooldown: number?,
	server: string?,
	run: Run?,
}

export type Command = {
	name: string,
	rank: number,
	aliases: { string },
	args: { Argument },
	description: string,
	cooldown: number,
	server: string?,
	run: Run?,
}

export type Rank = {
	id: number,
	name: string,
	aliases: { string },
	builtin: boolean?,
}

export type Resolver = (entity: any) -> number?

return {}
