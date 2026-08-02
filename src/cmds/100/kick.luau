--!strict

--[[
	@name kick
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 23, 2026
]]

local Types = require("../../types/sharedTypes")

export type Definition = Types.Definition

return table.freeze({
	name = "kick",
	rank = 100,
	aliases = { "boot" },
	description = "Kicks the target player.",
	server = "kickServer",
	args = {
		({
			name = "target",
			type = "player",
			required = true,
			suggestions = { "me" },
		} :: Types.Argument),
		({
			name = "reason",
			type = "string",
			required = false,
			default = "Kicked by a moderator.",
		} :: Types.Argument),
	},
}) :: Definition
