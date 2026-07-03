--[[
	@name panel
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

local imports = {
	TextService = game:GetService("TextService"),
	Workspace = game:GetService("Workspace"),

	History = require("../backend/history"),
	Shape = require("../../motion/math/shape"),
	View = require("../misc/view"),
}

local Panel = {}

local function measureText(text, config)
	local size =
		imports.TextService:GetTextSize(text, config.layout.textSize, config.font.mono, Vector2.new(10000, 10000))
	return size
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
		local baseLimit = channel == 2 and (panel.stackHistoryMaxHeight or 280) or (panel.historyMaxHeight or 420)
		local camera = imports.Workspace.CurrentCamera
		if typeof(camera) ~= "Instance" then
			return baseLimit
		end

		local available = camera.ViewportSize.Y - (panel.bottomInset or 24) - (panel.viewportTopInset or 72)
		if not self.hasSecondChat then
			return math.max(panel.commandHeight, math.min(baseLimit, available - panel.height))
		end

		if channel == 2 then
			local bottomAvailable = available - (panel.height * 2) - (panel.stackGap or 8) - (panel.commandHeight or 14)
			return math.max(panel.commandHeight, math.min(baseLimit, bottomAvailable))
		end

		local bottomHeight = math.min(self:rawHistoryHeight(2), panel.stackHistoryMaxHeight or 280)
		local remaining = available - (panel.height * 2) - (panel.stackGap or 8) - bottomHeight
		return math.max(panel.commandHeight, math.min(baseLimit, remaining))
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
		local first = math.max(1, math.floor(top / lineHeight) + 1 - buffer)
		local last = math.min(total, math.ceil((top + height) / lineHeight) + buffer)
		return first, last
	end

	function Session:renderHistory(channel)
		local _, row, label = self:channelState(channel)
		if typeof(row) ~= "Instance" or typeof(label) ~= "Instance" then
			return
		end

		local panel = self.config.panel
		local lineHeight = self:lineHeight()
		local rawHeight = self:rawHistoryHeight(channel)
		local visibleHeight = self:historyHeight(channel)
		row.CanvasSize = UDim2.fromOffset(0, rawHeight)
		row.ScrollBarImageTransparency = rawHeight > visibleHeight + 1 and 0.35 or 1

		local lines = self:historyLines(channel)
		local contentName = channel == 2 and "secondHistoryContent" or "historyContent"
		local content = self.refs[contentName]
		if typeof(content) ~= "Instance" then
			content = imports.View.make("Frame", {
				Name = "HistoryContent",
				Position = UDim2.fromOffset(2, 0),
				Size = UDim2.new(1, -14, 0, rawHeight),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = label.ZIndex,
			}, row)
			self.refs[contentName] = content
		end

		content.Size = UDim2.new(1, -14, 0, rawHeight)
		label.Text = ""
		label.Visible = false

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
				Name = string.format("Chunk_%04d", math.ceil(first / chunkSize)),
				Position = UDim2.fromOffset(0, (first - 1) * lineHeight),
				Size = UDim2.new(1, 0, 0, (last - first + 1) * lineHeight),
				BackgroundTransparency = 1,
				Font = self.config.font.mono,
				RichText = true,
				Text = imports.History.chunkText(lines, first, last),
				TextColor3 = self.config.color.inputText,
				TextTransparency = self.config.transparency.text,
				TextSize = self.config.layout.textSize,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = label.ZIndex,
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
		row.ScrollBarImageTransparency = rawHeight > visibleHeight + 1 and 0.35 or 1
		self.syncingScroll[channel] = true
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

		local lineHeight = self:lineHeight()
		local first, last = self:visibleLineRange(channel, 0)
		local bottom = top + height
		local minVisible = math.max(2, lineHeight * 0.96)
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

	function Session:contentWidth()
		local pill = self.refs.pill
		if typeof(pill) ~= "Instance" or pill.AbsoluteSize.X < 1 then
			return 0
		end

		local widest = 0
		for _, channel in { 1, 2 } do
			local input = channel == 2 and self.refs.SecondInputBox or self.refs.InputBox
			local row = channel == 2 and self.refs.SecondHintRow or self.refs.HintRow

			if typeof(input) == "Instance" and input.Visible then
				local field = input.Parent
				if typeof(field) == "Instance" then
					local leftEdge = field.AbsolutePosition.X - pill.AbsolutePosition.X
					local textWidth = measureText(tostring(input.Text or ""), self.config).X
					widest = math.max(widest, leftEdge + textWidth)
				end
			end

			if self.structured[channel] and typeof(row) == "Instance" and row.AbsoluteSize.X > 1 then
				local rightEdge = (row.AbsolutePosition.X + row.AbsoluteSize.X) - pill.AbsolutePosition.X
				widest = math.max(widest, rightEdge)
			end
		end

		if widest <= 0 then
			return 0
		end

		return math.ceil(widest + (self.config.layout.paddingX or 12) + 16)
	end

	function Session:activeWidth()
		local panel = self.config.panel
		local base = panel.width
		if self.hasOutput or self.hasSecondOutput then
			base = panel.outputWidth or panel.width
		end

		local measured = math.max(self:historyWidth(1), self:historyWidth(2), self:contentWidth())
		if measured > 0 then
			base = math.max(base, measured)
		end
		if self.restoredWidth then
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
		local refs = self.refs
		local panel = self.config.panel
		if typeof(refs.root) == "Instance" then
			refs.root.Size = UDim2.fromOffset(width, refs.root.Size.Y.Offset)
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
		if typeof(refs.secondPill) == "Instance" and refs.secondPill.Visible then
			refs.secondPill.Size = UDim2.fromOffset(width, refs.secondPill.Size.Y.Offset)
		end
		if typeof(refs.suggList) == "Instance" and refs.suggList.Visible and not self.suggestionsHiding then
			refs.suggList.Size = UDim2.fromOffset(width, refs.suggList.Size.Y.Offset)
		end
	end

	function Session:queueWidthRefresh()
		if not self.isExpanded then
			return
		end

		local targetWidth = self:activeWidth()
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
			local currentTarget = self:activeWidth()
			self.queuedWidth = nil
			if self.layoutTargetWidth and math.abs(currentTarget - self.layoutTargetWidth) < threshold then
				return
			end
			self:layoutStack((self.config.motion.outputSmoothTime or 0.24) * 0.8, currentTarget)
		end)
	end

	function Session:queueVisibleWidthRefresh()
		if not self.isExpanded then
			return
		end

		self:queueWidthRefresh()
		task.defer(function()
			if self.refs then
				self:queueWidthRefresh()
			end
		end)
		task.delay(0.08, function()
			if self.refs then
				self:queueWidthRefresh()
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
		if not self.isExpanded or not self.hasOutput then
			return 0
		end

		local bottomHeight = self.hasSecondChat and self:secondHeight() or self.config.panel.height
		return bottomHeight + (self.config.panel.stackGap or 8)
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

	function Session:queueShadowUpdate()
		if self.shadowQueued then
			return
		end

		self.shadowQueued = true
		task.defer(function()
			self.shadowQueued = false
			if self.refs then
				self:updateShadows()
			end
		end)
	end

	function Session:updateShadows()
		if self.isDestroying then
			return
		end

		local refs = self.refs
		imports.View.setShadowBounds(refs.pillShadow, refs.pill)
		if typeof(refs.pillShadow) == "Instance" then
			refs.pillShadow.Visible = true
		end

		if typeof(refs.suggShadow) == "Instance" and typeof(refs.suggList) == "Instance" then
			imports.View.setShadowBounds(refs.suggShadow, refs.suggList)
			if self.suggestionsHiding then
				refs.suggShadow.Visible = true
			else
				refs.suggShadow.Visible = refs.suggList.Visible and refs.suggList.AbsoluteSize.Y > 1
			end
		end

		local target = nil
		if self.hasSecondChat and typeof(refs.secondPill) == "Instance" and refs.secondPill.Visible then
			target = refs.secondPill
		elseif typeof(refs.addChatPill) == "Instance" and refs.addChatPill.Visible then
			target = refs.addChatPill
		end
		if typeof(refs.stackShadow) == "Instance" then
			if target then
				imports.View.setShadowBounds(refs.stackShadow, target)
				refs.stackShadow.Visible = true
			elseif not self.stackShadowHiding then
				refs.stackShadow.Visible = false
			end
		end
	end

	function Session:layoutStack(duration, targetWidth)
		imports.Shape.layout(self, duration, targetWidth)
	end
end

return Panel
