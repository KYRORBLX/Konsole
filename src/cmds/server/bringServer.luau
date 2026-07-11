--[[
	@name bringServer
	@author driftingAurora, dullflowerr
	@time June 23, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

return function(context: Types.Context, targets: { Player })
	local to = context.entity and context.entity.Character
	if not to then
		return context.err("no-character", "you must be spawned")
	end

	local pivot = (to :: Model):GetPivot()
	local brought = {}
	for _, player in targets do
		local character = player.Character
		if character then
			character:PivotTo(pivot * CFrame.new(0, 0, 3))
			table.insert(brought, player.Name)
		end
	end
	if #brought == 0 then
		return context.err("no-character", "no spawned players to bring")
	end

	return context.reply(`brought {table.concat(brought, ", ")}`)
end
