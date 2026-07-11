--!strict

--[[
	@name ease
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// types
export type EaseGroup = {
	direction: Enum.EasingDirection,
	style: Enum.EasingStyle,
	soft: Enum.EasingStyle,
}

--// public api
local Ease: EaseGroup = {
	direction = Enum.EasingDirection.Out,
	style = Enum.EasingStyle.Quint,
	soft = Enum.EasingStyle.Quad,
}

return Ease
