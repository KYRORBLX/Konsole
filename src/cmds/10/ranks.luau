--[[
	@name ranks
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

export type Definition = Types.Definition

return table.freeze({
	name = "ranks",
	rank = 10,
	aliases = { "ranklist", "roles" },
	description = "Lists every rank registered in the game.",
	run = function(context: Types.Context)
		local rows = {}
		for _, rank in context.ranks.list() do
			table.insert(rows, {
				Rank = rank.name,
				Id = tostring(rank.id),
				Source = rank.builtin and "built-in" or "custom",
				Aliases = #rank.aliases > 0 and table.concat(rank.aliases, ", ") or "—",
			})
		end

		return {
			ok = true,
			kind = "table",
			title = "Ranks",
			message = `{#rows} registered`,
			width = "wide",
			columns = { "Rank", "Id", "Source", "Aliases" },
			rows = rows,
		}
	end,
}) :: Definition
