--[[
	@name bring
	@author driftingAurora, dullflowerr
	@time June 23, 2026
]]

--!strict

local Types = require("../../core/shared/kommand/types")

export type Definition = Types.Definition

return table.freeze({
	name = "bring",
	rank = 50,
	aliases = { "fetch" },
	description = "Teleports the target players to you.",
	server = "bringServer",
	args = {
		{
			name = "targets",
			type = "players",
			required = true,
			suggestions = { "me", "all", "others" },
		},
	},
}) :: Definition
