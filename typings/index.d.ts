/// <reference types="@rbxts/types" />

interface KonsoleArgument {
	name?: string;
	type?: string;
	default?: unknown;
	required?: boolean;
	suggestions?: string[] | string;
}

interface KonsoleOutcome {
	ok: boolean;
	code?: string;
	message: string;
}

interface KonsoleContext {
	entity?: Player;
	kommand: KonsoleCommand;
	text: string;
	dispatch: unknown;
	ranks: unknown;
	run(text: unknown): unknown;
	reply(message?: unknown): KonsoleOutcome;
	err(code?: unknown, message?: unknown): KonsoleOutcome;
}

type KonsoleRun = (context: KonsoleContext, ...args: unknown[]) => unknown;

interface KonsoleDefinition {
	name: string;
	rank?: number | string;
	aliases?: string[];
	args?: KonsoleArgument[];
	description?: string;
	cooldown?: number;
	server?: string;
	run?: KonsoleRun;
}

interface KonsoleCommand extends Required<Omit<KonsoleDefinition, "rank" | "aliases" | "args" | "description" | "cooldown">> {
	rank: number;
	aliases: string[];
	args: KonsoleArgument[];
	description: string;
	cooldown: number;
	server?: string;
	run?: KonsoleRun;
}

interface KonsoleApi {
	Arguments: unknown;
	Config: unknown;
	Dispatch: unknown;
	Kommand: unknown;
	Ranks: unknown;
	Render: unknown;
	Result: unknown;
	create(options?: unknown): unknown;
	host(serverImplementations?: Record<string, KonsoleRun>): RemoteFunction | undefined;
	define(definition: KonsoleDefinition): KonsoleCommand;
	implement(name: string, callback: KonsoleRun): void;
	run(text: string): KonsoleOutcome;
	setRank(userId: unknown, rank: unknown): number;
	getRank(entity: unknown): number;
	bindRanks(resolver?: (entity: unknown) => number | undefined): void;
	destroy(): void;
	show(): void;
	hide(): void;
	toggle(): void;
	focus(): void;
	clear(): void;
}

declare const Konsole: KonsoleApi;
export = Konsole;
