--!strict

--[[
	@name uiTypes
	@author driftingAurora, dullflowerr, alias; kioukaii
	@time June 30, 2026
]]

local Types = require("./sharedTypes")

--// types
export type ResultKind = "text" | "table" | "error" | "warn"

export type RenderResult = {
	rows: { { [string]: any } },
	code: string?,
	ok: boolean,

	columns: { string }?,
	hints: { string }?,
	kind: ResultKind,

	message: string,
	title: string,
	width: string,
}

export type ResultOptions = {
	columns: { string }?,
	message: string?,

	title: string?,
	width: string?,

	hints: { string }?,
	kind: ResultKind?,

	rows: { { [string]: any } }?,
}

export type HistoryItemKind = "cmd" | "ok" | "warn" | "err"

export type HistoryItem = {
	kind: HistoryItemKind,
	wide: boolean?,
	text: string,
}

export type DisplayLine = {
	plain: string,
	chars: number,
	width: number,

	rich: string,
}

export type PlacementPreset =
	"br"
	| "tr"
	| "tl"
	| "bl"
	| "bc"
	| "tc"
	| "bottom center"
	| "bottom right"
	| "bottom left"
	| "top center"
	| "top right"
	| "top left"

export type PanelPosition = UDim2 | PlacementPreset

export type FontGroup = {
	title: Enum.Font,
	body: Enum.Font,
	mono: Enum.Font,
}

export type PanelGroup = {
	addChatCollapsedWidth: number,
	historyChunkLines: number,
	addChatHoverWidth: number,

	historyLineHeight: number,
	suggestionHeight: number,
	suggestionRadius: number,

	viewportTopInset: number,
	historyMaxHeight: number,
	position: PanelPosition,
	maxSuggestions: number,

	collapsedWidth: number,
	addChatAssetId: string,
	commandHeight: number,

	suggestionGap: number,
	shadowAssetId: string,
	displayOrder: number,

	arrowAssetId: string,
	outputRadius: number,
	outputWidth: number,

	inputHeight: number,
	wideWidth: number,
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

	expandSmoothTime: number,
	openSlideOffset: number,
	textSlideOffset: number,

	openSmoothTime: number,
	listSmoothTime: number,
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
	successRich: string,

	promptText: Color3,
	inputText: Color3,
	mutedText: Color3,

	errorText: Color3,
	hintGhost: Color3,
	suggPanel: Color3,

	mutedRich: string,
	errorRich: string,
	suggMatch: string,

	warnText: Color3,
	suggText: Color3,
	warnRich: string,

	suggSub: string,
	panel: Color3,
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

export type Config = {
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

export type Schemas = Types.Schemas
export type MouseUnlockGetter = () -> boolean

export type MouseUnlockSetter = (boolean) -> ()
export type Runner = (string) -> unknown

export type SessionSnapshot = {
	secondPosition: UDim2?,
	position: UDim2?,
}

export type Session = {
	bindSubmit: (Session, (string, number) -> ()) -> (),
	bindCloseRequest: (Session, () -> ()) -> (),

	appendResult: (Session, RenderResult, number) -> (),
	restoreSnapshot: (Session, SessionSnapshot?) -> (),
	appendPending: (Session, string, number) -> (),

	setSuggestions: (Session, { string }) -> (),
	setSchemas: (Session, Schemas) -> (),

	getCursorTarget: (Session) -> GuiObject?,
	snapshot: (Session) -> SessionSnapshot,

	clear: (Session, number?) -> (),
	closeSecond: (Session) -> (),
	destroy: (Session) -> (),
	focus: (Session) -> (),
}

export type SessionConstructor = (ScreenGui, Config, UDim2?, UDim2?) -> Session?

export type ControllerState = {
	previousMouseBehavior: Enum.MouseBehavior?,
	previousChatWindowEnabled: boolean?,
	previousMouseIconEnabled: boolean?,

	mouseUnlockSet: MouseUnlockSetter?,
	previousChatInputEnabled: boolean?,
	mouseUnlockGet: MouseUnlockGetter?,

	previousMouseUnlocked: boolean?,
	savedSession: SessionSnapshot?,
	session: Session?,

	runner: Runner?,
	gui: ScreenGui?,

	activationKeys: { Enum.KeyCode },
	toggleActionName: string?,

	activationUnlocksMouse: boolean,
	enabled: boolean,
	open: boolean,

	config: Config,

	suggestions: { string },
	schemas: Schemas,
}

export type Controller = ControllerState & {
	writeMouseUnlocked: (Controller, boolean) -> (),
	setChatSuppressed: (Controller, boolean) -> (),

	setMouseUnlocked: (Controller, boolean) -> (),
	readMouseUnlocked: (Controller) -> boolean,

	ensureGui: (Controller) -> ScreenGui?,
	invoke: (Controller, string) -> RenderResult,

	setSuggestions: (Controller, { string }) -> (),
	setSchemas: (Controller, Schemas) -> (),
	bindRun: (Controller, Runner?) -> (),

	toggle: (Controller) -> (),
	focus: (Controller) -> (),
	clear: (Controller) -> (),

	show: (Controller) -> (),
	hide: (Controller) -> (),

	setActivationKeys: (Controller, { Enum.KeyCode }) -> (),
	getCursorTarget: (Controller) -> GuiObject?,
	setEnabled: (Controller, boolean) -> (),

	setMouseUnlockDriver: (Controller, MouseUnlockGetter?, MouseUnlockSetter?) -> (),
	setActivationUnlocksMouse: (Controller, boolean) -> (),
	destroy: (Controller) -> (),
}

export type ViewProperties = { [string]: any }
export type ViewMake = <T>(className: string, props: ViewProperties?, parent: Instance?) -> T

export type TargetChanged = (UDim2) -> ()
export type DragMoved = () -> ()

export type DraggingBinding = {
	setEnabled: (boolean) -> (),
	setPosition: (UDim2) -> (),
}

export type SessionRefs = {
	[string]: any,

	secondCommandRow: ScrollingFrame,
	secondDragging: DraggingBinding,
	mainDragging: DraggingBinding,

	secondCommandText: TextLabel,
	SecondPlaceholder: TextLabel,

	secondHistoryContent: Frame?,
	SecondArrowIcon: ImageLabel,
	secondPillCorner: UICorner,

	commandRow: ScrollingFrame,
	suggList: ScrollingFrame,
	secondShadow: ImageLabel,

	addChatPill: TextButton,
	addChatIcon: ImageLabel,
	stackShadow: ImageLabel,

	SecondInputBox: TextBox,
	SecondPrompt: TextLabel,
	addChatText: TextLabel,

	pillShadow: ImageLabel,
	suggShadow: ImageLabel,
	commandText: TextLabel,

	Placeholder: TextLabel,
	historyContent: Frame?,
	ArrowIcon: ImageLabel,

	pillCorner: UICorner,
	SecondHintRow: Frame,
	pillBtn: TextButton,

	pillPad: UIPadding,
	secondRoot: Frame,

	secondPill: Frame,
	InputBox: TextBox,
	Prompt: TextLabel,

	HintRow: Frame,
	root: Frame,

	pill: Frame,
}

export type HintChip = {
	arg: Types.Argument,
	name: TextLabel,

	frame: Frame,
	box: TextBox,
}

export type ActiveHintChip = {
	arg: Types.Argument,
	channel: number,

	index: number,
	box: TextBox,
}

export type FormatterColors = { [string]: string }
export type FormatterRows = { { [string]: any } }

export type EaseGroup = {
	direction: Enum.EasingDirection,
	style: Enum.EasingStyle,
	soft: Enum.EasingStyle,
}

export type ScrollState = {
	target: number,
	tween: Tween?,
}

export type Client = Controller

return {}
