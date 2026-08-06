--[[
	@name suggestions
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

--// imports
local Imports = {
	Suggest = require("../../motion/suggest"),
    Providers = require("./providers"),

	Arguments = require("../../../shared/kommand/arguments"),
	Players = game:GetService("Players"),
	Text = require("../misc/text"),
	View = require("../misc/view"),
}

--// locals
local function startsWith(value, prefix)
	return string.sub(value, 1, #prefix) == prefix
end

local function contains(value, needle)
	return string.find(value, needle, 1, true) ~= nil
end

local isCollectiveKeyword = Imports.Arguments.isCollectiveKeyword

local function toHex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

-- lowercase names already confirmed before the segment currently being typed
local function confirmedPlayerNames(text)
	local lastComma = nil

	for position in string.gmatch(text, "()%,") do
		lastComma = position
	end

	if not lastComma then
		return {}
	end

	local names = {}
	for entry in string.gmatch(string.sub(text, 1, lastComma - 1), "[^,]+") do
		local trimmed = string.match(entry, "^%s*(.-)%s*$") or entry
		if trimmed ~= "" then
			names[string.lower(trimmed)] = true
		end
	end

	return names
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
		local fuzzy = Imports.Text.fuzzyScore(query, lower)
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
    
    local ranked = {}
    local seen = {}
    
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

local function placeList(session)
	local refs = session.refs
	local useSecondRoot = session.activeChannel == 2 and session.hasSecondChat and session.secondDetached
    
    local root = useSecondRoot and refs.secondRoot or refs.root
	if refs.suggList.Parent == root then
		return
	end

    refs.suggShadow.Parent = root
    refs.suggList.Parent = root
end

--// public api
local Suggestions = {}

function Suggestions.attach(Session)
	function Session:placeSuggestions()
		placeList(self)
	end

	function Session:refreshMeasured(channel)
        self.refreshMeasuredToken[channel] = (self.refreshMeasuredToken[channel] or 0) + 1
        
        local token = self.refreshMeasuredToken[channel]
        
		task.delay(0.04, function()
            if self.refs and self.refreshMeasuredToken[channel] == token then
                
				self:queueWidthRefresh(channel)
			end
		end)
	end

	function Session:suggestionsFor(text)
        text = string.lower(Imports.Text.cleanStart(text))
        
		if text == "" then
			return {}
		end

		return rankList(self.suggestionSource, text)
	end

	function Session:resolveSuggestions(text)
        local chip = if type(self.focusedChip) == "function" then self:focusedChip() else self.activeChip
        
		if chip and type(chip.arg) == "table" then
			local source = Imports.Providers.resolve(chip.arg)

			local isPlayerList = chip.arg.type == "players" or (chip.arg.type == "player" and chip.arg.array == true)
			if isPlayerList and next(confirmedPlayerNames(chip.box.Text)) then
				local filtered = {}
				for _, entry in source do
					if not isCollectiveKeyword(entry) then
						table.insert(filtered, entry)
					end
				end
				source = filtered
			end

			if text == "" then
				return source, text
			end

			local matches = rankList(source, text)

			if #matches == 0 then
				matches = source
			end

			return matches, text
		end

		local query = string.lower(Imports.Text.cleanStart(text))

		if string.find(query, "%s") then
			return {}, query
		end

		return self:suggestionsFor(query), query
	end

	function Session:hideSuggestions()
        local suggList = self.refs.suggList
        
		if typeof(suggList) ~= "Instance" or not suggList:IsA("ScrollingFrame") then
			return
		end

		Imports.View.clearSuggestionConnections(self)
		if not suggList.Visible and #self.currentSuggestions == 0 then
            self.suggestionsHiding = false
            
			if
				typeof(self.refs.suggShadow) == "Instance"
				and self.refs.suggShadow:IsA("ImageLabel")
			then
                self.refs.suggShadow.ImageTransparency = 1
                self.refs.suggShadow.Visible = false
			end
			return
		end

        self.currentSuggestions = {}
        
		self.selectedSuggestion = nil
        self.suggestionsHiding = true
        
        self.suggestToken += 1
		
		Imports.Suggest.hide(self)
	end

	function Session:syncSelection()
		local suggList = self.refs.suggList
		if typeof(suggList) ~= "Instance" or not suggList:IsA("ScrollingFrame") then
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
            
			if typeof(label) == "Instance" and label:IsA("TextLabel") then
				label.Font = selected and config.font.title or config.font.body
                local suggestion = child:GetAttribute("SuggestionText")

				if type(suggestion) == "string" then
					local richText = Imports.View.richSuggestion(suggestion, self.suggestionQuery, config)

					if child:GetAttribute("Dupe") then
						richText ..= ` <font color="{toHex(config.color.mutedText)}"><i>dupe</i></font>`
					end

					label.Text = selected and ("<b>" .. richText .. "</b>") or richText
				end
            end
            
            child.BackgroundTransparency = selected and 0.72 or 1
            child.BackgroundColor3 = config.color.suggPanel
			
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

		local suggList = self.refs.suggList
		if suggList:IsA("ScrollingFrame") then
			local rowHeight = self.config.panel.suggestionHeight
			local top = 2 + ((self.selectedSuggestion - 1) * rowHeight)

			local position = suggList.CanvasPosition.Y
			local bottom = top + rowHeight

			if top < position then
				position = top

			elseif bottom > position + suggList.AbsoluteWindowSize.Y then
				position = bottom - suggList.AbsoluteWindowSize.Y
			end

			suggList.CanvasPosition = Vector2.new(0, math.max(0, position))
		end
        
		return true
	end

	function Session:updateSuggestions(text)
		if not self.isExpanded then
			return
		end

        local suggList = self.refs.suggList
        local config = self.config
        local panel = config.panel
        
		if typeof(suggList) ~= "Instance" or not suggList:IsA("ScrollingFrame") then
			return
		end

		local chip = if type(self.focusedChip) == "function" then self:focusedChip() else self.activeChip
		local dupeNames = {}

		if chip and type(chip.arg) == "table" and chip.arg.type ~= "boolean" then
			-- dupe suggestions get flagged no matter what type/shape the argument is,
			-- except booleans -- repeating true/false isn't a meaningful duplicate
			dupeNames = confirmedPlayerNames(chip.box.Text)

			if chip.arg.type == "players" or chip.arg.type == "player" then
				-- "me" and the local player's own name refer to the same entry
				local localName = string.lower(Imports.Players.LocalPlayer.Name)
				if dupeNames["me"] or dupeNames[localName] then
					dupeNames["me"] = true
					dupeNames[localName] = true
				end
			end
		end

		local showing = suggList.Visible and not self.suggestionsHiding
		local list, query = self:resolveSuggestions(text)
		local limit = math.max(0, math.floor(tonumber(panel.maxSuggestions) or 5))
		local count = #list
		local visibleCount = math.min(count, limit)

		if visibleCount == 0 then
			self:hideSuggestions()
			return
		end

        self.suggestionQuery = query
        self.currentSuggestions = table.clone(list)
        
        self.suggestionsHiding = false

        self.selectedSuggestion = 1
        self.suggestToken += 1
        
        Imports.View.clearSuggestionConnections(self)
        self:placeSuggestions()

		suggList.CanvasPosition = Vector2.zero
		suggList.CanvasSize = UDim2.fromOffset(0, (count * panel.suggestionHeight) + 4)
        
		for _, child in suggList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		local slide = showing and 0 or (config.motion.textSlideOffset or 10)

		for index = 1, count do
			local suggestion = list[index]
			local button = Imports.View.make("TextButton", {
                LayoutOrder = index,
                
				Size = UDim2.new(1, 0, 0, panel.suggestionHeight),
                BackgroundColor3 = config.color.suggPanel,
                
                BackgroundTransparency = 1,
				BorderSizePixel = 0,
                ZIndex = 32,
                
                AutoButtonColor = false,
                
                Name = "Sugg_" .. tostring(index),
                Text = "",
            }, suggList)
            
			Imports.View.corner(button, panel.suggestionRadius or 10)
			button:SetAttribute("SuggestionText", suggestion)
			button:SetAttribute("Dupe", dupeNames[string.lower(suggestion)] == true)

			local label = Imports.View.make("TextLabel", {
                Name = "Label",
                
                Position = UDim2.new(0, config.layout.paddingX, 0, 1 + slide),
                Size = UDim2.new(1, -(config.layout.paddingX * 2), 1, -2),
                
                TextYAlignment = Enum.TextYAlignment.Center,
                TextXAlignment = Enum.TextXAlignment.Left,
                
                TextSize = config.layout.suggTextSize,
                TextColor3 = config.color.suggText,
                Font = config.font.body,
                
                BackgroundTransparency = 1,
                TextTransparency = showing and config.transparency.suggText or 1,
                ZIndex = 33,
				
                Text = Imports.View.richSuggestion(suggestion, query, config)
                    .. (dupeNames[string.lower(suggestion)]
                        and string.format(' <font color="%s"><i>dupe</i></font>', toHex(config.color.mutedText))
                        or ""),
                RichText = true,
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

			if not showing then
				Imports.Suggest.item(self, label)
			end
		end

		self:syncSelection()
        Imports.Suggest.reveal(self, visibleCount)
        
		task.defer(function()
			self:updateShadows()
		end)
	end

	function Session:applySuggestion(rawSuggestion: any)
		if type(rawSuggestion) ~= "string" then
			return false
		end
		local suggestion: string = rawSuggestion

		local chip = if type(self.focusedChip) == "function" then self:focusedChip() else self.activeChip
		if chip and typeof(chip.box) == "Instance" and chip.box:IsA("TextBox") then

			-- a preset group suggestion arrives as a full bracket literal, e.g. "[debug, godmode]";
			-- it replaces the whole field instead of appending as one more comma entry
			local presetInner = string.match(suggestion, "^%[(.*)%]$")

			if chip.arg and presetInner and chip.arg.array == true then
				chip.box.Text = presetInner
				chip.box.CursorPosition = #presetInner + 1
				chip.box:CaptureFocus()

				self:hideSuggestions()

				local chips = self.channelChips[chip.channel] or {}
				if chip.index < #chips then
					self:focusChip(chip.channel, chip.index + 1)
				end

				return true
			end

			if chip.arg and (chip.arg.type == "players" or chip.arg.array == true) then
				if not self:playersEntryAllowed(chip.box.Text, suggestion) then
					return false
				end

				local body = chip.box.Text
				local lastComma = nil

				for position in string.gmatch(body, "()%,") do
					lastComma = position
				end

				local prefix = lastComma and (string.sub(body, 1, lastComma) .. " ") or ""

				-- all/others can't be followed by more entries, so close the list instead of inviting another comma
				local newText = isCollectiveKeyword(suggestion) and (prefix .. suggestion) or (prefix .. suggestion .. ", ")

				chip.box.Text = newText
				chip.box.CursorPosition = #newText + 1
				chip.box:CaptureFocus()

				if isCollectiveKeyword(suggestion) then
					self:hideSuggestions()

					local chips = self.channelChips[chip.channel] or {}
					if chip.index < #chips then
						self:focusChip(chip.channel, chip.index + 1)
					end
				else
					self:updateSuggestions("")
				end

				return true
			end

            chip.box.CursorPosition = #suggestion + 1
            chip.box.Text = suggestion

			local chips = self.channelChips[chip.channel] or {}
            if chip.index < #chips then
				self:focusChip(chip.channel, chip.index + 1)
			else
                self:hideSuggestions()
                
                 chip.box.CursorPosition = #suggestion + 1
                 chip.box:CaptureFocus()
                
			end
			return true
		end

		local channel = self.activeChannel
		local input = self:activeInput()
		if typeof(input) ~= "Instance" or not input:IsA("TextBox") then
			return false
		end

        local newText = suggestion
        
		local schema = type(self.argSchemas) == "table" and self.argSchemas[string.lower(suggestion)]
		local hasArguments = type(schema) == "table" and #schema > 0 and not string.find(suggestion, " ", 1, true)

		if hasArguments then
			self:enterStructured(channel, self:commandContext(newText))

			return true
		end

		input.Text = newText
		input:CaptureFocus()
		input.CursorPosition = #newText + 1

		task.defer(function()
			if typeof(input) == "Instance" and input:IsA("TextBox") and input:IsFocused() then
                input.CursorPosition = #newText + 1
                input.Text = newText
			end
		end)

		return true
	end

	function Session:acceptSuggestion()
		local input = self:activeInput()
		if typeof(input) ~= "Instance" or not input:IsA("TextBox") then
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
