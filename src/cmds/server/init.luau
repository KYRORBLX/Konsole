--[[
	@name server
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--!strict

local Types = require("../types/sharedTypes")

export type Run = Types.Run

local server: { [string]: Run } = {
	bringServer = require("@self/bringServer"),
	banServer = require("@self/banServer").run,
	kickServer = require("@self/kickServer"),
	
	killServer = require("@self/killServer"),
	unbanServer = require("@self/unbanServer"),
	tpServer = require("@self/tpServer"),
	
}

return table.freeze(server)
