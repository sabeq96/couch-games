import { LAYOUT_IDS, type LayoutId } from './layouts';

export const PEER_PREFIX = 'couchgames-';
export const ROOM_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ';
export const INPUT_HZ = 30;
export const MAX_PARTY = 6;
/** Player colours in slot order: coral, sky, mint, butter, lavender, peach. */
export const PLAYER_COLORS: readonly string[] = [
  '#FF8A80',
  '#82B1FF',
  '#9BE7C4',
  '#FFE38A',
  '#C9B6F2',
  '#FFC09F',
];

export type ClientMsg = { t: 'hello'; name: string } | { t: 'input'; fields: Record<string, unknown> };
export type ServerMsg = { t: 'state'; layout: LayoutId; color: string };

const CODE_LENGTH = 4;
const MAX_NAME_LENGTH = 12;

export function makeRoomCode(rand: () => number = Math.random): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += ROOM_ALPHABET[Math.floor(rand() * ROOM_ALPHABET.length)];
  }
  return code;
}

export function peerIdFor(code: string): string {
  return PEER_PREFIX + code.toUpperCase();
}

export function controllerUrl(controllerBase: string, code: string): string {
  return `${controllerBase}?room=${code}`;
}

/** Accepts a plain object or a JSON string; returns a plain record or null. */
function toRecord(raw: unknown): Record<string, unknown> | null {
  let value = raw;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

export function decodeClient(raw: unknown): ClientMsg | null {
  const m = toRecord(raw);
  if (!m) return null;
  switch (m.t) {
    case 'hello': {
      const name = (typeof m.name === 'string' ? m.name : '').trim().slice(0, MAX_NAME_LENGTH).trim();
      return { t: 'hello', name: name || 'Player' };
    }
    case 'input': {
      const { t: _t, ...fields } = m;
      return { t: 'input', fields };
    }
    default:
      return null;
  }
}

export function decodeServer(raw: unknown): ServerMsg | null {
  const m = toRecord(raw);
  if (!m || m.t !== 'state') return null;
  if (typeof m.color !== 'string') return null;
  if (!LAYOUT_IDS.includes(m.layout as LayoutId)) return null;
  return { t: 'state', layout: m.layout as LayoutId, color: m.color };
}

export function encodeInput(input: object): { t: 'input' } & object {
  return { t: 'input', ...input };
}
