--[[
	@name suggest
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 13, 2026
]]

--// imports
local imports = {
	Math = require("./math"),
	Placement = require("../elements/misc/placement"),
}

local Tween = imports.Math.tween

local function suggestionWidth(session)
	local refs = session.refs
	local channel = refs.suggList.Parent == refs.secondRoot and 2 or 1

	return session:activeWidth(channel)
end

local function suggestionPosition(session, offset)
	local refs = session.refs
	local root = refs.suggList.Parent

	if typeof(root) ~= "Instance" or not root:IsA("GuiObject") then
		root = refs.root
	end

	return imports.Placement.suggestion(root, offset)
end

--// public api
local Suggest = {}

function Suggest.item(session, label)
	local layout = session.config.layout
	local motion = session.config.motion

	Tween.to(label, {
		Position = UDim2.new(0, layout.paddingX, 0, 1),
		TextTransparency = session.config.transparency.suggText,
	}, motion.itemSlideSmoothTime)
end

function Suggest.reveal(session, count)
	local refs = session.refs
    local config = session.config
    
    local panel = config.panel
	local suggList = refs.suggList
	local startPosition, anchorPoint = suggestionPosition(session, 1)
	local openPosition = suggestionPosition(session, panel.suggestionGap)

    suggList.AnchorPoint = anchorPoint
    suggList.Position = startPosition
    suggList.Visible = true
    
    if typeof(refs.suggShadow) == "Instance" then
        
		refs.suggShadow.Visible = not session.isClosing
        refs.suggShadow.ImageTransparency = 1

		Tween.to(refs.suggShadow, {
			ImageTransparency = config.transparency.shadow,
		}, config.motion.listSmoothTime)
    end
    
	Tween.to(suggList, {
        Size = UDim2.fromOffset(suggestionWidth(session), (count * panel.suggestionHeight) + 4),
        BackgroundTransparency = config.transparency.suggPanel,
		Position = openPosition,
	}, config.motion.listSmoothTime)
end

function Suggest.hide(session)
	local refs = session.refs
	local config = session.config
    local suggList = refs.suggList
    
	local token = session.suggestToken
	local slide = config.motion.textSlideOffset or 10
	local openPosition = suggestionPosition(session, config.panel.suggestionGap)
	local root = suggList.Parent
	local hidePosition = openPosition

	if typeof(root) == "Instance" and root:IsA("GuiObject") then
		hidePosition = imports.Placement.suggestion(root, -config.panel.suggestionGap)
	end

	for _, child in suggList:GetChildren() do
		if child:IsA("TextButton") then
			Tween.to(child:FindFirstChild("Label"), {
				Position = UDim2.new(0, config.layout.paddingX, 0, 1 + slide),
				TextTransparency = 1,
			}, config.motion.itemSlideSmoothTime)
		end
	end

	if typeof(refs.suggShadow) == "Instance" then
		refs.suggShadow.Visible = not session.isClosing
		Tween.to(refs.suggShadow, { ImageTransparency = 1 }, config.motion.listSmoothTime)
    end
    
	Tween.to(suggList, {
		Position = hidePosition,
		Size = UDim2.fromOffset(suggestionWidth(session), 0),
		BackgroundTransparency = 1,
	}, config.motion.listSmoothTime)

	task.delay(config.motion.exitFadeTime, function()
		if token ~= session.suggestToken or typeof(suggList) ~= "Instance" then
			return
        end
        
        session.suggestionsHiding = false
        suggList.Visible = false
        
		if typeof(refs.suggShadow) == "Instance" then
			refs.suggShadow.Visible = false
			refs.suggShadow.ImageTransparency = 1
        end
        
		for _, child in suggList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
        end
        
		session:updateShadows()
	end)
end

function Suggest.placeholder(session, placeholder, visible)
	placeholder.Position = UDim2.fromOffset(0, 0)
	if visible then
		placeholder.Visible = true
	end

	Tween.to(placeholder, {
		TextTransparency = visible and session.config.transparency.text or 1,
	}, session.config.motion.textFadeTime)
end

return Suggest
