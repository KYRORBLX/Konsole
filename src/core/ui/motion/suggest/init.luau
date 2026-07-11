--[[
	@name suggest
	@author driftingAurora, dullflowerr
	@time June 13, 2026
]]

--// imports
local imports = {
	View = require("../elements/misc/view"),
	Math = require("./math"),
}

local Tween = imports.Math.tween

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

	suggList.Visible = true
	suggList.Position = UDim2.new(0.5, 0, 0, -1)
	if typeof(refs.suggShadow) == "Instance" then
		refs.suggShadow.Visible = not session.isClosing
		refs.suggShadow.ImageTransparency = 1
		imports.View.setShadowBounds(refs.suggShadow, suggList)
		Tween.to(refs.suggShadow, {
			ImageTransparency = config.transparency.shadow,
		}, config.motion.listSmoothTime)
	end
	Tween.to(suggList, {
		Position = UDim2.new(0.5, 0, 0, -panel.suggestionGap),
		Size = UDim2.fromOffset(session:activeWidth(), (count * panel.suggestionHeight) + 4),
		BackgroundTransparency = config.transparency.suggPanel,
	}, config.motion.listSmoothTime)
end

function Suggest.hide(session)
	local refs = session.refs
	local config = session.config
	local suggList = refs.suggList
	local token = session.suggestToken
	local slide = config.motion.textSlideOffset or 10

	for _, child in suggList:GetChildren() do
		if child:IsA("TextButton") then
			Tween.to(child:FindFirstChild("Label"), {
				Position = UDim2.new(0, config.layout.paddingX, 0, 1 + slide),
				TextTransparency = 1,
			}, config.motion.itemSlideSmoothTime)
		end
	end

	if typeof(refs.suggShadow) == "Instance" then
		imports.View.setShadowBounds(refs.suggShadow, suggList)
		refs.suggShadow.Visible = not session.isClosing
		Tween.to(refs.suggShadow, { ImageTransparency = 1 }, config.motion.listSmoothTime)
	end
	Tween.to(suggList, {
		Position = UDim2.new(0.5, 0, 0, config.panel.suggestionGap),
		Size = UDim2.fromOffset(session:activeWidth(), 0),
		BackgroundTransparency = 1,
	}, config.motion.listSmoothTime)

	task.delay(config.motion.exitFadeTime, function()
		if token ~= session.suggestToken or typeof(suggList) ~= "Instance" then
			return
		end
		suggList.Visible = false
		session.suggestionsHiding = false
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
