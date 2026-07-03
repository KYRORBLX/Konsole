--[[
	@name suggestions
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

local imports = {
	Providers = require("./providers"),
	Suggest = require("../../motion/suggest"),
	Text = require("../misc/text"),
	View = require("../misc/view"),
}

local Suggestions = {}

local function startsWith(value, prefix)
	return string.sub(value, 1, #prefix) == prefix
end

local function contains(value, needle)
	return string.find(value, needle, 1, true) ~= nil
end

local function rankSuggestion(query, suggestion)
	local lower = string.lower(tostring(suggestion or ""))
	local firstWord = string.match(lower, "^(%S+)") or lower
	local score = 0

	if lower == query then
		score = 1200
	elseif firstWord == query then
		score = 1100
	elseif startsWith(firstWord, query) then
		score = 1000
	elseif startsWith(lower, query) then
		score = 900
	elseif contains(firstWord, query) then
		score = 650
	elseif contains(lower, query) then
		score = 420
	else
		local fuzzy = imports.Text.fuzzyScore(query, lower)
		if fuzzy <= 0 then
			return 0
		end
		score = fuzzy
	end

	if string.find(lower, " ", 1, true) then
		score -= 80
	end

	return score - math.min(#lower, 80) * 0.2
end

local function compareRanked(a, b)
	if a.score ~= b.score then
		return a.score > b.score
	end
	if #a.text ~= #b.text then
		return #a.text < #b.text
	end

	return string.lower(a.text) < string.lower(b.text)
end

local function rankList(source, query)
	query = string.lower(tostring(query or ""))
	local seen = {}
	local ranked = {}
	for _, item in source or {} do
		local itemText = tostring(item)
		local key = string.lower(itemText)
		if itemText ~= "" and not seen[key] then
			seen[key] = true
			local score = query == "" and (1000 - math.min(#key, 80) * 0.2) or rankSuggestion(query, itemText)
			if score > 0 then
				table.insert(ranked, { text = itemText, score = score })
			end
		end
	end
	table.sort(ranked, compareRanked)

	local matches = {}
	for _, item in ranked do
		table.insert(matches, item.text)
	end

	return matches
end

function Suggestions.attach(Session)
	function Session:refreshMeasured(channel)
		self.refreshMeasuredToken[channel] = (self.refreshMeasuredToken[channel] or 0) + 1
		local token = self.refreshMeasuredToken[channel]
		task.delay(0.04, function()
			if self.refs and self.refreshMeasuredToken[channel] == token then
				self:queueWidthRefresh()
			end
		end)
	end

	function Session:suggestionsFor(text)
		text = string.lower(imports.Text.cleanStart(text))
		if text == "" then
			return {}
		end

		return rankList(self.suggestionSource, text)
	end

	function Session:resolveSuggestions(text)
		local chip = self.activeChip
		if chip and type(chip.arg) == "table" then
			return rankList(imports.Providers.resolve(chip.arg), text), text
		end

		return self:suggestionsFor(text), string.lower(imports.Text.cleanStart(text))
	end

	function Session:hideSuggestions()
		local suggList = self.refs.suggList
		if typeof(suggList) ~= "Instance" then
			return
		end

		imports.View.clearSuggestionConnections(self)
		if not suggList.Visible and #self.currentSuggestions == 0 then
			self.suggestionsHiding = false
			if typeof(self.refs.suggShadow) == "Instance" then
				self.refs.suggShadow.Visible = false
				self.refs.suggShadow.ImageTransparency = 1
			end
			return
		end

		self.currentSuggestions = {}
		self.selectedSuggestion = nil
		self.suggestToken += 1
		self.suggestionsHiding = true
		imports.Suggest.hide(self)
	end

	function Session:syncSelection()
		local suggList = self.refs.suggList
		if typeof(suggList) ~= "Instance" then
			return
		end

		local config = self.config
		for _, child in suggList:GetChildren() do
			if not child:IsA("TextButton") then
				continue
			end

			local index = tonumber(string.match(child.Name, "^Sugg_(%d+)$")) or 0
			local selected = self.selectedSuggestion == index
			local label = child:FindFirstChild("Label")
			if typeof(label) == "Instance" then
				label.Font = selected and config.font.title or config.font.body
				local suggestion = child:GetAttribute("SuggestionText")
				if type(suggestion) == "string" then
					local richText = imports.View.richSuggestion(suggestion, self.suggestionQuery, config)
					label.Text = selected and ("<b>" .. richText .. "</b>") or richText
				end
			end
			child.BackgroundColor3 = config.color.suggPanel
			child.BackgroundTransparency = selected and 0.72 or 1
		end
	end

	function Session:moveSelection(delta)
		local count = #self.currentSuggestions
		if count == 0 then
			return false
		end

		local current = self.selectedSuggestion or 1
		self.selectedSuggestion = ((current - 1 + delta) % count) + 1
		self:syncSelection()
		return true
	end

	function Session:updateSuggestions(text)
		if not self.isExpanded then
			return
		end

		local config = self.config
		local panel = config.panel
		local suggList = self.refs.suggList
		if typeof(suggList) ~= "Instance" then
			return
		end

		local list, query = self:resolveSuggestions(text)
		local count = math.min(#list, panel.maxSuggestions or 5)
		if count == 0 then
			self:hideSuggestions()
			return
		end

		self.suggestionsHiding = false
		self.suggestToken += 1
		self.currentSuggestions = {}
		self.selectedSuggestion = 1
		self.suggestionQuery = query
		imports.View.clearSuggestionConnections(self)
		for index = 1, count do
			table.insert(self.currentSuggestions, list[index])
		end
		for _, child in suggList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for index = 1, count do
			local suggestion = list[index]
			local button = imports.View.make("TextButton", {
				Name = "Sugg_" .. tostring(index),
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, panel.suggestionHeight),
				BackgroundTransparency = 1,
				BackgroundColor3 = config.color.suggPanel,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 32,
			}, suggList)
			imports.View.corner(button, panel.suggestionRadius or 10)
			button:SetAttribute("SuggestionText", suggestion)

			local label = imports.View.make("TextLabel", {
				Name = "Label",
				Size = UDim2.new(1, -(config.layout.paddingX * 2), 1, -2),
				Position = UDim2.new(0, config.layout.paddingX, 0, 1 + (config.motion.textSlideOffset or 10)),
				BackgroundTransparency = 1,
				Font = config.font.body,
				RichText = true,
				Text = imports.View.richSuggestion(suggestion, query, config),
				TextColor3 = config.color.suggText,
				TextTransparency = 1,
				TextSize = config.layout.suggTextSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 33,
			}, button)

			table.insert(
				self.suggestionConnections,
				button.Activated:Connect(function()
					self:applySuggestion(suggestion)
				end)
			)
			table.insert(
				self.suggestionConnections,
				button.MouseEnter:Connect(function()
					self.selectedSuggestion = index
					self:syncSelection()
				end)
			)

			imports.Suggest.item(self, label)
		end

		self:syncSelection()
		imports.Suggest.reveal(self, count)
		task.defer(function()
			self:updateShadows()
		end)
	end

	function Session:applySuggestion(rawSuggestion: any)
		if type(rawSuggestion) ~= "string" then
			return false
		end
		local suggestion: string = rawSuggestion

		local chip = self.activeChip
		if chip and typeof(chip.box) == "Instance" then
			chip.box.Text = suggestion
			chip.box.CursorPosition = #suggestion + 1
			local chips = self.channelChips[chip.channel] or {}
			if chip.index < #chips then
				self:focusChip(chip.channel, chip.index + 1)
			else
				self:hideSuggestions()
				chip.box:CaptureFocus()
				chip.box.CursorPosition = #suggestion + 1
			end
			return true
		end

		local input = self:activeInput()
		if typeof(input) ~= "Instance" then
			return false
		end

		local newText = suggestion
		local schema = type(self.argSchemas) == "table" and self.argSchemas[string.lower(suggestion)]
		if type(schema) == "table" and #schema > 0 and not string.find(suggestion, " ", 1, true) then
			newText ..= " "
		end

		input.Text = newText
		input.CursorPosition = #newText + 1
		input:CaptureFocus()
		task.defer(function()
			if typeof(input) == "Instance" and input:IsFocused() then
				input.Text = newText
				input.CursorPosition = #newText + 1
			end
		end)

		return true
	end

	function Session:acceptSuggestion()
		local input = self:activeInput()
		if typeof(input) ~= "Instance" then
			return false
		end
		if self.acceptGuard then
			return true
		end
		self.acceptGuard = true
		task.defer(function()
			self.acceptGuard = false
		end)

		local suggestion = self.currentSuggestions[self.selectedSuggestion or 1]
		if not suggestion then
			suggestion = (self:resolveSuggestions(input.Text))[1]
		end
		if not suggestion then
			return false
		end

		return self:applySuggestion(suggestion)
	end
end

return Suggestions
