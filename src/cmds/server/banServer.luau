--[[
	@name ban
	@author driftingAurora, dullflowerr
	@time July 3, 2026
]]

--!strict

local imports = {
	Players = game:GetService("Players"),
}

local Types = require("../../core/shared/kommand/types")

local bans: { [number]: string } = {}
local Server = {}

function Server.ban(player: Player, reason: string): ()
	bans[player.UserId] = reason
	player:Kick(reason)
end

function Server.unban(userId: number): boolean
	local hadBan = bans[userId] ~= nil
	bans[userId] = nil
	return hadBan
end

imports.Players.PlayerAdded:Connect(function(player)
	local reason = bans[player.UserId]
	if reason then
		player:Kick(reason)
	end
end)

function Server.run(context: Types.Context, targets: { Player }?, reason: string?)
	if not targets or #targets == 0 then
		return context.err("no-target", "no player to ban")
	end

	local message = tostring(reason or "Banned from this server.")
	local names = {}
	for _, target in targets do
		table.insert(names, target.Name)
		Server.ban(target, message)
	end

	return context.reply(`banned {table.concat(names, ", ")}`)
end

return Server
