--!strict

--[[
	@name formatter
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--// imports
local imports = {
	Text = require("../misc/text"),
}

local Types = require("../types")

--// types
export type RenderResult = Types.RenderResult

type Colors = { [string]: string }

--// locals
local function cell(row: { [string]: any }?, column: string): string
	if type(row) ~= "table" then
		return ""
	end

	return tostring(row[column] or row[string.lower(column)] or "")
end

local function visibleLength(value: any): number
	return #tostring(value or "")
end

local function padRight(value: any, width: number): string
	local text = tostring(value or "")
	local missing = math.max(0, width - visibleLength(text))
	if missing == 0 then
		return text
	end

	return text .. string.rep(" ", missing)
end

local function tableLines(columns: { string }, rows: { { [string]: any } }?): { string }
	local widths: { number } = {}
	local out: { string } = {}

	for index, column in columns do
		widths[index] = visibleLength(column)
	end
	for _, row in rows or {} do
		for index, column in columns do
			widths[index] = math.max(widths[index] or 0, visibleLength(cell(row, column)))
		end
	end

	local header: { string } = {}
	for index, column in columns do
		table.insert(header, padRight(column, widths[index]))
	end
	if #header > 0 then
		table.insert(out, table.concat(header, "  |  "))
	end

	for _, row in rows or {} do
		local parts: { string } = {}
		for index, column in columns do
			table.insert(parts, padRight(cell(row, column), widths[index]))
		end
		table.insert(out, table.concat(parts, "  |  "))
	end

	return out
end

--// public api
local Formatter = {}

function Formatter.lines(result: RenderResult?): { string }
	local lines: { string } = {}
	if type(result) ~= "table" then
		return { "Invalid command result." }
	end

	if result.title and result.title ~= "" then
		table.insert(lines, tostring(result.title))
	end
	if result.message and result.message ~= "" then
		table.insert(lines, tostring(result.message))
	end

	if type(result.hints) == "table" then
		for _, hint in result.hints do
			table.insert(lines, tostring(hint))
		end
	end

	if (result.kind == "table" or result.kind == "error") and type(result.columns) == "table" then
		for _, line in tableLines(result.columns :: { string }, result.rows) do
			table.insert(lines, line)
		end
	end

	if #lines == 0 then
		table.insert(lines, result.ok and "Command completed." or "Command failed.")
	end

	return lines
end

function Formatter.rich(result: RenderResult?, colors: Colors?): string
	local palette: Colors = colors or {}
	local prefix = result and result.ok and "✓" or "x"
	local color = result and result.ok and (palette.successRich or "#89FF7E") or (palette.errorRich or "#FF7E7E")
	local lines = Formatter.lines(result)
	for index, line in lines do
		lines[index] = imports.Text.richEscape(line)
	end

	return string.format('<font color="%s">%s</font>  %s', color, prefix, table.concat(lines, "\n"))
end

function Formatter.plain(result: RenderResult?): string
	return table.concat(Formatter.lines(result), "\n")
end

return table.freeze(Formatter)
