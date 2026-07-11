--!strict

--[[
	@name ui
	@author driftingAurora, dullflowerr
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
