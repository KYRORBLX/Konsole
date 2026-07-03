--[[
	@name types
	@author driftingAurora, dullflowerr
	@time June 30, 2026
]]

--!strict

export type ResultKind = "text" | "table" | "error" | "warn"

export type RenderResult = {
	ok: boolean,
	kind: ResultKind,
	code: string?,
	title: string,
	message: string,
	width: string,
	columns: { string }?,
	rows: { { [string]: any } },
	hints: { string }?,
}

export type ResultOptions = {
	kind: ResultKind?,
	title: string?,
	message: string?,
	width: string?,
	columns: { string }?,
	rows: { { [string]: any } }?,
	hints: { string }?,
}

export type HistoryItemKind = "cmd" | "ok" | "warn" | "err"

export type HistoryItem = {
	kind: HistoryItemKind,
	text: string,
	wide: boolean?,
}

export type DisplayLine = {
	plain: string,
	chars: number,
	width: number,
	rich: string,
}

return {}
