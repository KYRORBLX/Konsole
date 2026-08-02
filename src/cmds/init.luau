--!strict

--[[
	@name cmds
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

local Imports = {
	Unban = require("@self/100/unban"),
	Bring = require("@self/50/bring"),
	Ranks = require("@self/10/ranks"),

	Clear = require("@self/10/clear"),
	Close = require("@self/10/close"),
	Server = require("@self/server"),

	Kick = require("@self/100/kick"),
	Kill = require("@self/100/kill"),
	Cmds = require("@self/10/cmds"),

	Ban = require("@self/100/ban"),
	TP = require("@self/50/tp"),
}

local Types = require("./types/sharedTypes")

export type Definition = Types.Definition
export type Run = Types.Run

local Cmds = {
	definitions = table.freeze({
		(Imports.Clear :: any) :: Definition,
		(Imports.Close :: any) :: Definition,

		Imports.Unban,
		Imports.Bring,
		Imports.Ranks,

		Imports.Kill,
		Imports.Cmds,
		Imports.Kick,

		Imports.Ban,

		Imports.TP,
	}) :: { Definition },
	server = Imports.Server :: { [string]: Run },
}

function Cmds.register(kommand: any)
	for index, definition in Cmds.definitions do
		assert(type(definition.name) == "string", `invalid built-in command at index {index}`)

		kommand.define(definition)
	end
end

return table.freeze(Cmds)
