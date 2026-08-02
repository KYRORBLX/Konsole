--!strict

--[[
	@name ban
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time July 3, 2026
]]

local Imports = {
	BanServer = require("./banServer"),
}

local Types = require("../../types/sharedTypes")

return function(context: Types.Context, userId: number)
	local removed = Imports.BanServer.unban(userId)
	return context.reply(removed and `unbanned {userId}` or `{userId} was not banned`)
end
