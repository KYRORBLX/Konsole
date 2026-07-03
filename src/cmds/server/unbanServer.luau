--[[
	@name ban
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

--!strict

local imports = {
	BanServer = require("./banServer"),
}

local Types = require("../../core/shared/kommand/types")

return function(context: Types.Context, userId: number)
	local removed = imports.BanServer.unban(userId)
	return context.reply(removed and `unbanned {userId}` or `{userId} was not banned`)
end
