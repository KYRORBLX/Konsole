/// <reference types="@rbxts/types" />

declare namespace Konsole {

	type BooleanArgument = `${boolean}` | "yes" | "no" | "on" | "off" | "1" | "0";

	export type Argument =
		| {
				name?: string;
				type?: "string";
				default?: string;
				required?: boolean;
				suggestions?: string[] | string;
		}
		| {
				name?: string;
				type: "number";
				default?: number;
				required?: boolean;
				suggestions?: `${number}`[] | `${number}`;
		}
		| {
				name?: string;
				type: "boolean";
				default?: boolean;
				required?: boolean;
				suggestions?: BooleanArgument[] | BooleanArgument;
		}
		| {
				name?: string;
				type: "player";
				default?: never;
				required?: boolean;
		}
		| {
				name?: string;
				type: "players";
				default?: never;
				required?: boolean;
		};

	export interface Outcome {
		ok: boolean;
		code?: string;
		message: string;
	}

	export type ResultKind = "text" | "table" | "error" | "warn";

	export interface RenderResult {
		ok: boolean;
		kind: ResultKind;
		code?: string;
		title: string;
		message: string;
		width: string;
		columns?: string[];
		rows: Array<Record<string, unknown>>;
		hints?: string[];
	}

	export interface ResultOptions {
		kind?: ResultKind;
		title?: string;
		message?: string;
		width?: string;
		columns?: string[];
		rows?: Array<Record<string, unknown>>;
		hints?: string[];
	}

	export interface ResultApi {
		ok: (message?: unknown, options?: ResultOptions) => RenderResult;
		err: (code?: unknown, message?: unknown, options?: ResultOptions) => RenderResult;
		table: (
			title?: unknown,
			columns?: string[],
			rows?: Array<Record<string, unknown>>,
			options?: ResultOptions,
		) => RenderResult;
		status: (
			title?: unknown,
			rows?: Array<{ Field: unknown; Value: unknown }>,
			options?: ResultOptions,
		) => RenderResult;
		from: (value: unknown) => RenderResult;
	}

	export type ExecuteResult = Outcome | RenderResult;

	type ArgumentValue<T extends Argument> =
		T["type"] extends "number" ? number :
		T["type"] extends "boolean" ? boolean :
		T["type"] extends "player" ? Player :
		T["type"] extends "players" ? Player[] :
		string;

	export type PanelPosition =
		| UDim2
		| "br"
		| "tr"
		| "tl"
		| "bl"
		| "bc"
		| "tc"
		| "bottom right"
		| "top right"
		| "top left"
		| "bottom left"
		| "bottom center"
		| "top center";

	/**
	 * What actually reaches the callback: `parse` skips an argument entirely
	 * when it is `required: false`, has no `default`, and no token was typed —
	 * so only that combination can be undefined. Defaults are inserted raw
	 * (no conversion), and an absent `required` behaves like required.
	 */
	type ArgumentRuntimeValue<T extends Argument> = T extends { required: false }
		? T extends { default: {} }
			? ArgumentValue<T>
			: ArgumentValue<T> | undefined
		: ArgumentValue<T>;

	export type Args = ReadonlyArray<unknown>;

	/**
	 * A server implementation name whose argument tuple was captured from the
	 * `args` schema of the `define(...)` call that produced it. Passing one to
	 * `implement(...)` types the callback parameters automatically.
	 * At runtime this is a plain string.
	 */
	export type ServerName<A extends Args = Args> = string & { readonly __args: A };

	export type Run<A extends Args = Args> = (context: Context, ...args: A) => unknown;

	/** Built-in rank names ship with Konsole; custom ones can be defined via `Ranks.define`. */
	export type RankName =
		| "player"
		| "helper"
		| "trial"
		| "lowmod"
		| "moderator"
		| "mod"
		| "admin"
		| "administrator"
		| "creator"
		| "owner"
		| (string & {});

	/** Anything rank lookups accept: a Player instance or a tonumber-able user id. */
	export type RankEntity = Player | number | string | undefined;

	export type RankResolver = (entity: RankEntity) => number | undefined;

	export interface Rank {
		id: number;
		name: string;
		aliases: string[];
		builtin?: boolean;
	}

	export interface RanksModule {
		readonly define: (id: number, name: string, aliases?: string[]) => Rank;
		readonly resolve: (value: number | RankName) => number | undefined;
		readonly label: (id: number) => string;
		readonly list: () => Rank[];
		readonly set: (userId: number | string, rank: number | RankName) => number;
		readonly bind: (fn?: RankResolver) => void;
		readonly get: (entity: RankEntity) => number;
		readonly allows: (entity: RankEntity, required: number | RankName) => boolean;
	}

	export interface DispatchModule {
		readonly remoteName: string;
		readonly definitionsRemoteName: string;
		readonly timeout: number;
		readonly host: (serverImplementations?: Record<string, Run<Array<any>>>) => RemoteFunction | undefined;
		readonly implement: (name: string, callback: Run<Array<any>>) => void;
		readonly execute: (text: string, entity?: RankEntity) => ExecuteResult;
	}

	export interface KommandModule {
		readonly define: (definition: Definition) => Command;
		readonly find: (name: string) => Command | undefined;
		readonly list: () => Command[];
		readonly schemas: () => Record<string, Argument[]>;
		readonly suggestions: () => string[];
		readonly watch: (fn?: () => void) => void;
	}

	/**
	 * Converts one typed token. Returns `[true, value]` on success or
	 * `[false, errorMessage]` on failure.
	 */
	export type Converter = (token: string, caller?: Player) => LuaTuple<[boolean, unknown]>;

	export interface ArgumentsModule {
		/** Built-in converter registry (`string`, `number`, `boolean`, `player`, `players`). */
		readonly types: Record<string, Converter>;
		readonly tokenize: (text?: string) => string[];
		readonly split: (text?: string) => LuaTuple<[string | undefined, string[]]>;
		readonly parse: (
			argDefinitions: Argument[] | undefined,
			tokens: string[],
			caller?: Player,
		) => LuaTuple<[boolean, unknown]>;
	}

	export interface ChatModule {
		readonly bindKonsoleOpen: (callback: () => void) => () => void;
		readonly unbindKonsoleOpen: () => void;
	}

	export interface ConfigGroups {
		panel: {
			position: PanelPosition;

			width: number;
			outputWidth: number;
			wideWidth: number;
			maxWidth: number;
			collapsedWidth: number;
			addChatCollapsedWidth: number;
			addChatHoverWidth: number;
			height: number;
			inputHeight: number;
			commandHeight: number;
			historyLineHeight: number;
			historyChunkLines: number;
			historyMaxHeight: number;
			stackHistoryMaxHeight: number;
			viewportTopInset: number;
			suggestionHeight: number;
			suggestionGap: number;
			suggestionRadius: number;
			maxSuggestions: number;
			hintHeight: number;
			outputRadius: number;
			bottomInset: number;
			displayOrder: number;
			shadowAssetId: string;
			arrowAssetId: string;
			addChatAssetId: string;
			stackGap: number;
		};
		color: {
			panel: Color3;
			inputText: Color3;
			promptText: Color3;
			suggPanel: Color3;
			suggText: Color3;
			suggMatch: string;
			suggSub: string;
			hintGhost: Color3;
			successRich: string;
			successText: Color3;
			errorRich: string;
			errorText: Color3;
			warnRich: string;
			warnText: Color3;
			mutedRich: string;
			mutedText: Color3;
			shadowColor: Color3;
		};
		motion: {
			expandSmoothTime: number;
			openSmoothTime: number;
			openSlideOffset: number;
			outputSmoothTime: number;
			listSmoothTime: number;
			textFadeTime: number;
			textSlideOffset: number;
			itemSlideSmoothTime: number;
			collapseSmoothTime: number;
			exitFadeTime: number;
			hintFadeTime: number;
			hintSlideTime: number;
		};
		layout: {
			paddingX: number;
			paddingY: number;
			promptSize: number;
			textSize: number;
			suggTextSize: number;
			hintTextSize: number;
			hintOffsetY: number;
			itemGap: number;
		};
		transparency: {
			panel: number;
			suggPanel: number;
			shadow: number;
			arrow: number;
			text: number;
			suggText: number;
			dimText: number;
		};
		input: {
			activationKeys: Enum.KeyCode[];
			activationPriority: number;
			forceclose: boolean;
			command: string;
			alias: string;
		};
		font: {
			body: Enum.Font;
			title: Enum.Font;
			mono: Enum.Font;
		};
		commands: {
			defaultLimit: number;
			aliases: Record<string, string>;
		};
	}

	export type ConfigOverrides = {
		[K in keyof ConfigGroups]?: Partial<ConfigGroups[K]>;
	};

	export interface ConfigModule {
		readonly groups: ConfigGroups;
		readonly merge: (options?: ConfigOverrides) => ConfigGroups;
	}

	export interface RenderModule {
		readonly Result: ResultApi;
		readonly Formatter: unknown;
		readonly Text: unknown;
		readonly config: (options?: ConfigOverrides) => ConfigGroups;
		readonly new: (options?: ConfigOverrides) => Client;
	}

	type RunArgs<T extends readonly Argument[]> = number extends T["length"]
		? []
		: { [K in keyof T]: ArgumentRuntimeValue<T[K]> };

	export interface Definition<
		T extends readonly Argument[] = readonly Argument[],
		S extends string | undefined = string | undefined,
	> {
		name: string;
		rank?: number | RankName;
		aliases?: string[];
		args?: T & readonly Argument[];
		description?: string;
		cooldown?: number;
		server?: S;
		run?: (context: Context, ...args: RunArgs<T>) => unknown;
	}

	export interface Command<A extends Args = Args, S extends string | undefined = string | undefined> {
		name: string;
		rank: number;
		aliases: string[];
		args: Argument[];
		description: string;
		cooldown: number;
		server: S extends string ? ServerName<A> : undefined;
		run?: Run<A>;
	}

	export interface Context {
		entity?: Player;
		kommand: Command;
		text: string;
		dispatch: DispatchModule;
		ranks: RanksModule;
		run: (text: string) => ExecuteResult;
		reply: (message?: unknown) => Outcome;
		err: (code?: unknown, message?: unknown) => Outcome;
	}

	/**
	 * A console client returned by `Konsole.create(...)`. Its members are
	 * colon-methods on the Luau side, so they are declared as methods here —
	 * roblox-ts emits `client:show()` style calls for them.
	 */
	export interface Client {
		bindRun(callback: (text: string) => unknown): void;
		clear(): void;
		destroy(): void;
		focus(): void;
		getCursorTarget(): Instance | undefined;
		hide(): void;
		setActivationKeys(keys: Enum.KeyCode[]): void;
		setActivationUnlocksMouse(enabled: boolean): void;
		setEnabled(enabled: boolean): void;
		setMouseUnlockDriver(getFn?: () => boolean, setFn?: (enabled: boolean) => void): void;
		setSchemas(map: Record<string, Argument[]>): void;
		setSuggestions(list: string[]): void;
		show(): void;
		toggle(): void;
	}

	/**
	 * The top-level API. Unlike `Client`, these are dot-functions on the Luau
	 * side (they delegate to a lazily created default client), so they are
	 * declared as function properties — roblox-ts emits `Konsole.show()`.
	 */
	export interface Api {
		Arguments: ArgumentsModule;
		Chat: ChatModule;
		Config: ConfigModule;
		Dispatch: DispatchModule;
		Kommand: KommandModule;
		Ranks: RanksModule;
		Render: RenderModule;
		Result: ResultApi;

		bindRanks: (resolver?: RankResolver) => void;
		create: (options?: ConfigOverrides) => Client;
		define: <const T extends readonly Argument[] = readonly Argument[], S extends string | undefined = undefined>(
			definition: Definition<T, S>,
		) => Command<RunArgs<T>, S>;
		getRank: (entity: RankEntity) => number;
		host: (serverImplementations?: Record<string, Run<Array<any>>>) => RemoteFunction | undefined;
		implement: {
			<A extends Args>(name: ServerName<A>, callback: (context: Context, ...args: A) => unknown): void;
			<T extends Args = Args>(name: string, callback: (context: Context, ...args: T) => unknown): void;
		};
		run: (text: string) => ExecuteResult;
		setRank: (userId: number | string, rank: number | RankName) => number;

		bindRun: (callback: (text: string) => unknown) => void;
		clear: () => void;
		destroy: () => void;
		focus: () => void;
		getCursorTarget: () => Instance | undefined;
		hide: () => void;
		setActivationKeys: (keys: Enum.KeyCode[]) => void;
		setActivationUnlocksMouse: (enabled: boolean) => void;
		setEnabled: (enabled: boolean) => void;
		setMouseUnlockDriver: (getFn?: () => boolean, setFn?: (enabled: boolean) => void) => void;
		setSchemas: (map: Record<string, Argument[]>) => void;
		setSuggestions: (list: string[]) => void;
		show: () => void;
		toggle: () => void;
	}
}

declare const Konsole: Konsole.Api;
export = Konsole;
