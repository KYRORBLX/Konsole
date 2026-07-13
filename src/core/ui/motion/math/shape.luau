--[[
	@name shape
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
	Math = require("../math"),
}

local Tween = imports.Math.tween

--// locals
local function layoutMain(session, time, width, mainHeight, stackExtra, layoutSeq)
	local refs = session.refs
	local panel = session.config.panel

	local transparency = session.config.transparency

	Tween.to(refs.pill, {
		Position = UDim2.new(0.5, 0, 1, -stackExtra),
        BackgroundTransparency = transparency.panel,
        
        Size = UDim2.fromOffset(width, mainHeight),
    }, time)
    
	Tween.to(refs.pillCorner, {
		CornerRadius = (session.isExpanded and session.hasOutput) and UDim.new(0, panel.outputRadius) or UDim.new(1, 0),
    }, time)
    
	Tween.to(refs.pillBtn, {
		Size = UDim2.fromOffset(width, panel.height),
		Position = UDim2.new(0.5, 0, 1, -stackExtra),
	}, time)

	if session.isExpanded and session.hasOutput then
        refs.commandRow.ScrollingEnabled = true
        refs.commandRow.Visible = true
        
		if typeof(refs.pillShadow) == "Instance" then
			refs.pillShadow.Visible = true
			Tween.fade(refs.pillShadow, { ImageTransparency = transparency.shadow }, time)
        end
        
        session:syncScrollSoon(1, time)
        
		Tween.to(refs.commandRow, { Size = UDim2.new(1, 0, 0, session:historyHeight(1)) }, time)
		Tween.to(refs.commandText, {
            TextTransparency = transparency.text,
            Position = UDim2.fromOffset(2, 0),
        }, time)
        
		Tween.fade(refs.ArrowIcon, {
			ImageTransparency = transparency.arrow or transparency.text,
		}, time)
	else
        refs.commandRow.ScrollBarImageTransparency = 1
        refs.commandRow.ScrollingEnabled = false
        
		Tween.to(refs.commandRow, { Size = UDim2.new(1, 0, 0, 0) }, time)
        Tween.to(refs.commandText, { TextTransparency = 1 }, time)
        
		task.delay(time, function()
			if session.layoutSeq == layoutSeq and not session.isExpanded and typeof(refs.commandRow) == "Instance" then
				refs.commandRow.Visible = false
			end
		end)
	end
end

local function layoutAddChat(session, time, width, showAddChat, layoutSeq)
	local refs = session.refs
	local panel = session.config.panel
    local transparency = session.config.transparency
    
    local openWidth = session:addChatWidth(width)
    
    local position = UDim2.new(0.5, 0, 1, 0)
	local fadeTime = math.min(time, 0.14)

	if showAddChat then
		if session.secondClosingToAdd then
			refs.addChatPill.Visible = false
			session.stackShadowHiding = true

			task.delay(time, function()
				if session.layoutSeq ~= layoutSeq or session.hasSecondChat or not session.isExpanded then
					return
				end

				refs.addChatPill.Size = UDim2.fromOffset(openWidth, panel.height)
				refs.addChatText.Size = UDim2.fromOffset(0, 0)
				refs.addChatPill.Position = position

				refs.addChatPill.BackgroundTransparency = 1
				refs.addChatIcon.ImageTransparency = 1
				refs.addChatText.TextTransparency = 1
				refs.addChatPill.Visible = true

				session.stackShadowHiding = false

				if typeof(refs.stackShadow) == "Instance" then
					refs.stackShadow.ImageTransparency = 1
					refs.stackShadow.Visible = true

					Tween.fade(refs.stackShadow, { ImageTransparency = transparency.shadow }, fadeTime)
				end

				Tween.to(refs.addChatPill, { BackgroundTransparency = transparency.panel }, fadeTime)
				Tween.fade(refs.addChatIcon, { ImageTransparency = transparency.dimText }, fadeTime)
			end)

			return
		end

		if typeof(refs.addChatPill) == "Instance" and not refs.addChatPill.Visible then
            refs.addChatPill.Size = UDim2.fromOffset(panel.addChatCollapsedWidth or panel.height, panel.height)
            refs.addChatPill.Position = position
            			
            refs.addChatText.Size = UDim2.fromOffset(0, 0)
            
            refs.addChatPill.BackgroundTransparency = 1
			refs.addChatText.TextTransparency = 1
        end
        
        session.stackShadowHiding = false
        refs.addChatPill.Visible = true
		
		if typeof(refs.stackShadow) == "Instance" then
			refs.stackShadow.Visible = true
			Tween.fade(refs.stackShadow, { ImageTransparency = transparency.shadow }, time)
        end
        
		Tween.to(refs.addChatPill, {
			Position = position,
			Size = UDim2.fromOffset(openWidth, panel.height),
			BackgroundTransparency = transparency.panel,
        }, time)
        
		Tween.fade(refs.addChatIcon, { ImageTransparency = transparency.dimText }, time)
		Tween.to(refs.addChatText, {
			Size = session.addChatHover and UDim2.new(1, -28, 1, 0) or UDim2.fromOffset(0, 0),
        }, time)
        
		Tween.fade(refs.addChatText, {
			TextTransparency = session.addChatHover and transparency.dimText or 1,
        }, time)
        
		return
	end

	local collapsing = not session.isExpanded
	local fadeOutTime = collapsing and fadeTime or time

	if typeof(refs.stackShadow) == "Instance" then
		session.stackShadowHiding = true
		refs.stackShadow.Visible = true
		Tween.fade(refs.stackShadow, { ImageTransparency = 1 }, fadeOutTime)
    end
    
    Tween.to(refs.addChatText, { Size = UDim2.fromOffset(0, 0) }, fadeTime)
    Tween.fade(refs.addChatIcon, { ImageTransparency = 1 }, fadeTime)
	Tween.fade(refs.addChatText, { TextTransparency = 1 }, fadeTime)
	Tween.to(refs.addChatPill, {
		Position = position,
		Size = UDim2.fromOffset(openWidth, collapsing and panel.height or 0),
		BackgroundTransparency = 1,
    }, fadeOutTime)
    
	task.delay(fadeTime, function()
		if session.layoutSeq ~= layoutSeq then
			return
        end
        
		if typeof(refs.addChatIcon) == "Instance" then
			refs.addChatIcon.ImageTransparency = 1
        end
        
		if typeof(refs.addChatText) == "Instance" then
			refs.addChatText.TextTransparency = 1
		end
    end)
    
	task.delay(time, function()
		if session.layoutSeq ~= layoutSeq then
			return
        end
        
        session.stackShadowHiding = false
        local stillWanted = session.isExpanded and session.hasOutput and not session.hasSecondChat
        
		if not stillWanted and typeof(refs.addChatPill) == "Instance" then
			refs.addChatPill.Visible = false
		end
	end)
end

local function layoutSecond(session, time, width, showSecondChat, layoutSeq)
	local refs = session.refs
	local panel = session.config.panel
	local transparency = session.config.transparency

	if showSecondChat then
        local height = session:secondHeight()
        
		refs.secondRoot.Visible = true
        refs.secondPill.Visible = true
        
        session.secondShadowHiding = false
        refs.SecondInputBox.Visible = true
        
		if typeof(refs.secondShadow) == "Instance" then
			refs.secondShadow.Visible = true

			Tween.fade(refs.secondShadow, { ImageTransparency = transparency.shadow }, time)
        end
        
		Tween.to(refs.secondRoot, { Size = UDim2.fromOffset(width, height) }, time)
		Tween.to(refs.secondPill, {
            BackgroundTransparency = transparency.panel,
            Size = UDim2.fromOffset(width, height),
            
            Position = UDim2.new(0.5, 0, 1, 0),
        }, time)
        
		Tween.to(refs.secondPillCorner, {
			CornerRadius = session.hasSecondOutput and UDim.new(0, panel.outputRadius) or UDim.new(1, 0),
        }, time)
        
		Tween.fade(refs.SecondPrompt, { TextTransparency = transparency.text }, time)
		Tween.fade(refs.SecondInputBox, { TextTransparency = transparency.text }, time)
		Tween.fade(refs.SecondPlaceholder, {
			TextTransparency = refs.SecondInputBox.Text == "" and transparency.text or 1,
        }, time)
        
		Tween.fade(refs.SecondArrowIcon, {
			ImageTransparency = transparency.arrow or transparency.text,
        }, time)
        
        if session.hasSecondOutput then

            refs.secondCommandRow.ScrollingEnabled = true
            refs.secondCommandRow.Visible = true
            
            session:syncScrollSoon(2, time)
            
			Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, session:historyHeight(2)) }, time)
			Tween.to(refs.secondCommandText, {
				Position = UDim2.fromOffset(2, 0),
				TextTransparency = transparency.text,
            }, time)
		else
            refs.secondCommandRow.ScrollBarImageTransparency = 1
            refs.secondCommandRow.ScrollingEnabled = false
            
			Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, 0) }, time)
			Tween.fade(refs.secondCommandText, { TextTransparency = 1 }, time)
        end
        
		return
	end

    if typeof(refs.secondShadow) == "Instance" then
        
		session.secondShadowHiding = true
        refs.secondShadow.Visible = true
        
		Tween.fade(refs.secondShadow, { ImageTransparency = 1 }, time)
    end
    
    Tween.fade(refs.SecondPlaceholder, { TextTransparency = 1 }, time)
    Tween.fade(refs.secondCommandText, { TextTransparency = 1 }, time)
    Tween.fade(refs.SecondArrowIcon, { ImageTransparency = 1 }, time)
    
    Tween.fade(refs.SecondInputBox, { TextTransparency = 1 }, time)
    Tween.fade(refs.SecondPrompt, { TextTransparency = 1 }, time)
    
	refs.secondCommandRow.ScrollBarImageTransparency = 1
	refs.secondCommandRow.ScrollingEnabled = false
    
	Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, 0) }, time)

	local closingToAdd = session.isExpanded and session.secondClosingToAdd
	local targetWidth = closingToAdd and session:addChatWidth(width) or width
	local targetHeight = closingToAdd and panel.height or 0

	local rootTarget = { Size = UDim2.fromOffset(targetWidth, targetHeight) }

	if closingToAdd then
		rootTarget.Position = refs.root.Position
	end

	Tween.to(refs.secondRoot, rootTarget, time)
	Tween.to(refs.secondPill, {
		Size = UDim2.fromOffset(targetWidth, targetHeight),
		BackgroundTransparency = closingToAdd and transparency.panel or 1,
    }, time)
	Tween.to(refs.secondPillCorner, {
		CornerRadius = closingToAdd and UDim.new(1, 0) or refs.secondPillCorner.CornerRadius,
	}, time)
    
	task.delay(time, function()
		if session.layoutSeq ~= layoutSeq then
			return
        end
        
		local stillWanted = session.isExpanded and session.hasSecondChat
		if not stillWanted and typeof(refs.secondPill) == "Instance" then
			refs.secondPill.Visible = false
        end
        
		if not stillWanted and typeof(refs.secondRoot) == "Instance" then
			refs.secondRoot.Visible = false
        end
        
		session.secondShadowHiding = false
		if not stillWanted and typeof(refs.secondShadow) == "Instance" then
			refs.secondShadow.Visible = false
        end
        
		if not stillWanted and typeof(refs.secondCommandRow) == "Instance" then
			refs.secondCommandRow.Visible = false
		end

		session.secondClosingToAdd = false
	end)
end

--// public api
local Shape = {}

function Shape.layout(session, duration, targetWidth)
	local refs = session.refs
    local config = session.config
    
	local panel = config.panel

	local width = targetWidth or (session.isExpanded and session:activeWidth() or panel.collapsedWidth)
    local mainHeight = session.isExpanded and session:mainHeight() or panel.height
    
    local stackExtra = session:stackExtra()
	
	local showAddChat = session.isExpanded and session.hasOutput and not session.hasSecondChat
    local showSecondChat = session.isExpanded and session.hasSecondChat
    local time = duration or config.motion.outputSmoothTime

    session.layoutTargetWidth = width
    session.layoutSeq += 1
    
	local layoutSeq = session.layoutSeq

	Tween.to(refs.root, { Size = UDim2.fromOffset(width, mainHeight + stackExtra) }, time)
	layoutMain(session, time, width, mainHeight, stackExtra, layoutSeq)
	layoutAddChat(session, time, width, showAddChat, layoutSeq)

	if not session.secondDetached or not showSecondChat then
		layoutSecond(session, time, width, showSecondChat, layoutSeq)
	end

	if typeof(refs.suggList) == "Instance" and not session.suggestionsHiding then
		local suggestionWidth = refs.suggList.Parent == refs.secondRoot and session:activeWidth(2) or width

		Tween.to(refs.suggList, {
			Size = UDim2.fromOffset(suggestionWidth, refs.suggList.Size.Y.Offset),
		}, time)
	end

	task.defer(function()
		if session.layoutSeq == layoutSeq then
			session:updateShadows()
		end
    end)
    
	task.delay(time, function()
		if session.layoutSeq ~= layoutSeq then
			return
        end
        
		session:syncWidths(width)

		if session.refs.mainDragging then
			session.refs.mainDragging.setPosition(session.refs.root.Position)
		end

		session:updateShadows()
	end)
end

function Shape.layoutDetachedSecond(session, duration, targetWidth)
	local config = session.config
    local width = targetWidth or session:activeWidth(2)
    local time = duration or config.motion.outputSmoothTime
    
	session.secondLayoutTargetWidth = width

	layoutSecond(session, time, width, true, session.layoutSeq)

	if typeof(session.refs.suggList) == "Instance" and session.refs.suggList.Parent == session.refs.secondRoot then
		Tween.to(session.refs.suggList, {
			Size = UDim2.fromOffset(width, session.refs.suggList.Size.Y.Offset),
		}, time)
	end

	task.delay(time, function()
		if session.secondDetached then
			session:syncSecondWidth(width)

			if session.refs.secondDragging then
				session.refs.secondDragging.setPosition(session.refs.secondRoot.Position)
			end

			session:updateShadows()
		end
	end)
end

function Shape.hover(session)
	local refs = session.refs
	local config = session.config

	local width = session:addChatWidth(session.layoutTargetWidth or session:activeWidth())
    local textTransparency = session.addChatHover and config.transparency.dimText or 1
    
	local textSize = session.addChatHover and UDim2.new(1, -28, 1, 0) or UDim2.fromOffset(0, 0)
	local time = config.motion.itemSlideSmoothTime or 0.2

	Tween.to(refs.addChatPill, { Size = UDim2.fromOffset(width, config.panel.height) }, time)
    Tween.fade(refs.addChatText, { TextTransparency = textTransparency }, time)
    Tween.to(refs.addChatText, { Size = textSize }, time)
    
end

function Shape.expand(session)
	local refs = session.refs
	local motion = session.config.motion
	local transparency = session.config.transparency

	Tween.fade(refs.ArrowIcon, {
		ImageTransparency = transparency.arrow or transparency.text,
    }, motion.textFadeTime)
    
    Tween.fade(refs.InputBox, { TextTransparency = transparency.text }, motion.textFadeTime)
    
	Shape.layout(session, motion.expandSmoothTime)
end

function Shape.collapse(session)
	local refs = session.refs
	local motion = session.config.motion
	local transparency = session.config.transparency

	Tween.fade(refs.ArrowIcon, {
		ImageTransparency = transparency.arrow or transparency.text,
    }, motion.textFadeTime)
    
    Tween.fade(refs.commandText, { TextTransparency = 1 }, motion.textFadeTime)
    
	Shape.layout(session, motion.collapseSmoothTime)
end

return Shape
