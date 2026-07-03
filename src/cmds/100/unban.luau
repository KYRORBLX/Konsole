--[[
	@name unban
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

--!strict

local Types = require("../../core/shared/kommand/types")

export type Definition = Types.Definition

local definition: Definition = {
	name = "unban",
	rank = 100,
	aliases = {},
	description = "Unbans a user ID from this server.",
	server = "unbanServer",
	args = {
		{
			name = "userId",
			type = "number",
			required = true,
		},
	},
}

return table.freeze(definition)
