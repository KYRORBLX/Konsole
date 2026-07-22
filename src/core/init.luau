--!strict

--[[
	@name core
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local imports = {
	shared = require("@self/shared"),
	ui = require("@self/ui"),
}

--// public api
local core = {
	shared = imports.shared,
	ui = imports.ui,
}

return table.freeze(core)
