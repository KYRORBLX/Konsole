--[[
	@name suggestions
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--// imports
local imports = {
	Suggest = require("../../motion/suggest"),
    Providers = require("./providers"),
    
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
        text = string.lower(imports.Text.cleanStart(text))
        
		if text == "" then
			return {}
		end

		return rankList(self.suggestionSource, text)
	end

	function Session:resolveSuggestions(text)
        local chip = if type(self.focusedChip) == "function" then self:focusedChip() else self.activeChip
        
		if chip and type(chip.arg) == "table" then
			local source = imports.Providers.resolve(chip.arg)

			if text == "" then
				return source, text
			end

			local matches = rankList(source, text)

			if #matches == 0 then
				matches = source
			end

			return matches, text
		end

		local query = string.lower(imports.Text.cleanStart(text))

		if string.find(query, "%s") then
			return {}, query
		end

		return self:suggestionsFor(query), query
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
                self.refs.suggShadow.ImageTransparency = 1
                self.refs.suggShadow.Visible = false
			end
			return
		end

        self.currentSuggestions = {}
        
		self.selectedSuggestion = nil
        self.suggestionsHiding = true
        
        self.suggestToken += 1
		
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
        
		if typeof(suggList) ~= "Instance" then
			return
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
        
        imports.View.clearSuggestionConnections(self)
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
			local button = imports.View.make("TextButton", {
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
            
			imports.View.corner(button, panel.suggestionRadius or 10)
			button:SetAttribute("SuggestionText", suggestion)

			local label = imports.View.make("TextLabel", {
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
				
                Text = imports.View.richSuggestion(suggestion, query, config),
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
				imports.Suggest.item(self, label)
			end
		end

		self:syncSelection()
        imports.Suggest.reveal(self, visibleCount)
        
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
        if chip and typeof(chip.box) == "Instance" then
            
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

		local input = self:activeInput()
		if typeof(input) ~= "Instance" then
			return false
		end

        local newText = suggestion
        
		local schema = type(self.argSchemas) == "table" and self.argSchemas[string.lower(suggestion)]
		if type(schema) == "table" and #schema > 0 and not string.find(suggestion, " ", 1, true) then
			newText ..= " "
		end

        input.CursorPosition = #newText + 1
        input.Text = newText

        input:CaptureFocus()
        
		task.defer(function()
			if typeof(input) == "Instance" and input:IsFocused() then
                input.CursorPosition = #newText + 1
                input.Text = newText
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
