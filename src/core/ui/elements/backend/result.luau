--!strict

--[[
	@name result
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Types = require("../../../../types/uiTypes")

--// types
export type ResultOptions = Types.ResultOptions
export type RenderResult = Types.RenderResult

--// locals
local function cloneRows(rows: { { [string]: any } }?): { { [string]: any } }
    local out: { { [string]: any } } = {}

    if type(rows) ~= "table" then
        return out
    end

    for _, row in rows do
        if type(row) == "table" then
            table.insert(out, table.clone(row))
        end
    end

    return out
end

--// public api
local Result = {}

function Result.ok(message: any?, options: ResultOptions?): RenderResult
    local opts: ResultOptions = type(options) == "table" and options or {}

    return {
        message = tostring(message or opts.message or "Command completed."),
        columns = type(opts.columns) == "table" and opts.columns or nil,
        title = opts.title or "OK",

        rows = cloneRows(opts.rows),
        
        width = opts.width or "normal",
        kind = opts.kind or "text",
        
        ok = true,
    }
end

function Result.err(code: any?, message: any?, options: ResultOptions?): RenderResult
    local opts: ResultOptions = type(options) == "table" and options or {}

    return {
        columns = type(opts.columns) == "table" and opts.columns or nil,
        hints = type(opts.hints) == "table" and opts.hints or nil,

		message = tostring(message or "Unable to execute command."),
        title = opts.title or "Command failed",
        width = opts.width or "normal",

        code = tostring(code or "error"),
        kind = "error",
        
        rows = cloneRows(opts.rows),

        ok = false,
    }
end

function Result.table(
    title: any?,
    columns: { string }?,
    rows: { { [string]: any } }?,
    options: ResultOptions?
): RenderResult
    
    local opts: ResultOptions = type(options) == "table" and options or {}

    return {
        columns = type(columns) == "table" and columns or {},
        message = tostring(opts.message or ""),
        
        title = tostring(title or "Result"),
        width = opts.width or "wide",
        kind = "table",
        
        rows = cloneRows(rows),

        ok = true,
    }
end

function Result.status(title: any?, rows: { { [string]: any } }?, options: ResultOptions?): RenderResult
    local opts: ResultOptions = type(options) == "table" and options or {}

    return Result.table(title, { "Field", "Value" }, rows, {
        message = opts.message,
        width = opts.width or "normal",
    })
end

function Result.from(value: any): RenderResult
    if type(value) == "table" then
        local data = value :: { [string]: any }

        if type(data.kind) == "string" then
            return data :: RenderResult
        end

        local title = if type(data.title) == "string" then data.title else nil

        if data.ok == true then
            local message = tostring(data.message or data.data or "")

            if message == "" then
                message = "Command completed."
            end

            return Result.ok(message, { title = title })
        end

        return Result.err(data.code or "command-failed", data.message or data.err or "Command failed.", {
            title = title,
        })
    end

    if value == nil then
        return Result.ok("Command completed.")
    end

    return Result.ok(tostring(value))
end

return table.freeze(Result)
