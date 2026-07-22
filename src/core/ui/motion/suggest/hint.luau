--[[
	@name hint
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local imports = {
	Math = require("../math"),
}

local Tween = imports.Math.tween

--// locals
local function rowPosition(offset)
	return UDim2.new(0, offset, 0.5, 0)
end

--// public api
local Hint = {}

function Hint.snap(_session, row, offset)
	if typeof(row) == "Instance" then
		row.Position = rowPosition(offset)
	end
end

function Hint.move(session, row, offset)
	Tween.to(row, { Position = rowPosition(offset) }, session.config.motion.hintSlideTime)
end

function Hint.text(session, label, transparency)
	Tween.to(label, { TextTransparency = transparency }, session.config.motion.hintFadeTime)
end

function Hint.tint(session, label, color)
	Tween.to(label, { TextColor3 = color }, session.config.motion.hintFadeTime)
end

return Hint
