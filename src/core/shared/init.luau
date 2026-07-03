--[[
	@name shared
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	Arguments = require("@self/kommand/arguments"),
	Dispatch = require("@self/dispatch"),
	Kommand = require("@self/kommand"),
	Ranks = require("@self/dispatch/ranks"),
	Table = require("@self/kommand/table"),
}

local shared = {
	arguments = imports.Arguments,
	dispatch = imports.Dispatch,
	kommand = imports.Kommand,
	ranks = imports.Ranks,
	table = imports.Table,
}

return table.freeze(shared)
