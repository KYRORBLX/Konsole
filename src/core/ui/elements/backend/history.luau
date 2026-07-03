--[[
	@name history
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	TextService = game:GetService("TextService"),

	Formatter = require("./formatter"),
	Text = require("../misc/text"),
}

local Types = require("../types")
local ConfigModule = require("../../../../config")

export type RenderResult = Types.RenderResult
export type HistoryItem = Types.HistoryItem
export type HistoryItemKind = Types.HistoryItemKind
export type DisplayLine = Types.DisplayLine
export type RenderConfig = ConfigModule.MergedConfig

local History = {}

function History.resultKind(result: RenderResult?): HistoryItemKind
	if type(result) ~= "table" then
		return "err"
	end
	if result.ok then
		return "ok"
	end
	if result.kind == "warn" then
		return "warn"
	end

	return "err"
end

function History.resultText(result: RenderResult?): string
	local text = imports.Formatter.plain(result)
	if text == "" then
		return result and result.ok and "Command completed." or "Command failed."
	end

	return text
end

local function lineColor(item: HistoryItem, config: RenderConfig): string
	local colors = config.color
	if item.kind == "cmd" then
		return colors.suggMatch
	elseif item.kind == "ok" then
		return colors.successRich
	elseif item.kind == "warn" then
		return colors.warnRich or colors.successRich
	end

	return colors.errorRich or "#FF7E7E"
end

local function linePrefix(item: HistoryItem): string
	if item.kind == "cmd" then
		return ">  "
	elseif item.kind == "ok" then
		return "✓  "
	elseif item.kind == "warn" then
		return "!  "
	end

	return "x  "
end

function History.displayLines(items: { HistoryItem }, config: RenderConfig): { DisplayLine }
	local lines: { DisplayLine } = {}
	local layout = config.layout
	for _, item in items do
		local color = lineColor(item, config)
		local prefix = linePrefix(item)
		for index, line in imports.Text.linesOf(item.text) do
			local plain = (index == 1 and prefix or "") .. tostring(line)
			local measured =
				imports.TextService:GetTextSize(plain, layout.textSize, config.font.mono, Vector2.new(10000, 10000))
			table.insert(lines, {
				plain = plain,
				chars = #plain,
				width = measured.X,
				rich = string.format('<font color="%s">%s</font>', color, imports.Text.richEscape(plain)),
			})
		end
	end

	return lines
end

function History.chunkText(lines: { DisplayLine }, first: number, last: number): string
	local rendered: { string } = {}
	for index = first, last do
		if lines[index] then
			table.insert(rendered, lines[index].rich)
		end
	end

	return table.concat(rendered, "\n")
end

function History.append(items: { HistoryItem }, item: HistoryItem): ()
	table.insert(items, item)
end

return table.freeze(History)
