import type { DpadInput } from '@couch/shared'

export type Key = keyof DpadInput

/** Turns dpad snapshots into presses: keys that went up → down since the previous snapshot. */
export class Presses {
  private prev: DpadInput | null = null

  next(input: DpadInput): Key[] {
    const prev = this.prev
    this.prev = input
    if (!prev) return []
    return (Object.keys(input) as Key[]).filter((k) => input[k] && !prev[k])
  }

  /** The next snapshot becomes the baseline, so a key already held then is not a press. */
  reset(): void {
    this.prev = null
  }
}
