--[[
	@name server
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local Types = require("../core/shared/kommand/types")

export type Run = Types.Run

local server: { [string]: Run } = {
	banServer = require("@self/banServer").run,
	bringServer = require("@self/bringServer"),
	kickServer = require("@self/kickServer"),
	killServer = require("@self/killServer"),
	tpServer = require("@self/tpServer"),
	unbanServer = require("@self/unbanServer"),
}

return table.freeze(server)
