--!strict

--[[
	@name server
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

local Types = require("../types/sharedTypes")

export type Run = Types.Run

local Imports = {
	BringServer = require("@self/bringServer"),
	BanServer = require("@self/banServer").run,
	KickServer = require("@self/kickServer"),

	UnbanServer = require("@self/unbanServer"),
	KillServer = require("@self/killServer"),
	TPServer = require("@self/tpServer"),
}

local Server: { [string]: Run } = {
	bringServer = Imports.BringServer,
	kickServer = Imports.KickServer,
	banServer = Imports.BanServer,

	unbanServer = Imports.UnbanServer,
	killServer = Imports.KillServer,
	tpServer = Imports.TPServer,
}

return table.freeze(Server)
