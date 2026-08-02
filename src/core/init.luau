--!strict

--[[
	@name core
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Imports = {
	Shared = require("@self/shared"),
	UI = require("@self/ui"),
}

--// public api
local Core = {
	shared = Imports.Shared,
	ui = Imports.UI,
}

return table.freeze(Core)
