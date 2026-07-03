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
	font: FontGroup,
	panel: PanelGroup,
	layout: LayoutGroup,
	motion: MotionGroup,
	input: InputGroup,
	color: ColorGroup,
	transparency: TransparencyGroup,
	commands: CommandsGroup,
}

export type ConfigOverrides = { [string]: { [string]: any } }

local Config = {}

Config.groups = {
	font = {
		body = Enum.Font.BuilderSans,
		title = Enum.Font.BuilderSansBold,
		mono = Enum.Font.Code,
	},

	panel = {
		width = 252,
		outputWidth = 338,
		wideWidth = 100000,
		maxWidth = 100000,
		collapsedWidth = 204,
		addChatCollapsedWidth = 42,
		addChatHoverWidth = 204,
		height = 34,
		inputHeight = 24,
		commandHeight = 14,
		historyLineHeight = 14,
		historyChunkLines = 90,
		historyMaxHeight = 340,
		stackHistoryMaxHeight = 190,
		viewportTopInset = 24,
		suggestionHeight = 26,
		suggestionGap = 8,
		suggestionRadius = 10,
		maxSuggestions = 5,
		hintHeight = 17,
		outputRadius = 12,
		bottomInset = 24,
		displayOrder = 8241,
		shadowAssetId = "1316045217",
		arrowAssetId = "6031104654",
		addChatAssetId = "6035047391",
		stackGap = 8,
	},

	layout = {
		paddingX = 12,
		paddingY = 5,
		promptSize = 13,
		textSize = 14,
		suggTextSize = 13,
		hintTextSize = 14,
		hintOffsetY = 1,
		itemGap = 6,
	},

	motion = {
		expandSmoothTime = 0.34,
		openSmoothTime = 0.46,
		openSlideOffset = 44,
		outputSmoothTime = 0.24,
		listSmoothTime = 0.28,
		textFadeTime = 0.34,
		textSlideOffset = 10,
		itemSlideSmoothTime = 0.30,
		collapseSmoothTime = 0.38,
		exitFadeTime = 0.34,
		hintFadeTime = 0.22,
		hintSlideTime = 0.34,
	},

	input = {
		activationKeys = { Enum.KeyCode.T },
		activationPriority = 10001,
	},

	color = {
		panel = Color3.fromRGB(0, 0, 0),
		inputText = Color3.fromRGB(255, 255, 255),
		promptText = Color3.fromRGB(210, 210, 210),
		suggPanel = Color3.fromRGB(8, 8, 8),
		suggText = Color3.fromRGB(238, 238, 238),
		suggMatch = "#FFFFFF",
		suggSub = "#CFCFCF",
		hintGhost = Color3.fromRGB(110, 110, 110),
		successRich = "#89FF7E",
		successText = Color3.fromRGB(137, 255, 126),
		errorRich = "#FF7E7E",
		errorText = Color3.fromRGB(255, 126, 126),
		warnRich = "#FFD36A",
		warnText = Color3.fromRGB(255, 211, 106),
		mutedRich = "#9F9F9F",
		mutedText = Color3.fromRGB(159, 159, 159),
		shadowColor = Color3.fromRGB(0, 0, 0),
	},

	transparency = {
		panel = 0.50,
		suggPanel = 0.42,
		shadow = 0.80,
		arrow = 0.35,
		text = 0,
		suggText = 0,
		dimText = 0.18,
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
		local merged: { [string]: any } = table.clone(group)
		local overrides = type(options) == "table" and (options :: ConfigOverrides)[name]
		if type(overrides) == "table" then
			for key, value in overrides do
				merged[key] = value
			end
		end
		config[name] = merged
	end

	return (config :: any) :: MergedConfig
end

return Config
