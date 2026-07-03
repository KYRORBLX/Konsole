--[[
	@name cmds
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	ban = require("@self/100/ban"),
	bring = require("@self/50/bring"),
	ranks = require("@self/10/ranks"),
	clear = require("@self/10/clear"),
	cmds = require("@self/10/cmds"),
	kick = require("@self/100/kick"),
	kill = require("@self/100/kill"),
	server = require("@self/server"),
	tp = require("@self/50/tp"),
	unban = require("@self/100/unban"),
}

local Types = require("./core/shared/kommand/types")

export type Definition = Types.Definition
export type Run = Types.Run

local Cmds = {
	definitions = table.freeze({
		imports.ban,
		imports.bring,
		imports.clear,
		imports.cmds,
		imports.kick,
		imports.kill,
		imports.ranks,
		imports.tp,
		imports.unban,
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
