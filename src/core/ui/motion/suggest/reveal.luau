--[[
	@name reveal
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

local imports = {
	Math = require("../math"),
}

local Tween = imports.Math.tween

local Reveal = {}

function Reveal.prepare(session)
	local refs = session.refs
	local motion = session.config.motion
	local panel = session.config.panel
	local layout = session.config.layout
	local slide = motion.textSlideOffset or 10

	refs.root.Position = UDim2.new(0.5, 0, 1, -panel.bottomInset + (motion.openSlideOffset or 44))
	refs.root.Size = UDim2.fromOffset(0, panel.height)
	refs.pill.Size = UDim2.fromOffset(0, panel.height)
	refs.pill.BackgroundTransparency = 1
	refs.Prompt.TextTransparency = 1
	refs.Placeholder.TextTransparency = 1
	refs.ArrowIcon.ImageTransparency = 1
	refs.pillPad.PaddingLeft = UDim.new(0, layout.paddingX + slide)
	refs.InputBox.Visible = false
end

function Reveal.open(session)
	local refs = session.refs
	local motion = session.config.motion
	local panel = session.config.panel
	local layout = session.config.layout
	local transparency = session.config.transparency
	local openTime = motion.openSmoothTime or motion.expandSmoothTime

	Tween.to(refs.root, {
		Position = UDim2.new(0.5, 0, 1, -panel.bottomInset),
		Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
	}, openTime)
	Tween.to(refs.pill, {
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(panel.collapsedWidth, panel.height),
		BackgroundTransparency = transparency.panel,
	}, openTime)
	Tween.to(refs.pillPad, { PaddingLeft = UDim.new(0, layout.paddingX) }, motion.textFadeTime)
	Tween.fade(refs.Prompt, { TextTransparency = transparency.text }, motion.textFadeTime)
	Tween.fade(refs.Placeholder, { TextTransparency = transparency.text }, motion.textFadeTime)
	Tween.fade(refs.ArrowIcon, {
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
	local slideDelay = 0.04
	local addChatFadeTime = 0.08
	local width = panel.collapsedWidth

	local addChatWidth = width
	local addChatReturnPosition = UDim2.new(0.5, 0, 1, 0)
	if typeof(refs.addChatPill) == "Instance" and refs.addChatPill.Size.X.Offset > 1 then
		addChatWidth = refs.addChatPill.Size.X.Offset
		addChatReturnPosition = refs.addChatPill.Position
	elseif typeof(refs.root) == "Instance" and refs.root.Size.X.Offset > 1 then
		addChatWidth = refs.root.Size.X.Offset
	end

	Tween.to(refs.commandRow, { Size = UDim2.new(1, 0, 0, 0) }, closeTime)
	Tween.to(refs.secondCommandRow, { Size = UDim2.new(1, 0, 0, 0) }, closeTime)
	Tween.to(refs.addChatPill, {
		Position = addChatReturnPosition,
		Size = UDim2.fromOffset(addChatWidth, 0),
		BackgroundTransparency = 1,
	}, closeTime)
	Tween.to(refs.secondPill, {
		Size = UDim2.fromOffset(width, 0),
		BackgroundTransparency = 1,
	}, closeTime)
	Tween.fade(refs.pillShadow, { ImageTransparency = 1 }, closeTime)
	Tween.fade(refs.suggShadow, { ImageTransparency = 1 }, closeTime)
	Tween.fade(refs.stackShadow, { ImageTransparency = 1 }, closeTime)
	task.defer(function()
		if not session.isClosing then
			return
		end
		for _, name in { "pillShadow", "suggShadow", "stackShadow" } do
			if typeof(refs[name]) == "Instance" then
				refs[name].Visible = false
			end
		end
	end)

	Tween.fade(refs.commandText, { TextTransparency = 1 }, motion.exitFadeTime)
	Tween.fade(refs.secondCommandText, { TextTransparency = 1 }, motion.exitFadeTime)
	Tween.fade(refs.addChatIcon, { ImageTransparency = 1 }, addChatFadeTime)
	Tween.fade(refs.addChatText, { TextTransparency = 1 }, addChatFadeTime)
	Tween.fade(refs.SecondPrompt, { TextTransparency = 1 }, motion.exitFadeTime)
	Tween.fade(refs.SecondInputBox, { TextTransparency = 1 }, motion.exitFadeTime)
	Tween.fade(refs.SecondPlaceholder, { TextTransparency = 1 }, motion.exitFadeTime)
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
			Position = UDim2.new(0.5, 0, 1, -panel.bottomInset + (motion.openSlideOffset or 44)),
			Size = UDim2.fromOffset(0, panel.height),
		}, slideTime)
		Tween.to(refs.pill, {
			Size = UDim2.fromOffset(0, panel.height),
			BackgroundTransparency = 1,
		}, slideTime)
		Tween.fade(refs.InputBox, { TextTransparency = 1 }, motion.exitFadeTime)
		Tween.fade(refs.ArrowIcon, { ImageTransparency = 1 }, motion.exitFadeTime)
		Tween.fade(refs.Placeholder, { TextTransparency = 1 }, motion.exitFadeTime)
		Tween.fade(refs.Prompt, { TextTransparency = 1 }, motion.exitFadeTime)
	end)

	return slideDelay + slideTime + 0.05
end

return Reveal
