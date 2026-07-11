--[[
	@name hints
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
	TextService = game:GetService("TextService"),
	Players = game:GetService("Players"),

	Arguments = require("../../../shared/kommand/arguments"),
	Hint = require("../../motion/suggest/hint"),
	Text = require("../misc/text"),
	View = require("../misc/view"),
}

--// locals
local function hintRowFor(self, channel)
	return channel == 2 and self.refs.SecondHintRow or self.refs.HintRow
end

local function mainInputFor(self, channel)
	return channel == 2 and self.refs.SecondInputBox or self.refs.InputBox
end

local function measureWidth(config, text)
	local size =
		imports.TextService:GetTextSize(text, config.layout.textSize, config.font.mono, Vector2.new(100000, 100000))
	return size.X
end

local function hintGap(config)
	return math.floor((measureWidth(config, "a a") - measureWidth(config, "aa")) * 0.5)
end

local function valueWidth(config, text)
	if text == "" then
		return 0
	end

	local size = config.layout.hintTextSize or 13
	local font = config.font.mono
	local full = imports.TextService:GetTextSize(text .. ".", size, font, Vector2.new(100000, 100000)).X
	local dot = imports.TextService:GetTextSize(".", size, font, Vector2.new(100000, 100000)).X
	return full - dot
end

local function textOffset(self, channel)
	local input = mainInputFor(self, channel)
	local config = self.config
	local text = typeof(input) == "Instance" and tostring(input.Text or "") or ""
	text = (string.gsub(text, "%s+$", ""))
	local gap = hintGap(config)
	if text == "" then
		return gap
	end

	return measureWidth(config, text) + gap
end

local function argLabel(arg, index)
	local name = tostring(arg.name or ("arg" .. index))
	local typeName = string.lower(tostring(arg.type or "string"))
	local optional = arg.required == false or arg.default ~= nil
	return optional and (name .. "?") or name, typeName
end

local function quoteIfNeeded(value)
	local text = imports.Text.trim(value)
	if text ~= "" and string.find(text, "%s") then
		return string.format("%q", text)
	end

	return text
end

local function fixedTokenArg(arg)
	local typeName = string.lower(tostring(arg.type or "string"))
	return typeName == "number" or typeName == "boolean"
end

local function argValid(arg, text)
	text = imports.Text.trim(text)
	if text == "" then
		return true
	end

	local typeName = string.lower(tostring(arg.type or "string"))
	local convert = imports.Arguments.types[typeName]
	if type(convert) ~= "function" then
		return true
	end

	local ok = convert(text, imports.Players.LocalPlayer)
	return ok == true
end

--// public api
local Hints = {}

function Hints.attach(Session)
	function Session:setSchemas(map)
		self.argSchemas = type(map) == "table" and map or {}
	end

	function Session:commandContext(text)
		local schemas = type(self.argSchemas) == "table" and self.argSchemas or {}
		local tokens = imports.Arguments.tokenize(text)
		local firstToken = tostring(tokens[1] or "")
		local commandWord = string.lower(firstToken)
		local args = schemas[commandWord]
		local word = firstToken
		local glued = nil

		if args == nil and #tokens == 1 and firstToken ~= "" then
			local best = nil
			for name in schemas do
				if
					#name < #commandWord
					and string.sub(commandWord, 1, #name) == name
					and (best == nil or #name > #best)
				then
					best = name
				end
			end

			if best then
				commandWord = best
				args = schemas[best]
				word = string.sub(firstToken, 1, #best)
				glued = string.sub(firstToken, #best + 1)
			end
		end

		local hasArgs = type(args) == "table" and #args > 0
		local trailingSpace = string.match(text, "%s$") ~= nil
		local supplied = math.max(0, #tokens - 1)
		local completed = trailingSpace and supplied or math.max(0, supplied - 1)

		return {
			tokens = tokens,
			command = args ~= nil and commandWord or nil,
			word = word,
			glued = glued,
			args = type(args) == "table" and args or {},
			hasArgs = hasArgs,
			trailingSpace = trailingSpace,
			activeIndex = completed + 1,
			argMode = hasArgs and (trailingSpace or #tokens >= 2),
		}
	end

	function Session:clearHintChips(channel)
		for _, connection in self.hintConnections[channel] or {} do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		self.hintConnections[channel] = {}

		local row = hintRowFor(self, channel)
		if typeof(row) == "Instance" then
			for _, child in row:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
		end
		self.channelChips[channel] = {}
		self.hintKey[channel] = nil
	end

	function Session:hideHints(channel)
		local channels = channel and { channel } or { 1, 2 }
		for _, target in channels do
			local chips = self.channelChips[target]
			if chips and #chips > 0 then
				self.hintToken = (self.hintToken or 0) + 1
				local token = self.hintToken
				for _, chip in chips do
					imports.Hint.text(self, chip.name, 1)
					imports.Hint.text(self, chip.box, 1)
				end
				self.hintKey[target] = nil
				task.delay(self.config.motion.exitFadeTime, function()
					if self.refs and self.hintToken == token then
						self:clearHintChips(target)
					end
				end)
			end
		end
	end

	function Session:styleChips(channel)
		local colors = self.config.color
		local chips = self.channelChips[channel] or {}
		local active = self.activeChip
		for index, chip in chips do
			local isActive = active ~= nil and active.channel == channel and active.index == index
			local valid = argValid(chip.arg, chip.box.Text)
			chip.name.TextColor3 = isActive and colors.inputText or colors.mutedText
			chip.box.TextColor3 = valid and colors.inputText or colors.errorText
		end
	end

	function Session:renderHints(channel, args)
		self:clearHintChips(channel)

		local row = hintRowFor(self, channel)
		if typeof(row) ~= "Instance" then
			return
		end

		local config = self.config
		local panel = config.panel
		local layout = config.layout
		local colors = config.color
		local chips = {}
		self.channelChips[channel] = chips
		self.hintConnections[channel] = self.hintConnections[channel] or {}

		local rowLayout = row:FindFirstChildOfClass("UIListLayout")
		if rowLayout then
			rowLayout.Padding = UDim.new(0, hintGap(config))
		end

		local function track(connection)
			table.insert(self.hintConnections[channel], connection)
		end

		local function focusOnInput(input, index)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			self:focusChip(channel, index)
		end

		for index, arg in args do
			local name, typeName = argLabel(arg, index)
			local frame = imports.View.make("Frame", {
				Name = "Hint_" .. tostring(index),
				LayoutOrder = index,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, panel.hintHeight or 20),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = row.ZIndex,
			}, row)
			imports.View.make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, hintGap(config)),
			}, frame)

			local nameLabel = imports.View.make("TextLabel", {
				Name = "Name",
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, panel.hintHeight or 20),
				BackgroundTransparency = 1,
				Font = config.font.mono,
				Text = name .. ":",
				TextColor3 = colors.mutedText,
				TextTransparency = 1,
				TextSize = layout.hintTextSize or 13,
				TextYAlignment = Enum.TextYAlignment.Center,
				Active = true,
				ZIndex = row.ZIndex + 1,
			}, frame)

			local box = imports.View.make("TextBox", {
				Name = "Value",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.fromOffset(6, panel.hintHeight or 20),
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				Font = config.font.mono,
				MultiLine = false,
				PlaceholderText = typeName,
				PlaceholderColor3 = colors.hintGhost or colors.mutedText,
				Text = "",
				TextColor3 = colors.inputText,
				TextTransparency = 1,
				TextSize = layout.hintTextSize or 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = row.ZIndex + 1,
			}, frame)

			local function fitValue()
				local source = box.Text ~= "" and box.Text or typeName
				box.Size = UDim2.fromOffset(math.max(2, valueWidth(config, source)), panel.hintHeight or 20)
				self:queueVisibleWidthRefresh()
			end
			fitValue()

			track(box.Focused:Connect(function()
				self.activeChannel = channel
				self:ensureStructured(channel)
				self.activeChip = { channel = channel, index = index, arg = arg, box = box }
				self:styleChips(channel)
				fitValue()
				self:updateSuggestions(box.Text)
			end))
			track(box:GetPropertyChangedSignal("Text"):Connect(function()
				if string.find(box.Text, "\t", 1, true) then
					box.Text = (string.gsub(box.Text, "\t", ""))
					return
				end
				if fixedTokenArg(arg) and string.find(box.Text, "%s$") then
					box.Text = imports.Text.trim(box.Text)
					if index < #self.channelChips[channel] then
						task.defer(function()
							self:focusChip(channel, index + 1)
						end)
					end
					return
				end
				fitValue()
				self:styleChips(channel)
				if self.activeChip and self.activeChip.box == box then
					self:updateSuggestions(box.Text)
				end
			end))
			track(box.FocusLost:Connect(function(enterPressed)
				if not enterPressed then
					return
				end
				if index < #self.channelChips[channel] then
					self:focusChip(channel, index + 1)
				else
					self:submit(channel)
				end
			end))
			track(frame.InputBegan:Connect(function(input)
				focusOnInput(input, index)
			end))
			track(nameLabel.InputBegan:Connect(function(input)
				focusOnInput(input, index)
			end))

			table.insert(chips, { frame = frame, name = nameLabel, box = box, arg = arg })
		end
	end

	function Session:focusedChip()
		for channel, chips in self.channelChips or {} do
			for index, chip in chips do
				if typeof(chip.box) == "Instance" and chip.box:IsFocused() then
					self.activeChannel = channel
					self.activeChip = { channel = channel, index = index, arg = chip.arg, box = chip.box }
					return self.activeChip
				end
			end
		end

		local active = self.activeChip
		if active and typeof(active.box) == "Instance" and active.box.Parent then
			return active
		end

		return nil
	end

	function Session:revealHints(channel)
		for _, chip in self.channelChips[channel] or {} do
			imports.Hint.text(self, chip.name, 0)
			imports.Hint.text(self, chip.box, 0)
		end
	end

	function Session:showHints(channel, ctx)
		local row = hintRowFor(self, channel)
		local offset = textOffset(self, channel)
		if self.hintKey[channel] ~= ctx.command or #(self.channelChips[channel] or {}) ~= #ctx.args then
			self.hintToken = (self.hintToken or 0) + 1
			local hadChips = #(self.channelChips[channel] or {}) > 0
			self:renderHints(channel, ctx.args)
			self.hintKey[channel] = ctx.command
			if hadChips then
				imports.Hint.move(self, row, offset)
			else
				imports.Hint.snap(self, row, offset)
			end
			self:revealHints(channel)
		else
			imports.Hint.move(self, row, offset)
		end
		self:styleChips(channel)
	end

	function Session:focusChip(channel, index)
		local chips = self.channelChips[channel]
		if not chips or #chips == 0 then
			return
		end

		index = math.clamp(index, 1, #chips)
		local chip = chips[index]
		self.activeChannel = channel
		self.activeChip = { channel = channel, index = index, arg = chip.arg, box = chip.box }
		self:styleChips(channel)
		if typeof(chip.box) == "Instance" then
			chip.box:CaptureFocus()
			chip.box.CursorPosition = #chip.box.Text + 1
		end
		self:updateSuggestions(chip.box.Text)
	end

	function Session:moveArgument(delta)
		if not self.structured[self.activeChannel] then
			return false
		end

		local channel = self.activeChannel
		local chips = self.channelChips[channel]
		if not chips or #chips == 0 then
			return false
		end

		local active = self.activeChip
		if active and active.channel == channel and typeof(active.box) == "Instance" then
			local text = tostring(active.box.Text or "")
			local cursor = active.box.CursorPosition
			if delta < 0 and cursor > 1 then
				return false
			end
			if delta > 0 and cursor <= #text then
				return false
			end

			if delta < 0 and active.index <= 1 then
				local input = mainInputFor(self, channel)
				if typeof(input) == "Instance" then
					self.activeChip = nil
					self:styleChips(channel)
					input:CaptureFocus()
					input.CursorPosition = #input.Text + 1
					return true
				end
			end

			local nextIndex = active.index + delta
			if nextIndex >= 1 and nextIndex <= #chips then
				self:focusChip(channel, nextIndex)
				return true
			end

			return false
		end

		if delta > 0 then
			local input = mainInputFor(self, channel)
			if typeof(input) ~= "Instance" or input.CursorPosition > #input.Text then
				self:focusChip(channel, 1)
				return true
			end
		end

		return false
	end

	function Session:ensureStructured(channel)
		if self.structured[channel] then
			return
		end
		local command = self.hintKey[channel]
		if not command then
			return
		end

		self.structured[channel] = true
		self.commandWord[channel] = command
		local input = mainInputFor(self, channel)
		if typeof(input) == "Instance" then
			local word = imports.Arguments.tokenize(input.Text)[1] or command
			if input.Text ~= word then
				input.Text = word
				input.CursorPosition = #word + 1
			end
		end
	end

	function Session:enterStructured(channel, ctx)
		local input = mainInputFor(self, channel)
		self.structured[channel] = true
		self.commandWord[channel] = ctx.command

		local display = ctx.word
		if typeof(input) == "Instance" and input.Text ~= display then
			input.Text = display
			input.CursorPosition = #display + 1
		end

		self:showHints(channel, ctx)

		if typeof(input) == "Instance" then
			imports.Hint.tint(self, input, self.config.color.mutedText)
		end

		if ctx.glued and ctx.glued ~= "" then
			local chip = (self.channelChips[channel] or {})[ctx.activeIndex]
			if chip and typeof(chip.box) == "Instance" and chip.box.Text == "" then
				chip.box.Text = ctx.glued
			end
		end

		self:focusChip(channel, ctx.activeIndex)
	end

	function Session:releaseActiveChip(channel)
		if self.activeChip and self.activeChip.channel == channel then
			self.activeChip = nil
			self:styleChips(channel)
		end
	end

	function Session:exitStructured(channel)
		self.structured[channel] = false
		self.commandWord[channel] = nil
		self:releaseActiveChip(channel)
		self:hideHints(channel)
		self:queueVisibleWidthRefresh()

		local input = mainInputFor(self, channel)
		if typeof(input) == "Instance" then
			imports.Hint.tint(self, input, self.config.color.inputText)
		end
	end

	function Session:assembleCommand(channel)
		local input = mainInputFor(self, channel)
		if not self.structured[channel] then
			return typeof(input) == "Instance" and tostring(input.Text or "") or ""
		end

		local parts = { self.commandWord[channel] or "" }
		for _, chip in self.channelChips[channel] or {} do
			local value = imports.Text.trim(chip.box.Text)
			if value ~= "" then
				table.insert(parts, quoteIfNeeded(value))
			end
		end

		return table.concat(parts, " ")
	end

	function Session:markCommandValidity(channel, text)
		local input = mainInputFor(self, channel)
		if typeof(input) ~= "Instance" then
			return
		end

		local word = string.lower(imports.Arguments.tokenize(text)[1] or "")
		local known = word == ""
		for name in (type(self.argSchemas) == "table" and self.argSchemas or {}) do
			if string.sub(name, 1, #word) == word then
				known = true
				break
			end
		end

		imports.Hint.tint(self, input, known and self.config.color.inputText or self.config.color.errorText)
	end

	function Session:onCommandText(channel, text)
		if not self.isExpanded then
			return
		end

		if self.structured[channel] then
			if string.lower(imports.Text.trim(text)) == (self.commandWord[channel] or "") then
				return
			end
			self:exitStructured(channel)
		end

		local ctx = self:commandContext(text)
		if ctx.hasArgs then
			self:showHints(channel, ctx)
			if ctx.argMode then
				self:enterStructured(channel, ctx)
				return
			end
		else
			self:hideHints(channel)
		end

		self:markCommandValidity(channel, text)
		self:updateSuggestions(text)
	end
end

return Hints
