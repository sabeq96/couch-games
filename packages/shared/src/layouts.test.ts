import { describe, expect, it } from 'vitest';
import { decodeInput, NEUTRAL } from './layouts';

const dpad = { up: true, down: false, left: false, right: false, a: false, b: false };

describe('decodeInput', () => {
  it('accepts a full dpad input', () => {
    expect(decodeInput('dpad', dpad)).toEqual(dpad);
  });
  it('rejects a dpad input missing a key', () => {
    const { b: _b, ...rest } = dpad;
    expect(decodeInput('dpad', rest)).toBeNull();
  });
  it('clamps tilt-racer steer', () => {
    expect(decodeInput('tilt-racer', { steer: 3, gas: true, brake: false, item: false })?.steer).toBe(1);
    expect(decodeInput('tilt-racer', { steer: -3, gas: true, brake: false, item: false })?.steer).toBe(-1);
  });
  it('rejects tilt-racer input with non-finite steer', () => {
    expect(decodeInput('tilt-racer', { steer: NaN, gas: true, brake: false, item: false })).toBeNull();
  });
  it('rejects dpad fields for tilt-racer', () => {
    expect(decodeInput('tilt-racer', dpad)).toBeNull();
  });
  it('never decodes wait input', () => {
    expect(decodeInput('wait', {})).toBeNull();
  });
  it('has a neutral input that decodes for each layout', () => {
    expect(decodeInput('dpad', { ...NEUTRAL.dpad })).toEqual(NEUTRAL.dpad);
    expect(decodeInput('tilt-racer', { ...NEUTRAL['tilt-racer'] })).toEqual(NEUTRAL['tilt-racer']);
  });
});
