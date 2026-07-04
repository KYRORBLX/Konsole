--[[
	@name shared
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	Arguments = require("@self/kommand/arguments"),
	Ranks = require("@self/dispatch/ranks"),
	Table = require("@self/kommand/table"),
	Dispatch = require("@self/dispatch"),
	Kommand = require("@self/kommand"),
	Chat = require("@self/chat"),
}

local shared = {
	arguments = imports.Arguments,
	chat = imports.Chat,
	dispatch = imports.Dispatch,
	kommand = imports.Kommand,
	ranks = imports.Ranks,
	table = imports.Table,
}

return table.freeze(shared)
