--!strict

--[[
	@name tween
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
	TweenService = game:GetService("TweenService"),

	Ease = require("./ease"),
}

--// public api
local Tween = {}

function Tween.to(
	instance: Instance?,
	props: { [string]: any },
	duration: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local info =
		TweenInfo.new(tonumber(duration) or 0.18, style or imports.Ease.style, direction or imports.Ease.direction)
	local tween = imports.TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function Tween.fade(instance: Instance?, props: { [string]: any }, duration: number?): Tween?
	return Tween.to(instance, props, duration, imports.Ease.soft)
end

return Tween
