--!strict

--[[
	@name formatter
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local imports = {
    Text = require("../misc/text"),
}

local Types = require("../../../../types/uiTypes")

--// types
export type RenderResult = Types.RenderResult

type Colors = { [string]: string }
type Rows = { { [string]: any } }

--// locals
local function visibleLength(value: any): number
    return #tostring(value or "")
end

local function cell(row: { [string]: any }?, column: string): string
    if type(row) ~= "table" then
        return ""
    end

    return tostring(row[column] or row[string.lower(column)] or "")
end

local function padRight(value: any, width: number): string
    local text = tostring(value or "")
    local missing = math.max(0, width - visibleLength(text))

    if missing == 0 then
        return text
    end

    return text .. string.rep(" ", missing)
end

local function columnWidths(columns: { string }, rows: Rows?): { number }
    local widths: { number } = {}

    for index, column in columns do
        widths[index] = visibleLength(column)
    end

    for _, row in (rows or {}) :: Rows do
        for index, column in columns do
            widths[index] = math.max(widths[index] or 0, visibleLength(cell(row, column)))
        end
    end

    return widths
end

local function headerLine(columns: { string }, widths: { number }): string?
    local cells: { string } = {}

    for index, column in columns do
        table.insert(cells, padRight(column, widths[index]))
    end

    if #cells == 0 then
        return nil
    end

    return table.concat(cells, "  |  ")
end

local function rowLine(row: { [string]: any }, columns: { string }, widths: { number }): string
    local cells: { string } = {}

    for index, column in columns do
        table.insert(cells, padRight(cell(row, column), widths[index]))
    end

    return table.concat(cells, "  |  ")
end

local function tableLines(columns: { string }, rows: Rows?): { string }
    local widths = columnWidths(columns, rows)
    local lines: { string } = {}

    local header = headerLine(columns, widths)

    if header then
        table.insert(lines, header)
    end

    for _, row in (rows or {}) :: Rows do
        table.insert(lines, rowLine(row, columns, widths))
    end

    return lines
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

    local color = result and result.ok
        and (palette.successRich or "#89FF7E")
        or (palette.errorRich or "#FF7E7E")

    local lines = Formatter.lines(result)

    for index, line in lines do
        lines[index] = imports.Text.richEscape(line)
    end

    return string.format(
        '<font color="%s">%s</font>  %s',

        color,
        prefix,

        table.concat(lines, "\n")
    )
end

function Formatter.plain(result: RenderResult?): string
    return table.concat(Formatter.lines(result), "\n")
end

return table.freeze(Formatter)
