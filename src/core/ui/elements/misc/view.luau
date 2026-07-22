--[[
	@name view
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local imports = {
    Placement = require("./placement"),
    Text = require("./text"),
}

--// locals
local View = {}

local function createShadow(parent, name, config, zIndex, visible)
    return View.make("ImageLabel", {
        ImageTransparency = config.transparency.shadow,
        ImageColor3 = config.color.shadowColor,
        
        SliceCenter = Rect.new(10, 10, 118, 118),
        ScaleType = Enum.ScaleType.Slice,

        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        SliceScale = 1,
        
        Visible = visible ~= false,
        
        Name = name,
        ZIndex = zIndex,
        Image = View.readAsset(config.panel.shadowAssetId),
    }, parent)
end

local function createInputRow(parent, config, refs, prefix, order, visibleTransparency, zIndex)
    local layout = config.layout
    local colors = config.color
    local panel = config.panel
    
    local arrowTransparency = visibleTransparency >= 1 and 1 or (config.transparency.arrow or visibleTransparency)
    local inputHeight = panel.inputHeight or (panel.height - layout.paddingY * 2)

    local row = View.make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        ClipsDescendants = true,
        LayoutOrder = order,
        ZIndex = zIndex,
        
        Name = prefix .. "InputRow",
        Size = UDim2.new(1, 0, 0, inputHeight),
    }, parent)

    View.make("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Center,
        FillDirection = Enum.FillDirection.Horizontal,
        
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, layout.itemGap),
    }, row)

    local prompt = View.make("TextLabel", {
        Font = config.font.mono,

        TextTransparency = visibleTransparency,
        ZIndex = zIndex,
        
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        
        TextColor3 = colors.promptText,
        TextSize = layout.promptSize,
        
        BackgroundTransparency = 1,
        LayoutOrder = 1,
       
        Text = ">",
        Name = prefix .. "Prompt",
        Size = UDim2.fromOffset(layout.promptSize, inputHeight),
    }, row)

    local field = View.make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,

        ClipsDescendants = false,
        ZIndex = zIndex,
        
        Name = prefix .. "Field",
        Size = UDim2.new(1, -(layout.promptSize + layout.itemGap), 1, 0),
    }, row)

    local placeholder = View.make("TextLabel", {
        Font = config.font.mono,
        
        TextTransparency = visibleTransparency,
        ZIndex = zIndex,
        
        TextYAlignment = Enum.TextYAlignment.Center,
        TextXAlignment = Enum.TextXAlignment.Left,
        
        TextColor3 = colors.promptText,
        TextSize = layout.textSize,
        
        BackgroundTransparency = 1,
        
        Text = "type a command...",
        Name = prefix .. "Placeholder",
        Size = UDim2.new(1, -20, 1, 0),
    }, field)

    local input = View.make("TextBox", {
        Font = config.font.mono,
        
        TextTransparency = visibleTransparency,

        TextYAlignment = Enum.TextYAlignment.Center,
        TextXAlignment = Enum.TextXAlignment.Left,
        
        TextColor3 = colors.inputText,
        TextSize = layout.textSize,
        
        ClearTextOnFocus = false,
        MultiLine = false,
        Selectable = true,
        
        BackgroundTransparency = 1,
        ZIndex = zIndex + 1,

        Text = "",
        PlaceholderText = "",
        
        Visible = prefix == "",
        Name = prefix .. "InputBox",
        Size = UDim2.new(1, -20, 1, 0),
    }, field)

    local hintRow = View.make("Frame", {
        Position = UDim2.new(0, 0, 0.5, layout.hintOffsetY or 0),
        AutomaticSize = Enum.AutomaticSize.X,
        AnchorPoint = Vector2.new(0, 0.5),
        
        ClipsDescendants = false,
        
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = zIndex + 2,
        
        Name = prefix .. "HintRow",
        Size = UDim2.new(0, 0, 0, panel.hintHeight or 18),
    }, field)

    View.make("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Padding = UDim.new(0, layout.itemGap),
    }, hintRow)

    local arrow = View.make("ImageLabel", {
        ImageTransparency = arrowTransparency,
        
        Position = UDim2.new(1, 2, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.fromOffset(12, 12),

        ImageColor3 = colors.promptText,
        ScaleType = Enum.ScaleType.Fit,
        
        BackgroundTransparency = 1,
        ZIndex = zIndex + 20,
        BorderSizePixel = 0,

        Name = prefix .. "ArrowIcon",
        Image = View.readAsset(panel.arrowAssetId),
    }, field)

    refs[prefix .. "Placeholder"] = placeholder
    refs[prefix .. "ArrowIcon"] = arrow
    refs[prefix .. "HintRow"] = hintRow
    
    refs[prefix .. "InputBox"] = input
    refs[prefix .. "Prompt"] = prompt

    return row
end

local function createPill(parent, config, name, width, height, zIndex, visible)
    local colors = config.color
    local layout = config.layout

    local pill = View.make("Frame", {
        Visible = visible ~= false,
        ClipsDescendants = true,

        BackgroundColor3 = colors.panel,
         
        Size = UDim2.fromOffset(width, height),
        Position = UDim2.new(0.5, 0, 1, 0),
        AnchorPoint = Vector2.new(0.5, 1),

        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        
        Name = name,
        ZIndex = zIndex,
    }, parent)

    local padding = View.padding(pill, layout.paddingX, layout.paddingY)
    local corner = View.corner(pill, UDim.new(1, 0))

    View.make("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        FillDirection = Enum.FillDirection.Vertical,

        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, pill)

    return pill, corner, padding
end

local function createHistory(parent, config, refs, names, rowZIndex, textZIndex)
    local layout = config.layout
    local colors = config.color
    local panel = config.panel

    local row = View.make("ScrollingFrame", {
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarImageColor3 = colors.promptText,
        Name = names.row,
        
        ScrollBarImageTransparency = 1,
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        
        BorderSizePixel = 0,
        LayoutOrder = 1,
        
        ClipsDescendants = true,
        Visible = false,
        
        ZIndex = rowZIndex,
        
        Size = UDim2.new(1, 0, 0, 0),
        CanvasSize = UDim2.fromOffset(0, 0),
    }, parent)

    local text = View.make("TextLabel", {
        BackgroundTransparency = 1,
        TextTransparency = 1,
        
        TextWrapped = false,
        RichText = true,

        Position = UDim2.fromOffset(2, config.motion.textSlideOffset or 10),
        TextSize = layout.textSize,
        ZIndex = textZIndex,
        
        Font = config.font.mono,
        Name = names.text,

        Text = "",
        TextColor3 = colors.inputText,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        
        Size = UDim2.new(1, -8, 0, panel.commandHeight),
    }, row)

    refs[names.refText] = text
    refs[names.refRow] = row
    
    return row, text
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
        PaddingBottom = UDim.new(0, bottom or top),
        PaddingRight = UDim.new(0, right or left),
        PaddingLeft = UDim.new(0, left),
        PaddingTop = UDim.new(0, top),
    }, parent)
end

function View.setShadowBounds(shadow, frame)
    if typeof(shadow) ~= "Instance" or typeof(frame) ~= "Instance" then
        return
    end

    local size = frame.Size
    local position = frame.Position
    local xOffset = frame.AnchorPoint.X == 0.5 and 0 or -3

    shadow.Position = UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset + 3)
    shadow.Size = UDim2.new(size.X.Scale, size.X.Offset + 6, size.Y.Scale, size.Y.Offset + 8)
   
    shadow.AnchorPoint = frame.AnchorPoint
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
    
    local transparency = config.transparency
    local layout = config.layout
    local refs = session.refs
    
    local pillHeight = panel.height
    local startWidth = pillHeight
    
    local startPosition, startAnchor = imports.Placement.resolve(panel.position, pillHeight / 2)

    local root = View.make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 30,
        
        ClipsDescendants = false,
        Position = startPosition,
        
        AnchorPoint = startAnchor,
        Size = UDim2.fromOffset(startWidth, pillHeight),
        
        Name = "TerminalRoot",
    }, gui)

    refs.root = root

    local secondRoot = View.make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 30,
        
        Position = startPosition,
        ClipsDescendants = false,
        Visible = false,
        
        AnchorPoint = startAnchor,
        Size = UDim2.fromOffset(startWidth, 0),

        Name = "SecondTerminalRoot",
    }, gui)

    refs.secondRoot = secondRoot

    refs.secondShadow = createShadow(secondRoot, "SecondShadow", config, 27, false)
    refs.suggShadow = createShadow(root, "AutofillShadow", config, 27, false)
    
    refs.stackShadow = createShadow(root, "StackShadow", config, 26, false)
    refs.pillShadow = createShadow(root, "PillShadow", config, 27, true)

    local suggestionPosition, suggestionAnchor = imports.Placement.suggestion(root, panel.suggestionGap)

    local suggList = View.make("ScrollingFrame", {
        ScrollingEnabled = true,
        Active = true,

        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarImageTransparency = 1,
        ScrollBarThickness = 0,

        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 28,

        Position = suggestionPosition,
        Size = UDim2.fromOffset(panel.width, 0),
        CanvasSize = UDim2.fromOffset(0, 0),
        AnchorPoint = suggestionAnchor,
        
        BackgroundColor3 = colors.suggPanel,

        Visible = false,
        ClipsDescendants = true,
        
        Name = "SuggList",
    }, root)

    View.corner(suggList, panel.suggestionRadius or 10)

    View.make("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Top,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Padding = UDim.new(0, 0),
    }, suggList)

    View.padding(suggList, 0, 2, 0, 2)

    refs.suggList = suggList

    local pill, pillCorner, pillPad = createPill(root, config, "Pill", startWidth, pillHeight, 30)

    pill.BackgroundTransparency = transparency.panel

    refs.pillCorner = pillCorner
    refs.pillPad = pillPad
    refs.pill = pill

    createHistory(pill, config, refs, {
        refText = "commandText",
        refRow = "commandRow",

        text = "CommandText",
        row = "CommandRow",
    }, 32, 33)

    createInputRow(pill, config, refs, "", 2, 0, 32)

    local addChat = View.make("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 29,

        Size = UDim2.fromOffset(startWidth, 0),
        Position = UDim2.new(0.5, 0, 1, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        
        BackgroundColor3 = colors.panel,

        AutoButtonColor = false,
        ClipsDescendants = true,
        Selectable = true,
        Visible = false,
        
        Text = "",
        Name = "AddChatPill",
    }, root)

    refs.addChatPill = addChat

    View.padding(addChat, layout.paddingX, layout.paddingY)
    View.corner(addChat, UDim.new(1, 0))
 
    View.make("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Center,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Padding = UDim.new(0, layout.itemGap + 4),
    }, addChat)

    refs.addChatIcon = View.make("ImageLabel", {
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        BorderSizePixel = 0,
        
        LayoutOrder = 1,
        ZIndex = 31,
        
        Image = View.readAsset(panel.addChatAssetId),
        ImageColor3 = colors.promptText,
        ScaleType = Enum.ScaleType.Fit,

        Name = "AddChatIcon",
        Size = UDim2.fromOffset(18, 18),
    }, addChat)

    refs.addChatText = View.make("TextLabel", {
        BackgroundTransparency = 1,
        TextTransparency = 1,
        
        LayoutOrder = 2,
        ZIndex = 31,

        TextSize = layout.textSize,
        Font = config.font.mono,
        
        Text = "Add new chat window...",
        Name = "AddChatText",
        
        Size = UDim2.fromOffset(0, 0),
        TextColor3 = colors.promptText,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, addChat)

    local second, secondCorner = createPill(secondRoot, config, "SecondPill", startWidth, 0, 29, false)

    refs.secondPill = second
    refs.secondPillCorner = secondCorner

    createHistory(second, config, refs, {
        refText = "secondCommandText",
        refRow = "secondCommandRow",

        text = "SecondCommandText",
        row = "SecondCommandRow",
    }, 31, 31)

    createInputRow(second, config, refs, "Second", 2, 1, 31)

    local clickTarget = View.make("TextButton", {
        BackgroundTransparency = 1,
        ZIndex = 40,
        
        Size = UDim2.fromOffset(panel.collapsedWidth, pillHeight),
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),

        Selectable = true,
   
        Text = "",
        Name = "PillClickTarget",
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
