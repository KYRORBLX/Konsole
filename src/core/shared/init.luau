--!strict

--[[
	@name shared
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Imports = {
	Arguments = require("@self/kommand/arguments"),
	Ranks = require("@self/dispatch/ranks"),
	Table = require("@self/kommand/table"),

	Dispatch = require("@self/dispatch"),
	Kommand = require("@self/kommand"),
	Chat = require("@self/chat"),
}

--// public api
local Shared = {
	arguments = Imports.Arguments,
	dispatch = Imports.Dispatch,
	kommand = Imports.Kommand,

	ranks = Imports.Ranks,
	table = Imports.Table,
	chat = Imports.Chat,
}

return table.freeze(Shared)
