--[[
	@name killServer
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local Types = require("../../core/shared/kommand/types")

return function(context: Types.Context, target: Player?)
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return context.err("no-humanoid", `{target and target.Name or "target"} has no humanoid`)
	end

	humanoid.Health = 0
	return context.reply(`killed {(target :: Player).Name}`)
end
