--[[
	@name ease
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--!strict

export type EaseGroup = {
	style: Enum.EasingStyle,
	soft: Enum.EasingStyle,
	direction: Enum.EasingDirection,
}

local Ease: EaseGroup = {
	style = Enum.EasingStyle.Quint,
	soft = Enum.EasingStyle.Quad,
	direction = Enum.EasingDirection.Out,
}

return Ease
