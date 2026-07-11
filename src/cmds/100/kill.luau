--[[
	@name kill
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

export type Definition = Types.Definition

return table.freeze({
	name = "kill",
	rank = 100,
	aliases = { "slay" },
	description = "Kills the target player.",
	server = "killServer",
	args = {
		{
			name = "target",
			type = "player",
			required = true,
			suggestions = { "me", "all" },
		},
	},
}) :: Definition
