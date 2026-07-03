--[[
	@name tp
	@author driftingAurora, dullflowerr
	@time June 23, 2026
]]

--!strict

local Types = require("../../core/shared/kommand/types")

export type Definition = Types.Definition

return table.freeze({
	name = "tp",
	rank = 50,
	aliases = { "teleport", "goto" },
	description = "Teleports you to the target player.",
	server = "tpServer",
	args = {
		{
			name = "target",
			type = "player",
			required = true,
		},
	},
}) :: Definition
