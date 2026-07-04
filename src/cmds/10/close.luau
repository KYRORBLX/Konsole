--[[
	@name close
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

return table.freeze({
	name = "close",
	rank = 0,
	aliases = { "exit" },
	description = "Closes the console UI.",
	run = function(context)
		return context.reply("closed")
	end,
})
