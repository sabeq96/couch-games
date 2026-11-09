import type { LayoutId, LayoutInputs } from './layouts';

export interface Player {
  slot: number;
  name: string;
  color: string;
}
export interface Result {
  slot: number;
  place: number;
}
export interface Round {
  el: HTMLElement;
  players: readonly Player[];
  finish(results: Result[]): void;
}
export interface RoundHandle<L extends LayoutId = LayoutId> {
  input(slot: number, input: LayoutInputs[L]): void;
  destroy(): void;
}
export interface GameModule<L extends LayoutId = LayoutId> {
  start(round: Round): RoundHandle<L>;
}
export interface Game<L extends LayoutId = LayoutId> {
  title: string;
  cover: string;
  layout: L;
  players: { min: number; max: number };
  load(): Promise<GameModule<L>>;
}
