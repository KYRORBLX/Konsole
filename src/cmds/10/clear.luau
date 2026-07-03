return table.freeze({
	name = "clear",
	rank = 0,
	aliases = { "cls" },
	description = "Clears the console output.",
	run = function(context)
		return context.reply("cleared")
	end,
})