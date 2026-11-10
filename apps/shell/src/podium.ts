/** Splits sorted results into the podium (places 1–3, each on the step for its place) and everyone else. */
export function splitPodium<T extends { place: number }>(rows: readonly T[]): { podium: T[]; rest: T[] } {
  return {
    podium: rows.filter((r) => r.place <= 3),
    rest: rows.filter((r) => r.place > 3),
  }
}
