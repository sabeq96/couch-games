export type LayoutId = 'wait' | 'dpad' | 'tilt-racer';
export const LAYOUT_IDS: readonly LayoutId[] = ['wait', 'dpad', 'tilt-racer'];

export interface DpadInput {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
  a: boolean;
  b: boolean;
}
export interface TiltRacerInput {
  steer: number;
  gas: boolean;
  brake: boolean;
  item: boolean;
}
export interface LayoutInputs {
  wait: Record<string, never>;
  dpad: DpadInput;
  'tilt-racer': TiltRacerInput;
}

export const NEUTRAL: { [L in LayoutId]: LayoutInputs[L] } = {
  wait: {},
  dpad: { up: false, down: false, left: false, right: false, a: false, b: false },
  'tilt-racer': { steer: 0, gas: false, brake: false, item: false },
};

const DPAD_KEYS = ['up', 'down', 'left', 'right', 'a', 'b'] as const;

export function decodeInput<L extends LayoutId>(layout: L, fields: Record<string, unknown>): LayoutInputs[L] | null {
  const result = decodeLayout(layout, fields);
  return result as LayoutInputs[L] | null;
}

function decodeLayout(layout: LayoutId, f: Record<string, unknown>): LayoutInputs[LayoutId] | null {
  switch (layout) {
    case 'dpad': {
      if (!DPAD_KEYS.every((k) => typeof f[k] === 'boolean')) return null;
      return { up: f.up, down: f.down, left: f.left, right: f.right, a: f.a, b: f.b } as DpadInput;
    }
    case 'tilt-racer': {
      if (typeof f.steer !== 'number' || !Number.isFinite(f.steer)) return null;
      if (typeof f.gas !== 'boolean' || typeof f.brake !== 'boolean' || typeof f.item !== 'boolean') return null;
      return { steer: Math.max(-1, Math.min(1, f.steer)), gas: f.gas, brake: f.brake, item: f.item };
    }
    default:
      return null;
  }
}
