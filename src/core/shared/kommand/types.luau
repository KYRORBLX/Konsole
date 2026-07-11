--!strict

--[[
	@name types
	@author driftingAurora, dullflowerr
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

export type Outcome = {
    message: string,
    code: string?,
    ok: boolean,
}

export type DispatchModule = {
    read host: (serverImplementations: { [string]: Run }?) -> RemoteFunction?,
    read implement: (name: string, callback: Run) -> (),
    read execute: (text: any, entity: any) -> any,

    read remoteName: string,
    read timeout: number,
}

export type RanksModule = {
    read define: (id: number, name: string, aliases: { string }?) -> Rank,
    read allows: (entity: any, required: any) -> boolean,
    read set: (userId: any, rank: any) -> number,

    read resolve: (value: any) -> number?,
    read get: (entity: any) -> number,
    read bind: (fn: Resolver?) -> (),
    
    read label: (id: number) -> string,
    read list: () -> { Rank },
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

export type Resolver = (entity: any) -> number?

return {}