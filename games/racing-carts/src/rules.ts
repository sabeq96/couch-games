/** Racing rules and the per-kart input the simulation reads each step. */
export const TOTAL_LAPS = 3;

export type Phase = 'lobby' | 'countdown' | 'racing' | 'results';

export interface InputSnapshot {
  steer: number;
  gas: boolean;
  brake: boolean;
  item: boolean;
}

export const NEUTRAL_INPUT: InputSnapshot = { steer: 0, gas: false, brake: false, item: false };
