/// <reference types="@rbxts/types" />

declare namespace Konsole {

	type BooleanArgument = `${boolean}` | "yes" | "no" | "on" | "off" | "1" | "0";
	
	export type Argument =
		| {
				name?: string;
				type: "string";
				default?: string;
				required?: boolean;
				suggestions?: string[] | string;
		}
		| {
				name?: string;
				type: "number";
				default?: number | `${number}`;
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

	type ArgumentValue<T extends Argument> =
		T["type"] extends "string" ? string :
		T["type"] extends "number" ? number :
		T["type"] extends "boolean" ? boolean :
		T["type"] extends "player" ? Player :
		T["type"] extends "players" ? Player[] :
		never;

	export type Run = (context: Context, ...args: unknown[]) => unknown;
	export type RankResolver = (entity: unknown) => number | undefined;
	export type ConfigOverrides = Record<string, Record<string, unknown>>;

	type RunArgs<T extends readonly Argument[]> = {
		[K in keyof T]: ArgumentValue<T[K]>;
	};

	export interface Definition<T extends readonly Argument[] = readonly Argument[]> {
		name: string;
		rank?: number | string;
		aliases?: string[];
		args?: T;
		description?: string;
		cooldown?: number;
		server?: string;
		run?: (context: Context, ...args: RunArgs<T>) => unknown;
	}

	export interface Command {
		name: string;
		rank: number;
		aliases: string[];
		args: Argument[];
		description: string;
		cooldown: number;
		server?: string;
		run?: Run;
	}

	export interface Context {
		entity?: Player;
		kommand: Command;
		text: string;
		dispatch: unknown;
		ranks: unknown;
		run: (text: unknown) => unknown;
		reply: (message?: unknown) => Outcome;
		err: (code?: unknown, message?: unknown) => Outcome;
	}

	export interface Client {
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
		setSchemas: (map: Record<string, unknown>) => void;
		setSuggestions: (list: string[]) => void;
		show: () => void;
		toggle: () => void;
	}

	export interface Api extends Client {
		Arguments: unknown;
		Chat: unknown;
		Config: unknown;
		Dispatch: unknown;
		Kommand: unknown;
		Ranks: unknown;
		Render: unknown;
		Result: unknown;
		bindRanks: (resolver?: RankResolver) => void;
		create: (options?: ConfigOverrides) => Client;
		define: <const T extends readonly Argument[]>(
			definition: Definition<T>,
		) => Command;
		getRank: (entity: unknown) => number;
		host: (serverImplementations?: Record<string, Run>) => RemoteFunction | undefined;
		implement: (name: string, callback: Run) => void;
		run: (text: string) => Outcome;
		setRank: (userId: unknown, rank: unknown) => number;
	}
}

declare const Konsole: Konsole.Api;
export = Konsole;
