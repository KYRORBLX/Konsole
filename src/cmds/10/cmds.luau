--!strict

local imports = {
	Kommand = require("../../core/shared/kommand"),
}

local Types = require("../../core/shared/kommand/types")

export type Definition = Types.Definition

local function formatArg(arg: Types.Argument): string
	local name = tostring(arg.name or "arg")
	local kind = tostring(arg.type or "string")
	local text = `{name}:{kind}`
	if arg.default ~= nil then
		text ..= `={arg.default}`
	end

	return if arg.required == false or arg.default ~= nil then `[{text}]` else `<{text}>`
end

local function usage(command: Types.Command): string
	local parts = { command.name }
	for _, arg in command.args do
		table.insert(parts, formatArg(arg))
	end

	return table.concat(parts, " ")
end

return table.freeze({
	name = "cmds",
	rank = 0,
	aliases = { "commands", "help" },
	description = "Lists every command registered in the game.",
	run = function()
		local rows = {}
		for _, command in imports.Kommand.list() do
			table.insert(rows, {
				Command = command.name,
				Rank = tostring(command.rank),
				Usage = usage(command),
				Description = command.description,
			})
		end

		return {
			ok = true,
			kind = "table",
			title = "Commands",
			message = `{#rows} registered`,
			width = "wide",
			columns = { "Command", "Rank", "Usage", "Description" },
			rows = rows,
		}
	end,
}) :: Definition
