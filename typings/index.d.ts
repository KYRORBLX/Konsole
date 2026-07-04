/// <reference types="@rbxts/types" />

declare namespace Konsole {
	export interface Argument {
		name?: string;
		type?: string;
		default?: unknown;
		required?: boolean;
		suggestions?: string[] | string;
	}

	export interface Outcome {
		ok: boolean;
		code?: string;
		message: string;
	}

	export type Run = (context: Context, ...args: unknown[]) => unknown;
	export type RankResolver = (entity: unknown) => number | undefined;
	export type ConfigOverrides = Record<string, Record<string, unknown>>;

	export interface Definition {
		name: string;
		rank?: number | string;
		aliases?: string[];
		args?: Argument[];
		description?: string;
		cooldown?: number;
		server?: string;
		run?: Run;
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
		define: (definition: Definition) => Command;
		getRank: (entity: unknown) => number;
		host: (serverImplementations?: Record<string, Run>) => RemoteFunction | undefined;
		implement: (name: string, callback: Run) => void;
		run: (text: string) => Outcome;
		setRank: (userId: unknown, rank: unknown) => number;
	}
}

declare const Konsole: Konsole.Api;
export = Konsole;
