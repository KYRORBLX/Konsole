--[[
	@name core
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local imports = {
	shared = require("@self/shared"),
	ui = require("@self/ui"),
}

local core = {
	shared = imports.shared,
	ui = imports.ui,
}

return table.freeze(core)
