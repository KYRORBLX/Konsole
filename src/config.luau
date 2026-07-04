--[[
	@name config
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

export type FontGroup = {
	body: Enum.Font,
	title: Enum.Font,
	mono: Enum.Font,
}

export type PanelGroup = {
	width: number,
	outputWidth: number,
	wideWidth: number,
	maxWidth: number,
	collapsedWidth: number,
	addChatCollapsedWidth: number,
	addChatHoverWidth: number,
	height: number,
	inputHeight: number,
	commandHeight: number,
	historyLineHeight: number,
	historyChunkLines: number,
	historyMaxHeight: number,
	stackHistoryMaxHeight: number,
	viewportTopInset: number,
	suggestionHeight: number,
	suggestionGap: number,
	suggestionRadius: number,
	maxSuggestions: number,
	hintHeight: number,
	outputRadius: number,
	bottomInset: number,
	displayOrder: number,
	shadowAssetId: string,
	arrowAssetId: string,
	addChatAssetId: string,
	stackGap: number,
}

export type LayoutGroup = {
	paddingX: number,
	paddingY: number,
	promptSize: number,
	textSize: number,
	suggTextSize: number,
	hintTextSize: number,
	hintOffsetY: number,
	itemGap: number,
}

export type MotionGroup = {
	expandSmoothTime: number,
	openSmoothTime: number,
	openSlideOffset: number,
	outputSmoothTime: number,
	listSmoothTime: number,
	textFadeTime: number,
	textSlideOffset: number,
	itemSlideSmoothTime: number,
	collapseSmoothTime: number,
	exitFadeTime: number,
	hintFadeTime: number,
	hintSlideTime: number,
}

export type InputGroup = {
	activationKeys: { Enum.KeyCode },
	activationPriority: number,
	forceclose: boolean,
	command: string,
	alias: string,
}

export type ColorGroup = {
	panel: Color3,
	inputText: Color3,
	promptText: Color3,
	suggPanel: Color3,
	suggText: Color3,
	suggMatch: string,
	suggSub: string,
	hintGhost: Color3,
	successRich: string,
	successText: Color3,
	errorRich: string,
	errorText: Color3,
	warnRich: string,
	warnText: Color3,
	mutedRich: string,
	mutedText: Color3,
	shadowColor: Color3,
}

export type TransparencyGroup = {
	panel: number,
	suggPanel: number,
	shadow: number,
	arrow: number,
	text: number,
	suggText: number,
	dimText: number,
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

local INF = 100000
local rgb = Color3.fromRGB

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
		outputWidth = 338,
		collapsedWidth = 204,
		width = 252,
		height = 34,
	}, {
		stackHistoryMaxHeight = 190,
		historyLineHeight = 14,
		historyChunkLines = 90,
		historyMaxHeight = 340,
		viewportTopInset = 24,
		commandHeight = 14,
		bottomInset = 24,
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
		inputText = rgb(255, 255, 255),
		promptText = rgb(210, 210, 210),
		successText = rgb(137, 255, 126),
		errorText = rgb(255, 126, 126),
		shadowColor = rgb(0, 0, 0),
		mutedText = rgb(159, 159, 159),
		suggText = rgb(238, 238, 238),
		hintGhost = rgb(110, 110, 110),
		suggPanel = rgb(8, 8, 8),
		warnText = rgb(255, 211, 106),
		successRich = "#89FF7E",
		errorRich = "#FF7E7E",
		mutedRich = "#9F9F9F",
		warnRich = "#FFD36A",
		suggMatch = "#FFFFFF",
		suggSub = "#CFCFCF",
		panel = rgb(0, 0, 0),
	},

	motion = {
		itemSlideSmoothTime = 0.30,
		collapseSmoothTime = 0.38,
		expandSmoothTime = 0.34,
		openSlideOffset = 44,
		outputSmoothTime = 0.24,
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
		promptSize = 13,
		paddingX = 12,
		paddingY = 5,
		textSize = 14,
		itemGap = 6,
	},

	transparency = {
		suggPanel = 0.42,
		suggText = 0,
		dimText = 0.18,
		shadow = 0.80,
		panel = 0.50,
		arrow = 0.35,
		text = 0,
	},

	input = {
		activationKeys = { Enum.KeyCode.T },
		command = "KonsoleOpenCommand",
		activationPriority = 10001,
		forceclose = false,
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
