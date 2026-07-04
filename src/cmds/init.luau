--[[
	@name cmds
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	--// B/R
	bring = require("@self/50/bring"),
	ranks = require("@self/10/ranks"),

	--// S
	server = require("@self/server"),

	--// C
	clear = require("@self/10/clear"),
	close = require("@self/10/close"),
	cmds = require("@self/10/cmds"),

	--// K
	kick = require("@self/100/kick"),
	kill = require("@self/100/kill"),

	--// U/B
	ban = require("@self/100/ban"),
	unban = require("@self/100/unban"),

	--// T
	tp = require("@self/50/tp"),
}

local Types = require("./core/shared/kommand/types")

export type Definition = Types.Definition
export type Run = Types.Run

local Cmds = {
	definitions = table.freeze({
		imports.bring,
		imports.clear,
		imports.close,
		imports.ranks,
		imports.unban,
		imports.cmds,
		imports.kick,
		imports.kill,
		imports.ban,
		imports.tp,
	}) :: { Definition },
	server = imports.server :: { [string]: Run },
}

function Cmds.register(kommand: any)
	for index, definition in Cmds.definitions do
		assert(type(definition.name) == "string", `invalid built-in command at index {index}`)
		kommand.define(definition)
	end
end

return table.freeze(Cmds)
