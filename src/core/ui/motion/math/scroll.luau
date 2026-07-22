--!strict

--[[
	@name scroll
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time July 11, 2026
]]

--// imports
local imports = {
	TweenService = game:GetService("TweenService"),
}

--// types
type State = {
	target: number,
	tween: Tween?,
}

--// locals
local states: { [ScrollingFrame]: State } = {}

local duration = 0.36

--// public api
local Scroll = {}

function Scroll.animating(frame: ScrollingFrame): boolean
	local state = states[frame]

	return state ~= nil and state.tween ~= nil
end

function Scroll.wheel(frame: ScrollingFrame, delta: number, maximum: number): (Tween?, number)
	maximum = math.max(0, maximum)

	local state = states[frame]
	local current = state and state.target or frame.CanvasPosition.Y
	local target = math.clamp(current + delta, 0, maximum)

	if math.abs(target - current) < 0.5 then
		return nil, target
	end

	if not state then
		local created: State = {
			target = target,
			tween = nil,
		}

		states[frame] = created
		state = created
	end

	state.target = target

	if state.tween then
		state.tween:Cancel()
	end

	local tween = imports.TweenService:Create(
		frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			CanvasPosition = Vector2.new(0, target),
		}
	)

	state.tween = tween

	tween.Completed:Connect(function()
		if states[frame] == state and state.tween == tween then
			state.tween = nil
		end
	end)

	tween:Play()

	return tween, target
end

return table.freeze(Scroll)
