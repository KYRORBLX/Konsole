--!strict

--[[
	@name ui
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Imports = {
	Render = require("@self/render"),
}

--// public api
local UI = {
	render = Imports.Render,
}

return table.freeze(UI)
