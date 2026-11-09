import { expect, test } from 'vitest';
import { createLatches } from './latch';

test('a tap shorter than one send interval still goes out as one press', () => {
  const latches = createLatches<'a' | 'b'>();
  latches.press('a');
  // released before the next 30 Hz send
  expect(latches.read('a', false)).toBe(true);
  expect(latches.read('a', false)).toBe(false);
});

test('each button latches on its own', () => {
  const latches = createLatches<'a' | 'b'>();
  latches.press('a');
  expect(latches.read('b', false)).toBe(false);
  expect(latches.read('a', false)).toBe(true);
});

test('a held button reads as held; nothing pressed reads false', () => {
  const latches = createLatches<'a'>();
  expect(latches.read('a', false)).toBe(false);
  latches.press('a');
  expect(latches.read('a', true)).toBe(true);
  expect(latches.read('a', true)).toBe(true);
  expect(latches.read('a', false)).toBe(false);
});
