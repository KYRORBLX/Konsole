--!strict

--[[
	@name placement
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time July 22, 2026
]]

export type Preset =
	"br"
	| "tr"
	| "tl"
	| "bl"
	| "bc"
	| "tc"
	| "bottom right"
	| "top right"
	| "top left"
	| "bottom left"
	| "bottom center"
	| "top center"

local bottomCenter = Vector2.new(0.5, 1)

local presetAnchors: { [string]: Vector2 } = {
	br = Vector2.new(1, 1),
	bottomright = Vector2.new(1, 1),

	tr = Vector2.new(1, 0),
	topright = Vector2.new(1, 0),

	tl = Vector2.new(0, 0),
	topleft = Vector2.new(0, 0),

	bl = Vector2.new(0, 1),
	bottomleft = Vector2.new(0, 1),

	bc = bottomCenter,
	bottomcenter = bottomCenter,

	tc = Vector2.new(0.5, 0),
	topcenter = Vector2.new(0.5, 0),
}

local Placement = {}

local function normalize(value: string): string
	return string.gsub(string.lower(value), "[%s_%-]", "")
end

local function edgeOffset(anchor: number, inset: number): number
	if anchor == 0 then
		return inset
	elseif anchor == 1 then
		return -inset
	end

	return 0
end

local function customAnchor(position: UDim2): Vector2
	local x = if position.X.Scale <= 0 then 0 elseif position.X.Scale >= 1 then 1 else 0.5
	local y = if position.Y.Scale < 0.5 then 0 else 1

	return Vector2.new(x, y)
end

function Placement.resolve(value: any, inset: number): (UDim2, Vector2)
	if typeof(value) == "UDim2" then
		local position = value :: UDim2
		return position, customAnchor(position)
	end

	local key = if type(value) == "string" then normalize(value) else "bc"
	local anchor = presetAnchors[key] or bottomCenter

	return UDim2.new(
		anchor.X,
		edgeOffset(anchor.X, inset),
		anchor.Y,
		edgeOffset(anchor.Y, inset)
	), anchor
end

function Placement.isTop(root: GuiObject): boolean
	return root.AnchorPoint.Y < 0.5
end

function Placement.shift(position: UDim2, offset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + offset)
end

function Placement.slide(position: UDim2, root: GuiObject, offset: number): UDim2
	return Placement.shift(position, if Placement.isTop(root) then -offset else offset)
end

function Placement.attachedSecond(position: UDim2, root: GuiObject, mainHeight: number, gap: number): UDim2
	return Placement.shift(position, (mainHeight + gap) * (1 - root.AnchorPoint.Y))
end

function Placement.withStack(position: UDim2, root: GuiObject, stackHeight: number): UDim2
	return Placement.shift(position, stackHeight * root.AnchorPoint.Y)
end

function Placement.withoutStack(position: UDim2, root: GuiObject, stackHeight: number): UDim2
	return Placement.shift(position, -stackHeight * root.AnchorPoint.Y)
end

function Placement.suggestion(root: GuiObject, offset: number): (UDim2, Vector2)
	local below = Placement.isTop(root)
	local direction = if below then 1 else -1

	return UDim2.new(0.5, 0, if below then 1 else 0, direction * offset),
		Vector2.new(0.5, if below then 0 else 1)
end

return table.freeze(Placement)
