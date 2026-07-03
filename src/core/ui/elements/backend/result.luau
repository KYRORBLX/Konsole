--[[
	@name result
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local Types = require("../types")

export type RenderResult = Types.RenderResult
export type ResultOptions = Types.ResultOptions

local Result = {}

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

function Result.ok(message: any?, options: ResultOptions?): RenderResult
	local opts: ResultOptions = type(options) == "table" and options or {}
	return {
		ok = true,
		kind = opts.kind or "text",
		title = opts.title or "OK",
		message = tostring(message or opts.message or "Command completed."),
		width = opts.width or "normal",
		columns = type(opts.columns) == "table" and opts.columns or nil,
		rows = cloneRows(opts.rows),
	}
end

function Result.err(code: any?, message: any?, options: ResultOptions?): RenderResult
	local opts: ResultOptions = type(options) == "table" and options or {}
	return {
		ok = false,
		kind = "error",
		code = tostring(code or "error"),
		title = opts.title or "Command failed",
		message = tostring(message or "Unable to execute command."),
		width = opts.width or "normal",
		columns = type(opts.columns) == "table" and opts.columns or nil,
		rows = cloneRows(opts.rows),
		hints = type(opts.hints) == "table" and opts.hints or nil,
	}
end

function Result.table(title: any?, columns: { string }?, rows: { { [string]: any } }?, options: ResultOptions?): RenderResult
	local opts: ResultOptions = type(options) == "table" and options or {}
	return {
		ok = true,
		kind = "table",
		title = tostring(title or "Result"),
		message = tostring(opts.message or ""),
		width = opts.width or "wide",
		columns = type(columns) == "table" and columns or {},
		rows = cloneRows(rows),
	}
end

function Result.status(title: any?, rows: { { [string]: any } }?, options: ResultOptions?): RenderResult
	local opts: ResultOptions = type(options) == "table" and options or {}
	return Result.table(title, { "Field", "Value" }, rows, {
		width = opts.width or "normal",
		message = opts.message,
	})
end

function Result.from(value: any): RenderResult
	if type(value) == "table" and type(value.kind) == "string" then
		return value :: RenderResult
	end

	if type(value) == "table" then
		if value.ok == true then
			local message = tostring(value.message or value.data or "")
			if message == "" then
				message = "Command completed."
			end
			return Result.ok(message, { title = value.title })
		end

		return Result.err(value.code or "command-failed", value.message or value.err or "Command failed.", {
			title = value.title,
		})
	end

	if value == nil then
		return Result.ok("Command completed.")
	end

	return Result.ok(tostring(value))
end

return table.freeze(Result)
