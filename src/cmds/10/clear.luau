--[[
	@name clear
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time July 3, 2026
]]

return table.freeze({
	name = "clear",
	rank = 0,
	aliases = { "cls", "clr" },
	description = "Clears the console output.",
	run = function(context)
		return context.reply("cleared")
	end,
})
