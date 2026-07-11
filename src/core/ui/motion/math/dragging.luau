--!strict

--[[
	@name dragging
	@author driftingAurora, dullflowerr
	@time July 10, 2026
]]

--// imports
local imports = {
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService"),
}

--// types
type TargetChanged = (UDim2) -> ()
export type Binding = {
	setEnabled: (boolean) -> (),
	setPosition: (UDim2) -> (),
}

--// locals
local stopDistance = 0.25
local smoothTime = 0.08

local function createDetector(handle: GuiObject): UIDragDetector
	local detector = Instance.new("UIDragDetector")
	detector.Name = "Dragging"
	detector.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane
	detector.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomScale
	detector.Enabled = false
	detector.Parent = handle
	return detector
end

local function pointFrom(position: UDim2, boundsSize: Vector2): Vector2
	return Vector2.new(
		boundsSize.X * position.X.Scale + position.X.Offset,
		boundsSize.Y * position.Y.Scale + position.Y.Offset
	)
end

local function clampAxis(value: number, minimum: number, maximum: number): number
	if maximum < minimum then
		return (minimum + maximum) / 2
	end

	return math.clamp(value, minimum, maximum)
end

local function clampPoint(point: Vector2, root: GuiObject, boundsSize: Vector2): Vector2
	local rootSize = root.AbsoluteSize
	local anchor = root.AnchorPoint

	return Vector2.new(
		clampAxis(point.X, rootSize.X * anchor.X, boundsSize.X - rootSize.X * (1 - anchor.X)),
		clampAxis(point.Y, rootSize.Y * anchor.Y, boundsSize.Y - rootSize.Y * (1 - anchor.Y))
	)
end

local function positionFrom(point: Vector2, boundsSize: Vector2): UDim2
	return UDim2.fromScale(point.X / boundsSize.X, point.Y / boundsSize.Y)
end

--// public api
local Dragging = {}

function Dragging.attach(root: GuiObject, handles: { GuiObject }, targetChanged: TargetChanged?): Binding
	local bounds = root.Parent
	assert(bounds and bounds:IsA("GuiBase2d"), "drag root needs a 2d parent")

	local connections: { RBXScriptConnection } = {}
	local detectors: { UIDragDetector } = {}
	local target = root.Position
	local velocity = Vector2.zero
	local destroyed = false
	local moving = false

	local function track(connection: RBXScriptConnection)
		table.insert(connections, connection)
	end

	local function setTarget(position: UDim2)
		target = position
		moving = true
		if targetChanged then
			targetChanged(position)
		end
	end

	local function setPosition(position: UDim2)
		local boundsSize = bounds.AbsoluteSize
		if boundsSize.X > 0 and boundsSize.Y > 0 then
			local point = clampPoint(pointFrom(position, boundsSize), root, boundsSize)
			position = positionFrom(point, boundsSize)
		end

		target = position
		root.Position = position
		velocity = Vector2.zero
		moving = false
		if targetChanged then
			targetChanged(position)
		end
	end

	local function setEnabled(value: boolean)
		local enabled = value and not destroyed
		for _, detector in detectors do
			detector.Enabled = enabled
		end
		moving = false
		target = root.Position
		velocity = Vector2.zero
	end

	for _, handle in handles do
		local detector = createDetector(handle)
		local inputOrigin = Vector2.zero
		local pointOrigin = Vector2.zero

		table.insert(detectors, detector)
		track(detector.DragStart:Connect(function(inputPosition)
			local boundsSize = bounds.AbsoluteSize
			if boundsSize.X <= 0 or boundsSize.Y <= 0 then
				return
			end

			inputOrigin = inputPosition
			pointOrigin = pointFrom(root.Position, boundsSize)
			target = root.Position
			velocity = Vector2.zero
			moving = false
			if targetChanged then
				targetChanged(target)
			end
		end))
		track(detector.DragContinue:Connect(function(inputPosition)
			local boundsSize = bounds.AbsoluteSize
			if boundsSize.X <= 0 or boundsSize.Y <= 0 then
				return
			end

			local point = clampPoint(pointOrigin + inputPosition - inputOrigin, root, boundsSize)
			setTarget(positionFrom(point, boundsSize))
		end))
	end
	track(imports.RunService.RenderStepped:Connect(function(deltaTime)
		if not moving then
			return
		end

		local boundsSize = bounds.AbsoluteSize
		if boundsSize.X <= 0 or boundsSize.Y <= 0 then
			return
		end

		local currentPoint = pointFrom(root.Position, boundsSize)
		local targetPoint = pointFrom(target, boundsSize)
		local nextPoint, nextVelocity =
			imports.TweenService:SmoothDamp(currentPoint, targetPoint, velocity, smoothTime, math.huge, deltaTime)

		nextPoint = nextPoint :: Vector2
		velocity = nextVelocity :: Vector2
		if (targetPoint - nextPoint).Magnitude <= stopDistance then
			nextPoint = targetPoint
			velocity = Vector2.zero
			moving = false
		end

		root.Position = positionFrom(nextPoint, boundsSize)
	end))

	track(root.Destroying:Connect(function()
		destroyed = true
		setEnabled(false)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end))

	return table.freeze({
		setEnabled = setEnabled,
		setPosition = setPosition,
	}) :: Binding
end

return table.freeze(Dragging)
