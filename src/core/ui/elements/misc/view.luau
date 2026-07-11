--[[
	@name view
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--// imports
local imports = {
	Text = require("./text"),
}

--// locals
local View = {}

local function createShadow(parent, name, config, zIndex, visible)
	return View.make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = View.readAsset(config.panel.shadowAssetId),
		ImageColor3 = config.color.shadowColor,
		ImageTransparency = config.transparency.shadow,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		SliceScale = 1,
		Visible = visible ~= false,
		ZIndex = zIndex,
	}, parent)
end

local function createInputRow(parent, config, refs, prefix, order, visibleTransparency, zIndex)
	local layout = config.layout
	local panel = config.panel
	local colors = config.color
	local inputHeight = panel.inputHeight or (panel.height - layout.paddingY * 2)
	local arrowTransparency = visibleTransparency >= 1 and 1 or (config.transparency.arrow or visibleTransparency)

	local row = View.make("Frame", {
		Name = prefix .. "InputRow",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, inputHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex,
	}, parent)
	View.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, layout.itemGap),
	}, row)

	local prompt = View.make("TextLabel", {
		Name = prefix .. "Prompt",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(layout.promptSize, inputHeight),
		BackgroundTransparency = 1,
		Font = config.font.mono,
		Text = ">",
		TextColor3 = colors.promptText,
		TextTransparency = visibleTransparency,
		TextSize = layout.promptSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = zIndex,
	}, row)

	local field = View.make("Frame", {
		Name = prefix .. "Field",
		LayoutOrder = 2,
		Size = UDim2.new(1, -(layout.promptSize + layout.itemGap), 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
	}, row)

	local placeholder = View.make("TextLabel", {
		Name = prefix .. "Placeholder",
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		Font = config.font.mono,
		Text = "type a command...",
		TextColor3 = colors.promptText,
		TextTransparency = visibleTransparency,
		TextSize = layout.textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = zIndex,
	}, field)

	local input = View.make("TextBox", {
		Name = prefix .. "InputBox",
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = config.font.mono,
		MultiLine = false,
		PlaceholderText = "",
		Selectable = true,
		Text = "",
		TextColor3 = colors.inputText,
		TextTransparency = visibleTransparency,
		TextSize = layout.textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = prefix == "",
		ZIndex = zIndex + 1,
	}, field)

	local hintRow = View.make("Frame", {
		Name = prefix .. "HintRow",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, layout.hintOffsetY or 0),
		Size = UDim2.new(0, 0, 0, panel.hintHeight or 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex + 2,
	}, field)
	View.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, layout.itemGap),
	}, hintRow)

	local arrow = View.make("ImageLabel", {
		Name = prefix .. "ArrowIcon",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 2, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = View.readAsset(panel.arrowAssetId),
		ImageColor3 = colors.promptText,
		ImageTransparency = arrowTransparency,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex + 20,
	}, field)

	refs[prefix .. "Prompt"] = prompt
	refs[prefix .. "Placeholder"] = placeholder
	refs[prefix .. "InputBox"] = input
	refs[prefix .. "HintRow"] = hintRow
	refs[prefix .. "ArrowIcon"] = arrow

	return row
end

--// public api
function View.readAsset(value)
	local text = type(value) == "string" and value or tostring(value or "")
	text = string.gsub(text, "^rbxassetid://", "")
	if string.match(text, "^%d+$") then
		return "rbxassetid://" .. text
	end

	return ""
end

function View.make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props or {} do
		instance[key] = value
	end

	instance.Parent = parent
	return instance
end

function View.corner(parent, radius)
	return View.make("UICorner", {
		CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius),
	}, parent)
end

function View.padding(parent, left, top, right, bottom)
	return View.make("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or left),
		PaddingBottom = UDim.new(0, bottom or top),
	}, parent)
end

function View.setShadowBounds(shadow, frame)
	if typeof(shadow) ~= "Instance" or typeof(frame) ~= "Instance" then
		return
	end

	local size = frame.Size
	local position = frame.Position
	local xOffset = frame.AnchorPoint.X == 0.5 and 0 or -3

	shadow.AnchorPoint = frame.AnchorPoint
	shadow.Position = UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset + 3)
	shadow.Size = UDim2.new(size.X.Scale, size.X.Offset + 6, size.Y.Scale, size.Y.Offset + 8)
end

function View.richSuggestion(text, matchText, config)
	local fullText = tostring(text or "")
	if type(matchText) ~= "string" or matchText == "" then
		return imports.Text.richEscape(fullText)
	end

	local startIndex, endIndex = string.find(string.lower(fullText), string.lower(matchText), 1, true)
	if not startIndex then
		return imports.Text.richEscape(fullText)
	end

	local colors = config.color
	return string.format(
		'<font color="%s">%s</font><font color="%s"><b>%s</b></font><font color="%s">%s</font>',
		colors.suggSub,
		imports.Text.richEscape(string.sub(fullText, 1, startIndex - 1)),
		colors.suggMatch,
		imports.Text.richEscape(string.sub(fullText, startIndex, endIndex)),
		colors.suggSub,
		imports.Text.richEscape(string.sub(fullText, endIndex + 1))
	)
end

function View.clearSuggestionConnections(session)
	for _, connection in session.suggestionConnections or {} do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	session.suggestionConnections = {}
end

function View.createTree(session, gui)
	local config = session.config
	local colors = config.color
	local panel = config.panel
	local layout = config.layout
	local transparency = config.transparency
	local refs = session.refs
	local pillHeight = panel.height
	local startWidth = pillHeight
	local startPosition = UDim2.new(0.5, 0, 1, -(pillHeight / 2))

	local root = View.make("Frame", {
		Name = "TerminalRoot",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = startPosition,
		Size = UDim2.fromOffset(startWidth, pillHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 30,
	}, gui)
	refs.root = root
	local secondRoot = View.make("Frame", {
		Name = "SecondTerminalRoot",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = startPosition,
		Size = UDim2.fromOffset(startWidth, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Visible = false,
		ZIndex = 30,
	}, gui)
	refs.secondRoot = secondRoot

	refs.pillShadow = createShadow(root, "PillShadow", config, 27, true)
	refs.suggShadow = createShadow(root, "AutofillShadow", config, 27, false)
	refs.stackShadow = createShadow(root, "StackShadow", config, 26, false)
	refs.secondShadow = createShadow(secondRoot, "SecondShadow", config, 27, false)

	local suggList = View.make("Frame", {
		Name = "SuggList",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -panel.suggestionGap),
		Size = UDim2.fromOffset(panel.width, 0),
		BackgroundColor3 = colors.suggPanel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 28,
	}, root)
	View.corner(suggList, panel.suggestionRadius or 10)
	View.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 0),
	}, suggList)
	View.padding(suggList, 0, 2, 0, 2)
	refs.suggList = suggList

	local pill = View.make("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(startWidth, pillHeight),
		BackgroundColor3 = colors.panel,
		BackgroundTransparency = transparency.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 30,
	}, root)
	refs.pill = pill
	refs.pillCorner = View.corner(pill, UDim.new(1, 0))
	refs.pillPad = View.padding(pill, layout.paddingX, layout.paddingY)
	View.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 0),
	}, pill)

	local commandRow = View.make("ScrollingFrame", {
		Name = "CommandRow",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		CanvasSize = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarImageColor3 = colors.promptText,
		ScrollBarImageTransparency = 1,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ZIndex = 32,
	}, pill)
	refs.commandRow = commandRow
	refs.commandText = View.make("TextLabel", {
		Name = "CommandText",
		Size = UDim2.new(1, -8, 0, panel.commandHeight),
		Position = UDim2.fromOffset(2, config.motion.textSlideOffset or 10),
		BackgroundTransparency = 1,
		Font = config.font.mono,
		RichText = true,
		Text = "",
		TextColor3 = colors.inputText,
		TextTransparency = 1,
		TextSize = layout.textSize,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 33,
	}, commandRow)

	createInputRow(pill, config, refs, "", 2, 0, 32)

	local addChat = View.make("TextButton", {
		Name = "AddChatPill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(startWidth, 0),
		BackgroundColor3 = colors.panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Selectable = true,
		Text = "",
		Visible = false,
		ZIndex = 29,
	}, root)
	refs.addChatPill = addChat
	View.corner(addChat, UDim.new(1, 0))
	View.padding(addChat, layout.paddingX, layout.paddingY)
	View.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, layout.itemGap + 4),
	}, addChat)
	refs.addChatIcon = View.make("ImageLabel", {
		Name = "AddChatIcon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = View.readAsset(panel.addChatAssetId),
		ImageColor3 = colors.promptText,
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 31,
	}, addChat)
	refs.addChatText = View.make("TextLabel", {
		Name = "AddChatText",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Font = config.font.mono,
		Text = "Add new chat window...",
		TextColor3 = colors.promptText,
		TextTransparency = 1,
		TextSize = layout.textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 31,
	}, addChat)

	local second = View.make("Frame", {
		Name = "SecondPill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(startWidth, 0),
		BackgroundColor3 = colors.panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 29,
	}, secondRoot)
	refs.secondPill = second
	refs.secondPillCorner = View.corner(second, UDim.new(1, 0))
	View.padding(second, layout.paddingX, layout.paddingY)
	View.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 0),
	}, second)

	local secondCommandRow = View.make("ScrollingFrame", {
		Name = "SecondCommandRow",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		CanvasSize = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarImageColor3 = colors.promptText,
		ScrollBarImageTransparency = 1,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ZIndex = 31,
	}, second)
	refs.secondCommandRow = secondCommandRow
	refs.secondCommandText = View.make("TextLabel", {
		Name = "SecondCommandText",
		Size = UDim2.new(1, -8, 0, panel.commandHeight),
		Position = UDim2.fromOffset(2, config.motion.textSlideOffset or 10),
		BackgroundTransparency = 1,
		Font = config.font.mono,
		RichText = true,
		Text = "",
		TextColor3 = colors.inputText,
		TextTransparency = 1,
		TextSize = layout.textSize,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 31,
	}, secondCommandRow)
	createInputRow(second, config, refs, "Second", 2, 1, 31)

	local clickTarget = View.make("TextButton", {
		Name = "PillClickTarget",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(panel.collapsedWidth, pillHeight),
		BackgroundTransparency = 1,
		Selectable = true,
		Text = "",
		ZIndex = 40,
	}, root)
	refs.pillBtn = clickTarget

	return root
end

function View.pointIn(frame, point)
	if typeof(frame) ~= "Instance" or not frame.Visible then
		return false
	end

	local pos = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

return View
