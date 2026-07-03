--[[
	@name kick
	@author driftingAurora, dullflowerr
	@time June 23, 2026
]]

--!strict

local Types = require("../../core/shared/kommand/types")

export type Definition = Types.Definition

return table.freeze({
	name = "kick",
	rank = 100,
	aliases = { "boot" },
	description = "Kicks the target player.",
	server = "kickServer",
	args = {
		{
			name = "target",
			type = "player",
			required = true,
			suggestions = { "me" },
		},
		{
			name = "reason",
			type = "string",
			required = false,
			default = "Kicked by a moderator.",
		},
	},
}) :: Definition
