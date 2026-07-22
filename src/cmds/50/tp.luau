--[[
	@name tp
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 23, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

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
