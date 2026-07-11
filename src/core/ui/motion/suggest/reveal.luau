--[[
	@name reveal
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
	Math = require("../math"),
}

local Tween = imports.Math.tween

--// locals
local function shifted(position, offset)
	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + offset)
end

local function savedPosition(session, key, root)
	local position = session[key]
	return typeof(position) == "UDim2" and position or root.Position
end

--// public api
local Reveal = {}

function Reveal.prepare(session)
	local refs = session.refs
    local motion = session.config.motion
    
    local panel = session.config.panel
    local layout = session.config.layout
    
    local slide = motion.textSlideOffset or 10
    
    local secondPosition = savedPosition(session, "secondRootPosition", refs.secondRoot)
    local position = savedPosition(session, "rootPosition", refs.root)

    session.secondRootPosition = secondPosition
    session.rootPosition = position
    
	refs.root.Position = shifted(position, motion.openSlideOffset or 44)
	refs.root.Size = UDim2.fromOffset(0, panel.height)
    refs.pill.Size = UDim2.fromOffset(0, panel.height)
    
	refs.pill.BackgroundTransparency = 1
    refs.Placeholder.TextTransparency = 1
    refs.ArrowIcon.ImageTransparency = 1
    refs.Prompt.TextTransparency = 1
	
    refs.pillPad.PaddingLeft = UDim.new(0, layout.paddingX + slide)
	refs.InputBox.Visible = false

	refs.secondRoot.Position = shifted(secondPosition, motion.openSlideOffset or 44)
	refs.secondRoot.Size = UDim2.fromOffset(0, panel.height)
    refs.secondPill.Size = UDim2.fromOffset(0, panel.height)
    
    refs.secondPill.Position = UDim2.new(0.5, 0, 1, 0)
    refs.SecondInputBox.Visible = false
    refs.secondRoot.Visible = false
	
    refs.SecondPlaceholder.TextTransparency = 1
    refs.secondPill.BackgroundTransparency = 1
    refs.SecondArrowIcon.ImageTransparency = 1
    
    refs.SecondInputBox.TextTransparency = 1
    refs.SecondPrompt.TextTransparency = 1
end

function Reveal.open(session)
	local refs = session.refs
    local motion = session.config.motion
    
	local panel = session.config.panel
    local layout = session.config.layout
    
    local openTime = motion.openSmoothTime or motion.expandSmoothTime
    local transparency = session.config.transparency
    
	local showPlaceholder = refs.InputBox.Text == ""
	local position = savedPosition(session, "rootPosition", refs.root)

	Tween.to(refs.root, {
        Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
        Position = position,
    }, openTime)
    
	Tween.to(refs.pill, {
        Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
        BackgroundTransparency = transparency.panel,
        Position = UDim2.new(0.5, 0, 1, 0),
    }, openTime)
    
	Tween.to(refs.pillPad, { PaddingLeft = UDim.new(0, layout.paddingX) }, motion.textFadeTime)
    Tween.fade(refs.Prompt, { TextTransparency = transparency.text }, motion.textFadeTime)
    
	refs.Placeholder.Visible = showPlaceholder
    
    Tween.fade(refs.Placeholder, { TextTransparency = showPlaceholder and transparency.text or 1 }, motion.textFadeTime)
	Tween.fade(refs.ArrowIcon, {
		ImageTransparency = transparency.arrow or transparency.text,
	}, motion.textFadeTime)

	if not session.hasSecondChat then
		return
	end

	local secondPosition = savedPosition(session, "secondRootPosition", refs.secondRoot)
    local showSecondPlaceholder = refs.SecondInputBox.Text == ""
    
    refs.SecondInputBox.Visible = true
    refs.secondRoot.Visible = true
	refs.secondPill.Visible = true
    
    
	if session.secondDetached then
        refs.secondRoot.Position = secondPosition

        Tween.to(refs.secondRoot, {
            Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
        }, openTime)
    else
        Tween.to(refs.secondRoot, {
            Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
            Position = secondPosition,
        }, openTime)
    end
    
	Tween.to(refs.secondPill, {
        Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
        BackgroundTransparency = transparency.panel,
        
        Position = UDim2.new(0.5, 0, 1, 0),
    }, openTime)
    
    refs.SecondPlaceholder.Visible = showSecondPlaceholder
    
    Tween.fade(refs.SecondInputBox, { TextTransparency = transparency.text }, motion.textFadeTime)
    Tween.fade(refs.SecondPrompt, { TextTransparency = transparency.text }, motion.textFadeTime)
    
	Tween.fade(refs.SecondPlaceholder, {
		TextTransparency = showSecondPlaceholder and transparency.text or 1,
    }, motion.textFadeTime)
    
	Tween.fade(refs.SecondArrowIcon, {
		ImageTransparency = transparency.arrow or transparency.text,
	}, motion.textFadeTime)
end

function Reveal.close(session)
	local refs = session.refs
    local motion = session.config.motion
    
	local panel = session.config.panel
    local transparency = session.config.transparency
    
	local closeTime = motion.collapseSmoothTime or 0.38
    local slideTime = motion.openSmoothTime or closeTime
    
    local hasSecondChat = session.hasSecondChat
    local width = panel.collapsedWidth
    
    local addChatFadeTime = 0.08
    local slideDelay = 0.04
    
    local secondPosition = savedPosition(session, "secondRootPosition", refs.secondRoot)
    local position = savedPosition(session, "rootPosition", refs.root)

    Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, 0) }, closeTime)
    Tween.to(refs.commandRow, { Size = UDim2.new(1, 0, 0, 0) }, closeTime)
	Tween.to(refs.addChatPill, {
		Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.fromOffset(width, 0),
        
		BackgroundTransparency = 1,
    }, closeTime)
    
    Tween.fade(refs.secondShadow, { ImageTransparency = 1 }, closeTime)
    Tween.fade(refs.stackShadow, { ImageTransparency = 1 }, closeTime)
    
    Tween.fade(refs.pillShadow, { ImageTransparency = 1 }, closeTime)
	Tween.fade(refs.suggShadow, { ImageTransparency = 1 }, closeTime)
	
	task.delay(closeTime, function()
		if not session.isClosing then
			return
        end
        
		for _, name in { "pillShadow", "suggShadow", "stackShadow", "secondShadow" } do
			if typeof(refs[name]) == "Instance" then
				refs[name].Visible = false
			end
		end
	end)

    Tween.fade(refs.secondCommandText, { TextTransparency = 1 }, motion.exitFadeTime)
    Tween.fade(refs.commandText, { TextTransparency = 1 }, motion.exitFadeTime)
	
	Tween.fade(refs.addChatIcon, { ImageTransparency = 1 }, addChatFadeTime)
    Tween.fade(refs.addChatText, { TextTransparency = 1 }, addChatFadeTime)
    
    Tween.fade(refs.SecondPlaceholder, { TextTransparency = 1 }, motion.exitFadeTime)
    Tween.fade(refs.SecondInputBox, { TextTransparency = 1 }, motion.exitFadeTime)
    Tween.fade(refs.SecondPrompt, { TextTransparency = 1 }, motion.exitFadeTime)
	
	Tween.fade(refs.SecondArrowIcon, { ImageTransparency = 1 }, motion.exitFadeTime)
    Tween.to(refs.root, { Size = UDim2.fromOffset(width, panel.height) }, closeTime)
    
	Tween.to(refs.pill, {
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(width, panel.height),
		BackgroundTransparency = transparency.panel,
    }, closeTime)
    
	Tween.to(refs.pillCorner, { CornerRadius = UDim.new(1, 0) }, closeTime)
	Tween.to(refs.pillBtn, {
		Size = UDim2.fromOffset(width, panel.height),
		Position = UDim2.new(0.5, 0, 1, 0),
    }, closeTime)
    
	if hasSecondChat then
		refs.secondRoot.Visible = true
        refs.secondPill.Visible = true
        
		Tween.to(refs.secondRoot, { Size = UDim2.fromOffset(width, panel.height) }, closeTime)
		Tween.to(refs.secondPill, {
            Size = UDim2.fromOffset(width, panel.height),
            BackgroundTransparency = transparency.panel,
            
            Position = UDim2.new(0.5, 0, 1, 0),
        }, closeTime)
        
		Tween.to(refs.secondPillCorner, { CornerRadius = UDim.new(1, 0) }, closeTime)
    end
    
	task.delay(addChatFadeTime, function()
		if typeof(refs.addChatIcon) == "Instance" then
			refs.addChatIcon.ImageTransparency = 1
        end
        
		if typeof(refs.addChatText) == "Instance" then
			refs.addChatText.TextTransparency = 1
		end
	end)

	task.delay(slideDelay, function()
		if not refs.root then
			return
        end
        
		Tween.to(refs.root, {
			Position = shifted(position, motion.openSlideOffset or 44),
			Size = UDim2.fromOffset(0, panel.height),
        }, slideTime)
        
		Tween.to(refs.pill, {
			Size = UDim2.fromOffset(0, panel.height),
			BackgroundTransparency = 1,
        }, slideTime)
        
        Tween.fade(refs.Placeholder, { TextTransparency = 1 }, motion.exitFadeTime)
        Tween.fade(refs.ArrowIcon, { ImageTransparency = 1 }, motion.exitFadeTime)
        
        Tween.fade(refs.InputBox, { TextTransparency = 1 }, motion.exitFadeTime)
		Tween.fade(refs.Prompt, { TextTransparency = 1 }, motion.exitFadeTime)

		if hasSecondChat and refs.secondRoot then
			Tween.to(refs.secondRoot, {
				Position = shifted(secondPosition, motion.openSlideOffset or 44),
				Size = UDim2.fromOffset(0, panel.height),
            }, slideTime)
            
			Tween.to(refs.secondPill, {
				Size = UDim2.fromOffset(0, panel.height),
				BackgroundTransparency = 1,
			}, slideTime)
		end
	end)

	return slideDelay + slideTime + 0.05
end

return Reveal
