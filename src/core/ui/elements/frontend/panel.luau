--[[
	@name panel
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--// imports
local imports = {
    TextService = game:GetService("TextService"),
    Workspace = game:GetService("Workspace"),

    Shape = require("../../motion/math/shape"),
    History = require("../backend/history"),
    View = require("../misc/view"),
}

--// locals
local function measureText(text, config)
    local size = imports.TextService:GetTextSize(
        text,

        config.layout.textSize,
        config.font.mono,

        Vector2.new(10000, 10000)
    )

    return size
end

local function textGap(config)
    return math.floor((measureText("a a", config).X - measureText("aa", config).X) * 0.5)
end

local function visibleWindow(session, channel)
    local _, row = session:channelState(channel)
    local raw = session:rawHistoryHeight(channel)

    local pinned = session.autoScroll[channel] ~= false

    if typeof(row) == "Instance" and row.Visible and row.AbsoluteSize.Y > 1 then

        local height = row.AbsoluteSize.Y
        local top = pinned and math.max(0, raw - height) or math.max(0, row.CanvasPosition.Y)

        return top, height
    end

    local height = session:historyHeight(channel)

    if height <= 1 then
        return 0, 0
    end

    return pinned and math.max(0, raw - height) or math.max(0, session.savedScroll[channel] or 0), height
end

--// public api
local Panel = {}

function Panel.attach(Session)
    function Session:channelState(channel)
        if channel == 2 then
            return self.secondHistory, self.refs.secondCommandRow, self.refs.secondCommandText
        end

        return self.history, self.refs.commandRow, self.refs.commandText
    end

    function Session:markHistoryDirty(channel)
        self.historyDirty[channel] = true
        self.historyVersion[channel] = (self.historyVersion[channel] or 0) + 1
    end

    function Session:saveScroll()
        for channel, row in { self.refs.commandRow, self.refs.secondCommandRow } do
            if typeof(row) == "Instance" then
                self.savedScroll[channel] = row.CanvasPosition.Y
            end
        end
    end

    function Session:historyLines(channel)
        if self.lineCache[channel] == nil or self.historyDirty[channel] then
            local items = channel == 2 and self.secondHistory or self.history

            self.lineCache[channel] = imports.History.displayLines(items, self.config)
            self.historyDirty[channel] = false
        end

        return self.lineCache[channel]
    end

    function Session:lineHeight()
        if not self.measuredLineHeight then
            local panel = self.config.panel
            
            local measured = measureText("Ag\nAg", self.config)
            self.measuredLineHeight =
                math.max(panel.historyLineHeight or panel.commandHeight, math.ceil(measured.Y / 2))
        end

        return self.measuredLineHeight
    end

    function Session:rawHistoryHeight(channel)
        local lines = self:historyLines(channel)

        if #lines == 0 then
            return 0
        end

        return math.max(self.config.panel.commandHeight, #lines * self:lineHeight())
    end

    function Session:historyLimit(channel)
        local panel = self.config.panel
        
        local baseLimit = panel.historyMaxHeight or 420
        local camera = imports.Workspace.CurrentCamera

        if typeof(camera) ~= "Instance" then
            return baseLimit
        end

        local bottom = camera.ViewportSize.Y
        local position = channel == 2 and self.secondRootPosition or self.rootPosition

        if typeof(position) == "UDim2" then
            bottom = (camera.ViewportSize.Y * position.Y.Scale) + position.Y.Offset
        end

        if channel == 1 then
            bottom -= self:stackExtra()
        end

        local available = bottom - (panel.viewportTopInset or 24)

        return math.max(panel.commandHeight, math.min(baseLimit, available - panel.height))
    end

    function Session:historyHeight(channel)
        local rawHeight = self:rawHistoryHeight(channel)

        if rawHeight <= 0 then
            return 0
        end

        return math.min(rawHeight, self:historyLimit(channel))
    end

    function Session:visibleLineRange(channel, buffer)
        local lines = self:historyLines(channel)
        local total = #lines

        if total == 0 then
            return 1, 0
        end

        local top, height = visibleWindow(self, channel)

        if height <= 0 then
            return 1, 0
        end

        local lineHeight = self:lineHeight()

        buffer = tonumber(buffer) or 8

        local last = math.min(total, math.ceil((top + height) / lineHeight) + buffer)
        local first = math.max(1, math.floor(top / lineHeight) + 1 - buffer)
        
        return first, last
    end

    function Session:renderHistory(channel)
        local _, row, label = self:channelState(channel)
        if typeof(row) ~= "Instance" or typeof(label) ~= "Instance" then
            return
        end

        local panel = self.config.panel

        local rawHeight = self:rawHistoryHeight(channel)
        local lineHeight = self:lineHeight()

        row.CanvasSize = UDim2.fromOffset(0, rawHeight)

        local lines = self:historyLines(channel)

        local contentName = channel == 2 and "secondHistoryContent" or "historyContent"
        local content = self.refs[contentName]

        if typeof(content) ~= "Instance" then
            content = imports.View.make("Frame", {

                BackgroundTransparency = 1,
                BorderSizePixel = 0,

                Name = "HistoryContent",

                ZIndex = label.ZIndex,
                Position = UDim2.fromOffset(2, 0),
                Size = UDim2.new(1, -14, 0, rawHeight),

            }, row)

            self.refs[contentName] = content
        end

        content.Size = UDim2.new(1, -14, 0, rawHeight)

        label.Visible = false
        label.Text = ""

        local version = self.historyVersion[channel] or 0
        if self.renderedVersion[channel] == version then
            return
        end

        self.renderedVersion[channel] = version

        for _, child in content:GetChildren() do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        if #lines == 0 then
            return
        end

        local chunkSize = math.max(20, tonumber(panel.historyChunkLines) or 90)

        for first = 1, #lines, chunkSize do
            local last = math.min(#lines, first + chunkSize - 1)

            imports.View.make("TextLabel", {

                BackgroundTransparency = 1,

                TextTransparency = self.config.transparency.text,
                TextColor3 = self.config.color.inputText,

                TextWrapped = false,
                RichText = true,

                Position = UDim2.fromOffset(0, (first - 1) * lineHeight),
                TextSize = self.config.layout.textSize,
                ZIndex = label.ZIndex,

                Name = string.format("Chunk_%04d", math.ceil(first / chunkSize)),
                Font = self.config.font.mono,

                TextYAlignment = Enum.TextYAlignment.Top,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = imports.History.chunkText(lines, first, last),
                Size = UDim2.new(1, 0, 0, (last - first + 1) * lineHeight),

            }, content)
        end
    end

    function Session:syncScroll(channel)
        local _, row, label = self:channelState(channel)
        if typeof(row) ~= "Instance" or typeof(label) ~= "Instance" then
            return
        end

        local rawHeight = self:rawHistoryHeight(channel)
        local visibleHeight = self:historyHeight(channel)

        row.CanvasSize = UDim2.fromOffset(0, rawHeight)

        self.syncingScroll[channel] = true
        -->
        if self.autoScroll[channel] ~= false then

            row.CanvasPosition = Vector2.new(0, math.max(0, rawHeight - visibleHeight))
        else
            local limit = math.max(0, rawHeight - visibleHeight)
            local saved = tonumber(self.savedScroll[channel]) or row.CanvasPosition.Y

            row.CanvasPosition = Vector2.new(0, math.clamp(saved, 0, limit))
        end

        self:renderHistory(channel)

        task.defer(function()
            if self.refs then
                self:renderHistory(channel)
            end

            self.syncingScroll[channel] = false
        end)
    end

    function Session:syncScrollSoon(channel, duration)
        self.scrollSyncToken[channel] = (self.scrollSyncToken[channel] or 0) + 1
        local token = self.scrollSyncToken[channel]

        self:syncScroll(channel)

        task.defer(function()
            if self.refs and self.scrollSyncToken[channel] == token then

                self:syncScroll(channel)
            end
        end)

        task.delay(duration or 0.05, function()
            if self.refs and self.scrollSyncToken[channel] == token then

                self:syncScroll(channel)
            end
        end)
    end

    function Session:historyWidth(channel)
        local lines = self:historyLines(channel)

        if #lines == 0 then
            return 0
        end

        local top, height = visibleWindow(self, channel)

        if height <= 0 then
            return 0
        end

        local first, last = self:visibleLineRange(channel, 0)
        local lineHeight = self:lineHeight()

        local minVisible = math.max(2, lineHeight * 0.96)

        local bottom = top + height

        local maxTextWidth = 0

        for index = first, last do
            local line = lines[index]

            local lineTop = (index - 1) * lineHeight
            local visibleAmount = math.min(lineTop + lineHeight, bottom) - math.max(lineTop, top)

            if line and visibleAmount >= minVisible then
                if not line.width then
                    line.width = measureText(line.plain, self.config).X
                end

                maxTextWidth = math.max(maxTextWidth, line.width)
            end
        end

        if maxTextWidth <= 0 then
            return 0
        end

        return math.ceil(maxTextWidth + (self.config.layout.paddingX * 2) + 10)
    end

    function Session:contentWidth(channel)
        channel = channel == 2 and 2 or 1

        local input = channel == 2 and self.refs.SecondInputBox or self.refs.InputBox
        local row = channel == 2 and self.refs.SecondHintRow or self.refs.HintRow
        local pill = channel == 2 and self.refs.secondPill or self.refs.pill

        if typeof(pill) ~= "Instance" or not pill:IsA("GuiObject") or pill.AbsoluteSize.X < 1 then
            return 0
        end

        local widest = 0

        local textWidth
        local leftEdge

        if typeof(input) == "Instance" and input:IsA("TextBox") and input.Visible then
            local field = input.Parent

            if typeof(field) == "Instance" and field:IsA("GuiObject") then
                leftEdge = field.AbsolutePosition.X - pill.AbsolutePosition.X
                textWidth = measureText(tostring(input.Text or ""), self.config).X

                widest = math.max(widest, leftEdge + textWidth)
            end
        end

        if
            typeof(row) == "Instance"
            and row:IsA("GuiObject")
            and self.structured[channel]
            and row.AbsoluteSize.X > 1
        then
            local rightEdge = (row.AbsolutePosition.X + row.AbsoluteSize.X) - pill.AbsolutePosition.X

            if leftEdge and textWidth then
                rightEdge = leftEdge + textWidth + textGap(self.config) + row.AbsoluteSize.X
            end

            widest = math.max(widest, rightEdge)
        end

        return widest > 0 and math.ceil(widest + (self.config.layout.paddingX or 12) + 16) or 0
    end

    function Session:activeWidth(channel)
        channel = channel == 2 and 2 or 1
        
        local panel = self.config.panel
        
        local hasOutput = channel == 2 and self.hasSecondOutput or self.hasOutput
        local base = hasOutput and (panel.outputWidth or panel.width) or panel.width

        local measured = math.max(
            self:historyWidth(channel),
            self:contentWidth(channel)
        )

        if channel == 1 and not self.secondDetached and self.hasSecondChat then
            measured = math.max(
                measured,
                self:historyWidth(2),
                self:contentWidth(2)
            )
        end

        if measured > 0 then
            base = math.max(base, measured)
        end

        if channel == 1 and self.restoredWidth then
            base = math.max(base, self.restoredWidth)
        end

        local viewportMax = panel.maxWidth or panel.wideWidth or base
        local camera = imports.Workspace.CurrentCamera

        if typeof(camera) == "Instance" then
            viewportMax = math.min(viewportMax, math.max(panel.width, camera.ViewportSize.X - 24))
        end

        return math.clamp(base, panel.width, viewportMax)
    end


    function Session:syncWidths(width)
        local panel = self.config.panel
        local refs = self.refs

        if typeof(refs.root) == "Instance" then
            refs.root.Size = UDim2.fromOffset(width, refs.root.Size.Y.Offset)
        end

        if not self.secondDetached and typeof(refs.secondRoot) == "Instance" then
            refs.secondRoot.Size = UDim2.fromOffset(width, refs.secondRoot.Size.Y.Offset)
        end

        if typeof(refs.pill) == "Instance" then
            refs.pill.Size = UDim2.fromOffset(width, refs.pill.Size.Y.Offset)
        end

        if typeof(refs.pillBtn) == "Instance" then
            refs.pillBtn.Size = UDim2.fromOffset(width, panel.height)
        end

        if typeof(refs.addChatPill) == "Instance" and refs.addChatPill.Visible then
            local addWidth = self.hasSecondChat and width or self:addChatWidth(width)

            refs.addChatPill.Size = UDim2.fromOffset(addWidth, refs.addChatPill.Size.Y.Offset)
        end

        if not self.secondDetached and typeof(refs.secondPill) == "Instance" and refs.secondPill.Visible then
            refs.secondPill.Size = UDim2.fromOffset(width, refs.secondPill.Size.Y.Offset)
        end

        if typeof(refs.suggList) == "Instance" and refs.suggList.Visible and not self.suggestionsHiding then
            local suggestionWidth = refs.suggList.Parent == refs.secondRoot and self:activeWidth(2) or width

            refs.suggList.Size = UDim2.fromOffset(suggestionWidth, refs.suggList.Size.Y.Offset)
        end
    end

    function Session:syncSecondWidth(width)
        local refs = self.refs

        if typeof(refs.secondRoot) == "Instance" then
            refs.secondRoot.Size = UDim2.fromOffset(width, refs.secondRoot.Size.Y.Offset)
        end

        if typeof(refs.secondPill) == "Instance" and refs.secondPill.Visible then
            refs.secondPill.Size = UDim2.fromOffset(width, refs.secondPill.Size.Y.Offset)
        end
    end

    function Session:queueWidthRefresh(channel)
        channel = channel == 2 and 2 or 1

        if not self.isExpanded then
            return
        end

        if channel == 2 and self.secondDetached then
            local targetWidth = self:activeWidth(2)
            local threshold = 3

            if self.secondLayoutTargetWidth and math.abs(targetWidth - self.secondLayoutTargetWidth) < threshold then
                return
            end

            if self.secondQueuedWidth and math.abs(targetWidth - self.secondQueuedWidth) < threshold then
                return
            end

            self.secondQueuedWidth = targetWidth
            self.secondWidthRefreshToken += 1

            local token = self.secondWidthRefreshToken

            task.defer(function()
                if not self.refs or token ~= self.secondWidthRefreshToken then
                    return
                end

                local width = self:activeWidth(2)

                self.secondQueuedWidth = nil

                if self.secondLayoutTargetWidth and math.abs(width - self.secondLayoutTargetWidth) < threshold then
                    return
                end

                imports.Shape.layoutDetachedSecond(self, (self.config.motion.outputSmoothTime or 0.24) * 0.8, width)
            end)

            return
        end

        local targetWidth = self:activeWidth(1)
        local threshold = 3

        if self.layoutTargetWidth and math.abs(targetWidth - self.layoutTargetWidth) < threshold then
            return
        end

        if self.queuedWidth and math.abs(targetWidth - self.queuedWidth) < threshold then
            return
        end

        self.queuedWidth = targetWidth
        self.widthRefreshToken += 1

        local token = self.widthRefreshToken

        task.defer(function()
            if not self.refs or token ~= self.widthRefreshToken then
                return
            end

            local width = self:activeWidth(1)

            self.queuedWidth = nil
            if self.layoutTargetWidth and math.abs(width - self.layoutTargetWidth) < threshold then
                return
            end

            self:layoutStack((self.config.motion.outputSmoothTime or 0.24) * 0.8, width)
        end)
    end

    function Session:queueVisibleWidthRefresh(channel)
        channel = channel == 2 and 2 or 1

        self:queueWidthRefresh(channel)

        task.defer(function()
            if self.refs then
                self:queueWidthRefresh(channel)
            end
        end)

        task.delay(0.08, function()
            if self.refs then
                self:queueWidthRefresh(channel)
            end
        end)
    end

    function Session:mainHeight()
        return self.config.panel.height + (self.hasOutput and self:historyHeight(1) or 0)
    end

    function Session:secondHeight()
        return self.config.panel.height + (self.hasSecondOutput and self:historyHeight(2) or 0)
    end

    function Session:stackExtra()
        if not self.isExpanded then
            return 0
        end

        if self.hasSecondChat then
            if self.secondDetached then
                return 0
            end

            return self:secondHeight() + (self.config.panel.stackGap or 8)
        end

        if not self.hasOutput then
            return 0
        end

        return self.config.panel.height + (self.config.panel.stackGap or 8)
    end

    function Session:addChatWidth(fullWidth)
        local panel = self.config.panel

        if not self.addChatHover then
            return panel.addChatCollapsedWidth or panel.height
        end

        local hoverWidth = panel.addChatHoverWidth or panel.collapsedWidth

        return math.min(fullWidth or hoverWidth, hoverWidth)
    end

    function Session:setAddChatHover(hovering)
        self.addChatHover = hovering == true

        if self.hasSecondChat or not self.isExpanded or not self.hasOutput then
            return
        end

        imports.Shape.hover(self)
    end

    function Session:updateShadows()
        if self.isDestroying then
            return
        end

        local refs = self.refs

        if typeof(refs.pillShadow) == "Instance" then
            refs.pillShadow.Visible = true
        end

        if typeof(refs.suggShadow) == "Instance" and typeof(refs.suggList) == "Instance" then
            if self.suggestionsHiding then
                refs.suggShadow.Visible = true
            else
                refs.suggShadow.Visible = refs.suggList.Visible and refs.suggList.AbsoluteSize.Y > 1
            end
        end

        local target = typeof(refs.addChatPill) == "Instance" and refs.addChatPill.Visible and refs.addChatPill or nil

        if typeof(refs.stackShadow) == "Instance" then
            if target then
                refs.stackShadow.Visible = true

            elseif not self.stackShadowHiding then
                refs.stackShadow.Visible = false
            end
        end

        local secondTarget = self.hasSecondChat
            and typeof(refs.secondPill) == "Instance"
            and refs.secondPill.Visible
            and refs.secondPill
            or nil

        if typeof(refs.secondShadow) == "Instance" then
            if secondTarget then
                refs.secondShadow.Visible = true

            elseif not self.secondShadowHiding then
                refs.secondShadow.Visible = false
            end
        end
    end

    function Session:layoutStack(duration, targetWidth)
        imports.Shape.layout(self, duration, targetWidth)
    end
end

return Panel
