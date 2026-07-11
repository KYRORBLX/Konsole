--[[
	@name tpServer
	@author driftingAurora, dullflowerr
	@time June 23, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

return function(context: Types.Context, target: Player?)
	local from = context.entity and context.entity.Character
	local to = target and target.Character
	if not (from and to) then
		return context.err("no-character", "both players must be spawned")
	end

	(from :: Model):PivotTo((to :: Model):GetPivot() * CFrame.new(0, 0, 3))
	return context.reply(`teleported to {(target :: Player).Name}`)
end
