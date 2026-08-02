--!strict

--[[
	@name config
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 12, 2026
]]

local Types = require("./types/uiTypes")

export type TransparencyGroup = Types.TransparencyGroup
export type ConfigOverrides = Types.ConfigOverrides
export type PanelPosition = Types.PanelPosition

export type CommandsGroup = Types.CommandsGroup
export type LayoutGroup = Types.LayoutGroup
export type MotionGroup = Types.MotionGroup

export type InputGroup = Types.InputGroup
export type ColorGroup = Types.ColorGroup
export type PanelGroup = Types.PanelGroup

export type MergedConfig = Types.Config
export type FontGroup = Types.FontGroup

local rgb = Color3.fromRGB
local INF = 100000

local function flat(...)
	local out = {}
	for _, part in { ... } do
		for key, value in part do
			out[key] = value
		end
	end
	return out
end

local Config = {}

Config.groups = {
	panel = flat({
		position = "bc", -- use a udim2 or a preset like "bottom center"

		wideWidth = INF,
		maxWidth = INF,

		collapsedWidth = 204,
		outputWidth = 338,
		width = 252,
		height = 34,
	}, {
		historyLineHeight = 14,
		historyChunkLines = 90,
		historyMaxHeight = 340,

		viewportTopInset = 24,
		commandHeight = 14,
		inputHeight = 24,
	}, {
		addChatCollapsedWidth = 42,
		addChatHoverWidth = 204,
		suggestionRadius = 10,

		suggestionHeight = 26,
		maxSuggestions = 5,
		suggestionGap = 8,

		outputRadius = 12,
		hintHeight = 17,

		stackGap = 8,
	}, {
		addChatAssetId = "6035047391",
		shadowAssetId = "1316045217",
		arrowAssetId = "6031104654",

		displayOrder = 8241,
	}),

	color = {
		successText = rgb(137, 255, 126),
		promptText = rgb(210, 210, 210),
		inputText = rgb(255, 255, 255),

		hintGhost = rgb(110, 110, 110),
		mutedText = rgb(159, 159, 159),
		errorText = rgb(255, 126, 126),

		suggText = rgb(238, 238, 238),
		warnText = rgb(255, 211, 106),
		shadowColor = rgb(0, 0, 0),

		suggPanel = rgb(8, 8, 8),
		panel = rgb(0, 0, 0),
		
		successRich = "#89FF7E",
		errorRich = "#FF7E7E",
		mutedRich = "#9F9F9F",

        suggMatch = "#FFFFFF",
        warnRich = "#FFD36A",
		suggSub = "#CFCFCF",
	},

	motion = {
		itemSlideSmoothTime = 0.30,
		collapseSmoothTime = 0.38,
		expandSmoothTime = 0.34,

		outputSmoothTime = 0.24,
		listSmoothTime = 0.28,

		openSmoothTime = 0.46,
		openSlideOffset = 44,
		hintSlideTime = 0.34,

		textSlideOffset = 10,
		hintFadeTime = 0.22,

		textFadeTime = 0.34,
		exitFadeTime = 0.34,
	},

	layout = {
		suggTextSize = 13,
		hintTextSize = 14,
		hintOffsetY = 1,

		paddingX = 12,
		paddingY = 5,

		promptSize = 13,
		textSize = 14,
		itemGap = 6,
	},

	transparency = {
		suggPanel = 0.42,
		dimText = 0.18,
		shadow = 0.80,

		suggText = 0,
		panel = 0.50,
		arrow = 0.35,

		text = 0,
	},

	input = {
		activationKeys = { Enum.KeyCode.T },
		forceclose = false,

		activationPriority = 10001,

		command = "KonsoleOpenCommand",
		alias = "/konsole",
	},

	font = {
		title = Enum.Font.BuilderSansBold,
		body = Enum.Font.BuilderSans,
		mono = Enum.Font.Code,
	},

	commands = {
		defaultLimit = 12,
		aliases = {},
	},
} :: MergedConfig

function Config.merge(options: ConfigOverrides?): MergedConfig
	local config: { [string]: any } = {}
	local groups: { [string]: any } = Config.groups :: any

	for name, group in groups do
		local merged = table.clone(group)
		local override = type(options) == "table" and (options :: ConfigOverrides)[name]
		if type(override) == "table" then
			for key, value in override do
				merged[key] = value
			end
		end
		config[name] = merged
	end

	return (config :: any) :: MergedConfig
end

return Config
