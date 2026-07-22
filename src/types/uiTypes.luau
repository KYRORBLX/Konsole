--!strict

--[[
	@name uiTypes
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 30, 2026
]]

--// types
export type ResultKind = "text" | "table" | "error" | "warn"

export type RenderResult = {
	rows: { { [string]: any } },
	code: string?,
	ok: boolean,

	columns: { string }?,
	hints: { string }?,
	kind: ResultKind,
	message: string,
	title: string,
	width: string,
}

export type ResultOptions = {
	columns: { string }?,
	message: string?,

	title: string?,
	width: string?,

	hints: { string }?,
	kind: ResultKind?,

	rows: { { [string]: any } }?,
}

export type HistoryItemKind = "cmd" | "ok" | "warn" | "err"

export type HistoryItem = {
	kind: HistoryItemKind,
	wide: boolean?,
	text: string,
}

export type DisplayLine = {
	plain: string,
	chars: number,
	width: number,

	rich: string,
}

return {}
