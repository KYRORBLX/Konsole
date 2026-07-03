--[[
	@name table
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--!strict

local Table = {}

function Table.callable(value: any): boolean
	if type(value) == "function" then
		return true
	end

	local meta = getmetatable(value :: any)
	return type(meta) == "table" and type((meta :: any).__call) == "function"
end

function Table.copyList<T>(items: { T }?): { T }
	local out: { T } = {}
	for _, item in items or {} :: { T } do
		local value = (if type(item) == "table" then table.clone(item :: any) else item) :: T
		table.insert(out, value)
	end

	return out
end

return table.freeze(Table)
