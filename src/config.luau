--[[
	@name config
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

export type FontGroup = {
	title: Enum.Font,
	body: Enum.Font,
	mono: Enum.Font,
}

export type PanelGroup = {
	addChatCollapsedWidth: number,
	historyChunkLines: number,
	addChatHoverWidth: number,

	suggestionHeight: number,
	maxSuggestions: number,
	suggestionRadius: number,
	collapsedWidth: number,

	historyLineHeight: number,
	viewportTopInset: number,
	commandHeight: number,

	historyMaxHeight: number,
	displayOrder: number,
	outputWidth: number,

	suggestionGap: number,
	shadowAssetId: string,
	inputHeight: number,
	
	addChatAssetId: string,
	arrowAssetId: string,
	wideWidth: number,

	outputRadius: number,
	stackGap: number,
	maxWidth: number,

	height: number,
	width: number,
}

export type LayoutGroup = {
	suggTextSize: number,
	hintTextSize: number,
	promptSize: number,

	hintOffsetY: number,
	textSize: number,
	paddingX: number,

	paddingY: number,
	itemGap: number,
}

export type MotionGroup = {
	itemSlideSmoothTime: number,
	collapseSmoothTime: number,
	outputSmoothTime: number,

	openSlideOffset: number,
	openSmoothTime: number,
	listSmoothTime: number,

	expandSmoothTime: number,
	textSlideOffset: number,
	hintSlideTime: number,

	textFadeTime: number,
	exitFadeTime: number,
	hintFadeTime: number,
}

export type InputGroup = {
	activationKeys: { Enum.KeyCode },
	
	activationPriority: number,
	forceclose: boolean,

	command: string,
	alias: string,
}

export type ColorGroup = {
	successText: Color3,
	shadowColor: Color3,
	promptText: Color3,

	successRich: string,
	inputText: Color3,
	mutedText: Color3,

	errorText: Color3,
	hintGhost: Color3,
	suggPanel: Color3,

	mutedRich: string,
	errorRich: string,
	warnText: Color3,

	suggMatch: string,
	suggText: Color3,
	panel: Color3,

	warnRich: string,
	suggSub: string,
}

export type TransparencyGroup = {
	suggPanel: number,
	suggText: number,
	dimText: number,

	shadow: number,
	panel: number,
	arrow: number,

	text: number,
}

export type CommandsGroup = {
	defaultLimit: number,
	aliases: { [string]: string },
}

export type MergedConfig = {
	transparency: TransparencyGroup,
	commands: CommandsGroup,
	motion: MotionGroup,

	layout: LayoutGroup,
	panel: PanelGroup,
	color: ColorGroup,

	input: InputGroup,
	font: FontGroup,
}

export type ConfigOverrides = { [string]: { [string]: any } }

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
		shadowAssetId = "1316045217",
		addChatAssetId = "6035047391",
		arrowAssetId = "6031104654",

		displayOrder = 8241,
	}),

	color = {
		successText = rgb(137, 255, 126),
		promptText = rgb(210, 210, 210),
		inputText = rgb(255, 255, 255),

		mutedText = rgb(159, 159, 159),
		errorText = rgb(255, 126, 126),
		shadowColor = rgb(0, 0, 0),
		panel = rgb(0, 0, 0),

		hintGhost = rgb(110, 110, 110),
		suggText = rgb(238, 238, 238),
		warnText = rgb(255, 211, 106),
		suggPanel = rgb(8, 8, 8),
		
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
		openSlideOffset = 44,
		hintSlideTime = 0.34,

		listSmoothTime = 0.28,
		textSlideOffset = 10,
		hintFadeTime = 0.22,

		openSmoothTime = 0.46,
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
