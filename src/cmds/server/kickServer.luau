--[[
	@name kickServer
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 23, 2026
]]

--!strict

local Types = require("../../types/sharedTypes")

return function(context: Types.Context, target: Player?, reason: string?)
	if not target then
		return context.err("no-target", "no player to kick")
	end

	target:Kick(tostring(reason or "Kicked by a moderator."))
	return context.reply(`kicked {target.Name}`)
end
