--[[
	@name shape
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

local imports = {
	Math = require("../math"),
	View = require("../../elements/misc/view"),
}

local Tween = imports.Math.tween

local Shape = {}

local function layoutMain(session, time, width, mainHeight, stackExtra, layoutSeq)
	local refs = session.refs
	local panel = session.config.panel
	local transparency = session.config.transparency

	Tween.to(refs.pill, {
		Position = UDim2.new(0.5, 0, 1, -stackExtra),
		Size = UDim2.fromOffset(width, mainHeight),
		BackgroundTransparency = transparency.panel,
	}, time)
	Tween.to(refs.pillCorner, {
		CornerRadius = (session.isExpanded and session.hasOutput) and UDim.new(0, panel.outputRadius) or UDim.new(1, 0),
	}, time)
	Tween.to(refs.pillBtn, {
		Size = UDim2.fromOffset(width, panel.height),
		Position = UDim2.new(0.5, 0, 1, -stackExtra),
	}, time)

	if session.isExpanded and session.hasOutput then
		refs.commandRow.Visible = true
		refs.commandRow.ScrollingEnabled = true
		if typeof(refs.pillShadow) == "Instance" then
			refs.pillShadow.Visible = true
			Tween.fade(refs.pillShadow, { ImageTransparency = transparency.shadow }, time)
		end
		session:syncScrollSoon(1, time)
		Tween.to(refs.commandRow, { Size = UDim2.new(1, 0, 0, session:historyHeight(1)) }, time)
		Tween.to(refs.commandText, {
			Position = UDim2.fromOffset(2, 0),
			TextTransparency = transparency.text,
		}, time)
		Tween.fade(refs.ArrowIcon, {
			ImageTransparency = transparency.arrow or transparency.text,
		}, time)
	else
		refs.commandRow.ScrollingEnabled = false
		refs.commandRow.ScrollBarImageTransparency = 1
		Tween.to(refs.commandRow, { Size = UDim2.new(1, 0, 0, 0) }, time)
		Tween.to(refs.commandText, { TextTransparency = 1 }, time)
		task.delay(time, function()
			if session.layoutSeq == layoutSeq and not session.isExpanded and typeof(refs.commandRow) == "Instance" then
				refs.commandRow.Visible = false
			end
		end)
	end
end

local function layoutAddChat(session, time, width, showAddChat, showSecondChat, layoutSeq)
	local refs = session.refs
	local panel = session.config.panel
	local transparency = session.config.transparency
	local position = UDim2.new(0.5, 0, 1, 0)
	local openWidth = session:addChatWidth(width)
	local fadeTime = math.min(time, 0.14)

	if showAddChat then
		if typeof(refs.addChatPill) == "Instance" and not refs.addChatPill.Visible then
			refs.addChatPill.Position = position
			refs.addChatPill.Size = UDim2.fromOffset(panel.addChatCollapsedWidth or panel.height, panel.height)
			refs.addChatPill.BackgroundTransparency = 1
			refs.addChatText.Size = UDim2.fromOffset(0, 0)
			refs.addChatText.TextTransparency = 1
		end
		refs.addChatPill.Visible = true
		session.stackShadowHiding = false
		if typeof(refs.stackShadow) == "Instance" then
			refs.stackShadow.Visible = true
			imports.View.setShadowBounds(refs.stackShadow, refs.addChatPill)
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

	if typeof(refs.stackShadow) == "Instance" and not showSecondChat then
		session.stackShadowHiding = true
		refs.stackShadow.Visible = true
		Tween.fade(refs.stackShadow, { ImageTransparency = 1 }, time)
	end
	Tween.fade(refs.addChatIcon, { ImageTransparency = 1 }, fadeTime)
	Tween.to(refs.addChatText, { Size = UDim2.fromOffset(0, 0) }, fadeTime)
	Tween.fade(refs.addChatText, { TextTransparency = 1 }, fadeTime)
	Tween.to(refs.addChatPill, {
		Position = position,
		Size = UDim2.fromOffset(openWidth, 0),
		BackgroundTransparency = 1,
	}, time)
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

local function layoutSecond(session, time, width, showAddChat, showSecondChat, layoutSeq)
	local refs = session.refs
	local panel = session.config.panel
	local transparency = session.config.transparency

	if showSecondChat then
		if session.secondOpeningFromAdd and typeof(refs.addChatPill) == "Instance" then
			refs.secondPill.Position = refs.addChatPill.Position
			refs.secondPill.Size = refs.addChatPill.Size
			refs.secondPill.BackgroundTransparency = refs.addChatPill.BackgroundTransparency
			session.secondOpeningFromAdd = false
		end
		refs.secondPill.Visible = true
		refs.SecondInputBox.Visible = true
		session.stackShadowHiding = false
		if typeof(refs.stackShadow) == "Instance" then
			refs.stackShadow.Visible = true
			imports.View.setShadowBounds(refs.stackShadow, refs.secondPill)
			Tween.fade(refs.stackShadow, { ImageTransparency = transparency.shadow }, time)
		end
		Tween.to(refs.secondPill, {
			Size = UDim2.fromOffset(width, session:secondHeight()),
			BackgroundTransparency = transparency.panel,
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
			refs.secondCommandRow.Visible = true
			refs.secondCommandRow.ScrollingEnabled = true
			session:syncScrollSoon(2, time)
			Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, session:historyHeight(2)) }, time)
			Tween.to(refs.secondCommandText, {
				Position = UDim2.fromOffset(2, 0),
				TextTransparency = transparency.text,
			}, time)
		else
			refs.secondCommandRow.ScrollingEnabled = false
			refs.secondCommandRow.ScrollBarImageTransparency = 1
			Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, 0) }, time)
			Tween.fade(refs.secondCommandText, { TextTransparency = 1 }, time)
		end
		return
	end

	if typeof(refs.stackShadow) == "Instance" and not showAddChat then
		session.stackShadowHiding = true
		refs.stackShadow.Visible = true
		Tween.fade(refs.stackShadow, { ImageTransparency = 1 }, time)
	end
	Tween.fade(refs.SecondPrompt, { TextTransparency = 1 }, time)
	Tween.fade(refs.SecondInputBox, { TextTransparency = 1 }, time)
	Tween.fade(refs.SecondPlaceholder, { TextTransparency = 1 }, time)
	Tween.fade(refs.SecondArrowIcon, { ImageTransparency = 1 }, time)
	Tween.fade(refs.secondCommandText, { TextTransparency = 1 }, time)
	refs.secondCommandRow.ScrollingEnabled = false
	refs.secondCommandRow.ScrollBarImageTransparency = 1
	Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, 0) }, time)
	Tween.to(refs.secondPill, {
		Size = UDim2.fromOffset(width, 0),
		BackgroundTransparency = 1,
	}, time)
	task.delay(time, function()
		if session.layoutSeq ~= layoutSeq then
			return
		end
		session.stackShadowHiding = false
		local stillWanted = session.isExpanded and session.hasSecondChat
		if not stillWanted and typeof(refs.secondPill) == "Instance" then
			refs.secondPill.Visible = false
		end
		if not stillWanted and typeof(refs.secondCommandRow) == "Instance" then
			refs.secondCommandRow.Visible = false
		end
	end)
end

function Shape.layout(session, duration, targetWidth)
	local refs = session.refs
	local config = session.config
	local panel = config.panel

	local width = targetWidth or (session.isExpanded and session:activeWidth() or panel.collapsedWidth)
	local mainHeight = session.isExpanded and session:mainHeight() or panel.height
	local stackExtra = session:stackExtra()
	local time = duration or config.motion.outputSmoothTime
	local showAddChat = session.isExpanded and session.hasOutput and not session.hasSecondChat
	local showSecondChat = session.isExpanded and session.hasOutput and session.hasSecondChat

	session.layoutSeq += 1
	session.layoutTargetWidth = width
	local layoutSeq = session.layoutSeq

	Tween.to(refs.root, { Size = UDim2.fromOffset(width, mainHeight + stackExtra) }, time)
	layoutMain(session, time, width, mainHeight, stackExtra, layoutSeq)
	layoutAddChat(session, time, width, showAddChat, showSecondChat, layoutSeq)
	layoutSecond(session, time, width, showAddChat, showSecondChat, layoutSeq)

	if typeof(refs.suggList) == "Instance" and not session.suggestionsHiding then
		Tween.to(refs.suggList, {
			Size = UDim2.fromOffset(width, refs.suggList.Size.Y.Offset),
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
		session:updateShadows()
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
	Tween.to(refs.addChatText, { Size = textSize }, time)
	Tween.fade(refs.addChatText, { TextTransparency = textTransparency }, time)
	if typeof(refs.stackShadow) == "Instance" and typeof(refs.addChatPill) == "Instance" then
		task.defer(function()
			if session.refs and not session.isClosing and not session.hasSecondChat then
				imports.View.setShadowBounds(refs.stackShadow, refs.addChatPill)
			end
		end)
	end
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

	Tween.fade(refs.InputBox, { TextTransparency = 1 }, motion.textFadeTime)
	Tween.fade(refs.ArrowIcon, {
		ImageTransparency = transparency.arrow or transparency.text,
	}, motion.textFadeTime)
	Tween.fade(refs.commandText, { TextTransparency = 1 }, motion.textFadeTime)
	Shape.layout(session, motion.collapseSmoothTime)
end

return Shape
