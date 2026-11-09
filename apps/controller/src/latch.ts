/**
 * Remembers each button's press until its next read, so a tap shorter than one 30 Hz send interval
 * is still sent once. `read(k, level)` gives `level || k pressed since its last read`, then forgets the press.
 */
export function createLatches<K extends string>(): { press(k: K): void; read(k: K, level: boolean): boolean } {
  const latched = new Set<K>();
  return {
    press(k: K): void {
      latched.add(k);
    },
    read(k: K, level: boolean): boolean {
      const v = level || latched.has(k);
      latched.delete(k);
      return v;
    },
  };
}
