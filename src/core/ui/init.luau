--!strict

--[[
	@name ui
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local imports = {
	Render = require("@self/render"),
}

--// public api
local ui = {
	render = imports.Render,
}

return table.freeze(ui)
