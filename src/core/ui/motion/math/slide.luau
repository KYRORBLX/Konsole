--!strict

--[[
	@name slide
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

--// imports
local imports = {
	Tween = require("./tween"),
}

--// public api
local Slide = {}

function Slide.history(session: any, channel: number): ()
    local contentName = channel == 2 and "secondHistoryContent" or "historyContent"
    
	local content = session.refs and session.refs[contentName]
	if typeof(content) ~= "Instance" then
		return
	end

    local time = math.min(session.config.motion.itemSlideSmoothTime or 0.18, 0.22)
    local offset = session.config.motion.textSlideOffset or 10
    
    content.Position = UDim2.fromOffset(2, offset)
    
	imports.Tween.to(content, {
		Position = UDim2.fromOffset(2, 0),
	}, time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end

return table.freeze(Slide)
