--!strict

--[[
	@name slide
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time July 3, 2026
]]

--// imports
local Imports = {
	Tween = require("./tween"),
}

--// public api
local Slide = {}

function Slide.history(session: any, channel: number): ()
    local contentName = channel == 2 and "secondHistoryContent" or "historyContent"
    
	local content = session.refs and session.refs[contentName]
	if typeof(content) ~= "Instance" or not content:IsA("GuiObject") then
		return
	end

    local time = math.min(session.config.motion.itemSlideSmoothTime or 0.18, 0.22)
    local offset = session.config.motion.textSlideOffset or 10
    
    content.Position = UDim2.fromOffset(2, offset)
    
	Imports.Tween.to(content, {
		Position = UDim2.fromOffset(2, 0),
	}, time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end

return table.freeze(Slide)
