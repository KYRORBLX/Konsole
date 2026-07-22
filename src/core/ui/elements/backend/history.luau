--!strict

--[[
	@name history
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local imports = {
    TextService = game:GetService("TextService"),

    Formatter = require("./formatter"),
    Text = require("../misc/text"),
}

local ConfigModule = require("../../../../config")
local Types = require("../../../../types/uiTypes")

--// types
export type HistoryItemKind = Types.HistoryItemKind
export type RenderResult = Types.RenderResult
export type HistoryItem = Types.HistoryItem

export type RenderConfig = ConfigModule.MergedConfig
export type DisplayLine = Types.DisplayLine

--// locals
local prefixes: { [HistoryItemKind]: string } = {
    warn = "!  ",
    cmd = ">  ",
    err = "x  ",
    ok = "✓  ",
}

local function colorFor(kind: HistoryItemKind, config: RenderConfig): string
    local colors = config.color

    if kind == "cmd" then
        return colors.suggMatch
    end

    if kind == "ok" then
        return colors.successRich
    end

    if kind == "warn" then
        return colors.warnRich or colors.successRich
    end

    return colors.errorRich or "#FF7E7E"
end

local function measureLine(text: string, config: RenderConfig): number
    local size = imports.TextService:GetTextSize(
        text,
        
        config.layout.textSize,
        config.font.mono,
        
        Vector2.new(10000, 10000)
    )

    return size.X
end

local function renderLine(text: string, color: string): string
    return string.format(
        '<font color="%s">%s</font>',
        
        color,
        
        imports.Text.richEscape(text)
    )
end

local function createDisplayLine(text: string, color: string, config: RenderConfig): DisplayLine
    return {
        chars = #text,
        plain = text,
        
        width = measureLine(text, config),
        rich = renderLine(text, color),
    }
end

--// public api
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

    if text ~= "" then
        return text
    end

    if result and result.ok then
        return "Command completed."
    end

    return "Command failed."
end

function History.displayLines(items: { HistoryItem }, config: RenderConfig): { DisplayLine }
    local output: { DisplayLine } = {}

    for _, item in items do
        
        local color = colorFor(item.kind, config)
        local prefix = prefixes[item.kind] or prefixes.err

        for index, line in imports.Text.linesOf(item.text) do
            local text = tostring(line)

            if index == 1 then
                text = prefix .. text
            end

            table.insert(output, createDisplayLine(text, color, config))
        end
    end

    return output
end

function History.chunkText(lines: { DisplayLine }, first: number, last: number): string
    local output: { string } = {}

    for index = first, last do
        local line = lines[index]

        if line then
            table.insert(output, line.rich)
        end
    end

    return table.concat(output, "\n")
end

function History.append(items: { HistoryItem }, item: HistoryItem): ()
    table.insert(items, item)
end

return table.freeze(History)
