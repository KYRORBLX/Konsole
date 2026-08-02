--!strict

--[[
	@name ease
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

local Types = require("../../../../types/uiTypes")

--// types
export type EaseGroup = Types.EaseGroup

--// public api
local Ease: EaseGroup = {
	direction = Enum.EasingDirection.Out,
	style = Enum.EasingStyle.Quint,
	soft = Enum.EasingStyle.Quad,
}

return Ease
