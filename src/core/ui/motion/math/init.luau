--!strict

--[[
	@name math
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local Imports = {
	Dragging = require("@self/dragging"),
	Scroll = require("@self/scroll"),
	Slide = require("@self/slide"),

	Tween = require("@self/tween"),
	Ease = require("@self/ease"),
}

local Math = {
	dragging = Imports.Dragging,
	scroll = Imports.Scroll,
	slide = Imports.Slide,

	tween = Imports.Tween,
	ease = Imports.Ease,
}

return Math
