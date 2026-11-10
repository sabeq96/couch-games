/** Splits sorted results into the podium (places 1–3, each on the step for its place) and everyone else. */
export function splitPodium<T extends { place: number }>(rows: readonly T[]): { podium: T[]; rest: T[] } {
  return {
    podium: rows.filter(onPodium),
    rest: rows.filter((r) => !onPodium(r)),
  }
}

const onPodium = (r: { place: number }): boolean => r.place >= 1 && r.place <= 3
