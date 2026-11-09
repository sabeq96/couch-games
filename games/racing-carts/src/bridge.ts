import type { Player, Result, TiltRacerInput } from '@couch/shared';

/** URL of a file of the Godot web export, under the site base. */
export function exportUrl(base: string, file: string): string {
  return `${base.replace(/\/$/, '')}/games/racing-carts/${file}`;
}

export function engineConfig(
  base: string,
  canvas: HTMLCanvasElement,
  onExit: (code: number) => void,
): Record<string, unknown> {
  return {
    executable: exportUrl(base, 'index'),
    canvas,
    focusCanvas: false,
    canvasResizePolicy: 0,
    onExit,
    args: [],
  };
}

export function encodePlayers(players: readonly Player[]): string {
  return JSON.stringify(players.map(({ slot, name, color }) => ({ slot, name, color })));
}

export function encodeInputs(inputs: ReadonlyMap<number, TiltRacerInput>): string {
  return JSON.stringify(Object.fromEntries(inputs));
}

/** One result per player, always: bad or missing entries are placed last, in slot order. */
export function decodeResults(json: string, players: readonly Player[]): Result[] {
  const known = new Set(players.map((p) => p.slot));
  const seen = new Set<number>();
  const valid: Result[] = [];
  for (const entry of parseArray(json)) {
    if (typeof entry !== 'object' || entry === null) continue;
    const { slot, place } = entry as Record<string, unknown>;
    if (typeof slot !== 'number' || typeof place !== 'number' || !Number.isFinite(place)) continue;
    if (!known.has(slot) || seen.has(slot)) continue;
    seen.add(slot);
    valid.push({ slot, place });
  }
  valid.sort((a, b) => a.place - b.place);
  const missing = players.map((p) => p.slot).filter((slot) => !seen.has(slot)).sort((a, b) => a - b);
  return [...valid.map((r) => r.slot), ...missing].map((slot, i) => ({ slot, place: i + 1 }));
}

function parseArray(json: string): unknown[] {
  try {
    const data: unknown = JSON.parse(json);
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  }
}
