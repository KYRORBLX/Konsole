--[[
	@name hints
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local Imports = {
	UserInputService = game:GetService("UserInputService"),
	TextService = game:GetService("TextService"),
	Players = game:GetService("Players"),

	Arguments = require("../../../shared/kommand/arguments"),
	Hint = require("../../motion/suggest/hint"),

	Text = require("../misc/text"),
	View = require("../misc/view"),
}

local Types = require("../../../../types/uiTypes")

type Chip = Types.HintChip
type ActiveChip = Types.ActiveHintChip

--// locals
local function hintRowFor(self, channel): Frame?
	local row = channel == 2 and self.refs.SecondHintRow or self.refs.HintRow

	if typeof(row) == "Instance" and row:IsA("Frame") then
		return row
	end

	return nil
end

local function mainInputFor(self, channel): TextBox?
	local input = channel == 2 and self.refs.SecondInputBox or self.refs.InputBox

	if typeof(input) == "Instance" and input:IsA("TextBox") then
		return input
	end

	return nil
end

local function measureWidth(config, text)
	local size =
		Imports.TextService:GetTextSize(text, config.layout.textSize, config.font.mono, Vector2.new(100000, 100000))

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

	local full = Imports.TextService:GetTextSize(text .. ".", size, font, Vector2.new(100000, 100000)).X
	local dot = Imports.TextService:GetTextSize(".", size, font, Vector2.new(100000, 100000)).X

	return full - dot
end

local function textOffset(self, channel)
	local input = mainInputFor(self, channel)
	local config = self.config

	local text = input and tostring(input.Text or "") or ""
	text = (string.gsub(text, "%s+$", ""))

	local gap = hintGap(config)
	if text == "" then
		return gap
	end

	return measureWidth(config, text) + gap
end

local function argLabel(arg, index)
	local name = tostring(arg.name or ("arg" .. index))
	-- array args get their brackets drawn as separate labels around the box, so the
	-- placeholder itself must stay bracket-free or it renders nested as "[ [] ]"
	local typeName = string.lower(tostring(arg.type or "string"))
	local optional = arg.required == false or arg.default ~= nil

	return optional and (name .. "?") or name, typeName
end

local function quoteIfNeeded(value)
	local text = Imports.Text.trim(value)

	if text ~= "" and string.find(text, "%s") then
		return string.format("%q", text)
	end

	return text
end

local function fixedTokenArg(arg)
	if arg.array == true then
		return false
	end

	local typeName = string.lower(tostring(arg.type or "string"))
	return typeName == "number" or typeName == "boolean"
end

local function playersListArg(arg)
	local typeName = string.lower(tostring(arg.type or "string"))
	return typeName == "players" or arg.array == true
end

local isCollectiveKeyword = Imports.Arguments.isCollectiveKeyword

-- text after the last confirmed comma, i.e. the name currently being typed
local function tailSegment(text)
	local lastComma = nil

	for position in string.gmatch(text, "()%,") do
		lastComma = position
	end

	local tail = lastComma and string.sub(text, lastComma + 1) or text
	return string.match(tail, "^%s*(.-)%s*$") or tail
end

-- entries already confirmed before the segment currently being typed
local function confirmedEntries(text)
	local inner = string.gsub(text, "^%[", "")
	local lastComma = nil

	for position in string.gmatch(inner, "()%,") do
		lastComma = position
	end

	if not lastComma then
		return {}
	end

	local entries = {}
	for entry in string.gmatch(string.sub(inner, 1, lastComma - 1), "[^,]+") do
		local trimmed = string.match(entry, "^%s*(.-)%s*$") or entry
		if trimmed ~= "" then
			table.insert(entries, string.lower(trimmed))
		end
	end

	return entries
end

local function argValid(arg, text)
	text = Imports.Text.trim(text)
	if text == "" then
		return true
	end

	local typeName = string.lower(tostring(arg.type or "string"))

	if arg.array then
		local ok = Imports.Arguments.parseArray("[" .. text .. "]", typeName, Imports.Players.LocalPlayer)
		return ok == true
	end

	local convert = Imports.Arguments.types[typeName]

	if type(convert) ~= "function" then
		return true
	end

	if playersListArg(arg) then
		text = "[" .. text .. "]"
	end

	local ok = convert(text, Imports.Players.LocalPlayer)

	return ok == true
end

--// public api
local Hints = {}

function Hints.attach(Session)
	function Session:setSchemas(map)
		self.argSchemas = type(map) == "table" and map or {}
	end

	-- all/others can only ever be the sole entry in a players list; plain duplicates are allowed
	function Session:playersEntryAllowed(existingText, entry)
		local confirmed = confirmedEntries(existingText)
		local collective = isCollectiveKeyword(entry)

		if collective then
			return #confirmed == 0
		end

		for _, existing in confirmed do
			if isCollectiveKeyword(existing) then
				return false
			end
		end

		return true
	end

	function Session:commandContext(text)
		local schemas = type(self.argSchemas) == "table" and self.argSchemas or {}
		local tokens = Imports.Arguments.tokenize(text)

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

		local trailingSpace = string.match(text, "%s$") ~= nil
		local hasArgs = type(args) == "table" and #args > 0

		local supplied = math.max(0, #tokens - 1)
		local completed = trailingSpace and supplied or math.max(0, supplied - 1)

		return {
			trailingSpace = trailingSpace,
			hasArgs = hasArgs,
			tokens = tokens,

			activeIndex = completed + 1,

			argMode = hasArgs and (glued ~= nil or trailingSpace or #tokens >= 2),
			command = args ~= nil and commandWord or nil,

			glued = glued,
			word = word,
			args = type(args) == "table" and args or {},
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

		if row then
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
					Imports.Hint.text(self, chip.name, 1)

					Imports.Hint.text(self, chip.box, 1)

					if chip.bracketOpen then
						Imports.Hint.text(self, chip.bracketOpen, 1)
						Imports.Hint.text(self, chip.bracketClose, 1)
					end
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

		local chips = (self.channelChips[channel] or {}) :: { Chip }
		local active = self.activeChip :: ActiveChip?

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
		if not row then
			return
		end

		local config = self.config

		local layout = config.layout
		local colors = config.color
		local panel = config.panel

		local chips: { Chip } = {}

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

			-- number/boolean array args can name each position (e.g. "gridX, gridY")
			-- instead of showing the bare type as a placeholder
			local labelList = (arg.array == true and type(arg.labels) == "table" and #arg.labels > 0)
				and arg.labels
				or nil

			if labelList then
				typeName = table.concat(labelList, ", ")
			end

			local frame = Imports.View.make("Frame", {

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = true,

				LayoutOrder = index,
				ZIndex = row.ZIndex,

				Name = "Hint_" .. tostring(index),

				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, panel.hintHeight or 20),
			}, row) :: Frame

			Imports.View.make("UIListLayout", {

				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,

				Padding = UDim.new(0, hintGap(config)),
			}, frame)

			local nameLabel = Imports.View.make("TextLabel", {

				BackgroundTransparency = 1,
				TextTransparency = 1,
				LayoutOrder = 1,

				TextColor3 = colors.mutedText,
				Font = config.font.mono,

				TextSize = layout.hintTextSize or 13,
				ZIndex = row.ZIndex + 1,
				Active = true,

				Text = name .. ":",
				Name = "Name",

				AutomaticSize = Enum.AutomaticSize.X,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.fromOffset(0, panel.hintHeight or 20),
			}, frame) :: TextLabel

			local isPlayersList = playersListArg(arg)

			local function bracketLabel(text, order)
				return Imports.View.make("TextLabel", {

					BackgroundTransparency = 1,
					TextTransparency = 1,
					LayoutOrder = order,

					TextColor3 = colors.mutedText,
					Font = config.font.mono,

					TextSize = layout.hintTextSize or 13,
					ZIndex = row.ZIndex + 1,
					Active = true,

					Text = text,
					Name = "Bracket",

					AutomaticSize = Enum.AutomaticSize.X,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.fromOffset(0, panel.hintHeight or 20),
				}, frame) :: TextLabel
			end

			local bracketOpen = isPlayersList and bracketLabel("[", 2) or nil
			local bracketClose

			-- the box and its ghost continuation are manually positioned inside this
			-- group instead of relying on UIListLayout spacing, so the ghost sits
			-- immediately at the cursor with zero gap instead of a full item-padding gap
			local valueGroup = Imports.View.make("Frame", {

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = isPlayersList and 3 or 2,

				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, panel.hintHeight or 20),
			}, frame) :: Frame

			local box = Imports.View.make("TextBox", {

				PlaceholderColor3 = colors.hintGhost or colors.mutedText,

				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				TextTransparency = 1,

				TextColor3 = colors.inputText,
				Font = config.font.mono,

				TextSize = layout.hintTextSize or 13,
				ZIndex = row.ZIndex + 1,

				MultiLine = false,

				PlaceholderText = typeName,
				Name = "Value",
				Text = "",
				Position = UDim2.fromOffset(0, 0),

				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.fromOffset(6, panel.hintHeight or 20),
			}, valueGroup) :: TextBox

			-- labels not yet reached (no comma typed for them yet) stay visible as a
			-- ghost continuation right after the box, so they don't just vanish once
			-- the user starts typing the first entry
			local remainingLabel = nil :: TextLabel?

			if labelList then
				remainingLabel = Imports.View.make("TextLabel", {

					BackgroundTransparency = 1,
					TextTransparency = 1,

					TextColor3 = colors.hintGhost or colors.mutedText,
					Font = config.font.mono,

					TextSize = layout.hintTextSize or 13,
					ZIndex = row.ZIndex + 1,
					Active = true,

					Text = "",
					Name = "Remaining",
					Position = UDim2.fromOffset(0, 0),

					AutomaticSize = Enum.AutomaticSize.X,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.fromOffset(0, panel.hintHeight or 20),
				}, valueGroup) :: TextLabel
			end

			if isPlayersList then
				bracketClose = bracketLabel("]", 5)
			end

			-- only the label for the slot currently being typed shows, and only until
			-- that slot has a character in it -- not the whole remaining list at once
			local function remainingLabelsText(text)
				if not labelList or tailSegment(text) ~= "" then
					return ""
				end

				local currentIndex = 1
				for _ in string.gmatch(text, ",") do
					currentIndex += 1
				end

				return labelList[currentIndex] or ""
			end

			local function fitValue()
				local source = box.Text ~= "" and box.Text or typeName
				local boxWidth = math.max(2, valueWidth(config, source))

				box.Size = UDim2.fromOffset(boxWidth, panel.hintHeight or 20)

				if remainingLabel then
					remainingLabel.Text = box.Text ~= "" and remainingLabelsText(box.Text) or ""
					remainingLabel.Position = UDim2.fromOffset(boxWidth, 0)
				end

				self:queueVisibleWidthRefresh(channel)
			end

			local previousText = box.Text

			fitValue()

			track(box.Focused:Connect(function()
				self.activeChannel = channel

				self:ensureStructured(channel)

				self.activeChip = { channel = channel, index = index, arg = arg, box = box }
				self:styleChips(channel)

				fitValue()

				self:updateSuggestions(isPlayersList and tailSegment(box.Text) or box.Text)
			end))

			track(box:GetPropertyChangedSignal("Text"):Connect(function()
				local currentText = box.Text
				local grew = #currentText > #previousText

				if
					previousText ~= ""
					and currentText == ""
					and Imports.UserInputService:IsKeyDown(Enum.KeyCode.Backspace)
				then
					self.clearedArgument = box
				elseif currentText ~= "" and self.clearedArgument == box then
					self.clearedArgument = nil
				end

				previousText = currentText

				if string.find(box.Text, "\t", 1, true) then
					box.Text = (string.gsub(box.Text, "\t", ""))
					return
				end

				if fixedTokenArg(arg) and string.find(box.Text, "%s$") then
					box.Text = Imports.Text.trim(box.Text)

					if index < #self.channelChips[channel] then
						task.defer(function()
							self:focusChip(channel, index + 1)
						end)
					end

					return
				end

				if playersListArg(arg) then
					local text = box.Text
					local lastChar = string.sub(text, -1)

					-- only a single space is allowed, and only right after a
					-- confirmed comma -- no leading space, no runs of spaces
					if grew and lastChar == " " then
						local prevChar = string.sub(text, -2, -2)
						if prevChar ~= "," then
							box.Text = string.sub(text, 1, -2)
							return
						end
					end

					if grew and (lastChar == "," or lastChar == "]") then
						local body = string.sub(text, 1, -2)
						local segment = tailSegment(body)

						local typeName = string.lower(tostring(arg.type or "string"))
						local isPlayerType = typeName == "players" or typeName == "player"

						local ok = segment ~= ""
						local collective = ok and isPlayerType and isCollectiveKeyword(segment)

						if ok then
							if collective then
								ok = Imports.Arguments.types.players(segment, Imports.Players.LocalPlayer) == true
							elseif isPlayerType then
								ok = Imports.Arguments.types.player(segment, Imports.Players.LocalPlayer) == true
							else
								local convert = Imports.Arguments.types[typeName]
								ok = type(convert) ~= "function" or convert(segment, Imports.Players.LocalPlayer) == true
							end
						end

						if ok and isPlayerType then
							ok = self:playersEntryAllowed(body, segment)
						end

						if not ok then
							box.Text = body
							return
						end

						if lastChar == "," then
							box.Text = body .. ", "
							return
						end

						-- valid "]" close: bracket is drawn statically, don't store it
						box.Text = body

						if index < #self.channelChips[channel] then
							task.defer(function()
								self:focusChip(channel, index + 1)
							end)
						end
					end

					fitValue()
					self:styleChips(channel)

					if self.activeChip and self.activeChip.box == box then
						self:updateSuggestions(tailSegment(box.Text))
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

			table.insert(chips, {
				name = nameLabel,
				frame = frame,
				box = box,
				arg = arg,
				bracketOpen = bracketOpen,
				bracketClose = bracketClose,
				remaining = remainingLabel,
			})
		end
	end

	function Session:focusedChip()
		for channel, rawChips in self.channelChips or {} do
			for index, chip in rawChips :: { Chip } do
				if chip.box:IsFocused() then
					self.activeChannel = channel
					self.activeChip = { channel = channel, index = index, arg = chip.arg, box = chip.box }

					return self.activeChip
				end
			end
		end

		local active = self.activeChip :: ActiveChip?

		if active and active.box.Parent then
			return active
		end

		return nil
	end

	function Session:revealHints(channel)
		for _, chip in (self.channelChips[channel] or {}) :: { Chip } do
			Imports.Hint.text(self, chip.name, 0)
			Imports.Hint.text(self, chip.box, 0)

			if chip.bracketOpen then
				Imports.Hint.text(self, chip.bracketOpen, 0)
				Imports.Hint.text(self, chip.bracketClose, 0)
			end

			if chip.remaining then
				Imports.Hint.text(self, chip.remaining, 0)
			end
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
				Imports.Hint.move(self, row, offset)
			else
				Imports.Hint.snap(self, row, offset)
			end

			self:revealHints(channel)
		else
			Imports.Hint.move(self, row, offset)
		end

		self:styleChips(channel)
	end

	function Session:focusChip(channel, index)
		local chips = self.channelChips[channel] :: { Chip }?
		if not chips or #chips == 0 then
			return
		end

		index = math.clamp(index, 1, #chips)

		local chip = chips[index]
		local box = chip.box

		self.activeChannel = channel
		self.activeChip = { channel = channel, index = index, arg = chip.arg, box = box }

		self:styleChips(channel)

		local function capture()
			local active = self.activeChip
			if
				self.isDestroying
				or not active
				or active.channel ~= channel
				or active.index ~= index
				or active.box ~= box
				or not box.Parent
			then
				return
			end

			if not box:IsFocused() then
				box:CaptureFocus()
			end

			box.CursorPosition = #box.Text + 1
		end

		capture()
		task.defer(capture)

		self:updateSuggestions(box.Text)
	end

	function Session:moveArgument(delta, force)
		if not self.structured[self.activeChannel] then
			return false
		end

		local channel = self.activeChannel
		local chips = self.channelChips[channel] :: { Chip }?

		if not chips or #chips == 0 then
			return false
		end

		local active = self.activeChip :: ActiveChip?
		if active and active.channel == channel then
			local text = tostring(active.box.Text or "")
			local cursor = active.box.CursorPosition

			if not force and delta < 0 and cursor > 1 then
				return false
			end

			if not force and delta > 0 and cursor <= #text then
				return false
			end

			if delta < 0 and active.index <= 1 then
				local input = mainInputFor(self, channel)

				if input then
					self.activeChip = nil

					self:styleChips(channel)
					self:hideSuggestions()

					input:CaptureFocus()

					input.CursorPosition = #input.Text + 1

					task.defer(function()
						if self.isDestroying or not input.Parent or not input:IsFocused() or self.activeChip ~= nil then
							return
						end

						self:updateSuggestions(input.Text)
					end)

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

			if not input or force or input.CursorPosition > #input.Text then
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

		if input then
			local word = Imports.Arguments.tokenize(input.Text)[1] or command

			if input.Text ~= word then
				input.Text = word
				input.CursorPosition = #word + 1
			end
		end
	end

	function Session:enterStructured(channel, ctx)
		local input = mainInputFor(self, channel)

		self.commandWord[channel] = ctx.command

		self.structured[channel] = true

		local display = ctx.word

		if input and input.Text ~= display then
			input.Text = display

			input.CursorPosition = #display + 1
		end

		self:showHints(channel, ctx)

		if input then
			Imports.Hint.tint(self, input, self.config.color.mutedText)
		end

		local chips = (self.channelChips[channel] or {}) :: { Chip }

		local function seed(chip, token)
			if playersListArg(chip.arg) then
				token = string.gsub(string.gsub(token, "^%[", ""), "%]$", "")
			end

			chip.box.Text = token
		end

		if ctx.glued and ctx.glued ~= "" then
			local chip = chips[ctx.activeIndex]

			if chip and chip.box.Text == "" then
				seed(chip, ctx.glued)
			end
		else
			for tokenIndex = 2, #ctx.tokens do
				local chip = chips[tokenIndex - 1]

				if chip and chip.box.Text == "" then
					seed(chip, ctx.tokens[tokenIndex])
				end
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

		self:queueVisibleWidthRefresh(channel)

		self:releaseActiveChip(channel)
		self:hideHints(channel)

		local input = mainInputFor(self, channel)

		if input then
			Imports.Hint.tint(self, input, self.config.color.inputText)
		end
	end

	function Session:assembleCommand(channel)
		local input = mainInputFor(self, channel)

		if not self.structured[channel] then
			return input and tostring(input.Text or "") or ""
		end

		local parts = { self.commandWord[channel] or "" }

		for _, chip in (self.channelChips[channel] or {}) :: { Chip } do
			local value = Imports.Text.trim(chip.box.Text)

			if value ~= "" then
				if playersListArg(chip.arg) then
					value = "[" .. value .. "]"
				end

				table.insert(parts, quoteIfNeeded(value))
			end
		end

		return table.concat(parts, " ")
	end

	function Session:markCommandValidity(channel, text)
		local input = mainInputFor(self, channel)

		if not input then
			return
		end

		local word = string.lower(Imports.Arguments.tokenize(text)[1] or "")
		local known = word == ""

		for name in (type(self.argSchemas) == "table" and self.argSchemas or {}) do
			if string.sub(name, 1, #word) == word then
				known = true
				break
			end
		end

		Imports.Hint.tint(self, input, known and self.config.color.inputText or self.config.color.errorText)
	end

	function Session:onCommandText(channel, text)
		if not self.isExpanded then
			return
		end

		if self.structured[channel] then
			if string.lower(Imports.Text.trim(text)) == (self.commandWord[channel] or "") then
				if string.match(text, "%s$") then
					local input = mainInputFor(self, channel)

					if input then
						local display = Imports.Text.trim(text)

						input.Text = display
						input.CursorPosition = #display + 1
					end

					self:focusChip(channel, 1)
				end

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
