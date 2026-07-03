--[[
	@name clear
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

return table.freeze({
	name = "clear",
	rank = 0,
	aliases = { "cls" },
	description = "Clears the console output.",
	run = function(context)
		return context.reply("cleared")
	end,
})
