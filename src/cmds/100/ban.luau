--[[
	@name ban
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time July 3, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

export type Definition = Types.Definition

return table.freeze({
	name = "ban",
	rank = 100,
	aliases = {},
	description = "Bans the target player from this server.",
	server = "banServer",
	args = {
		{
			name = "target",
			type = "players",
			required = true,
			suggestions = { "me", "others" },
		},
		{
			name = "reason",
			type = "string",
			required = false,
			default = "Banned from this server.",
		},
	},
}) :: Definition
