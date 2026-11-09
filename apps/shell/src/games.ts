import type { Game } from '@couch/shared'

export interface GameEntry {
  id: string
  game: Game
}

/** One entry per `<folder>/index.ts` glob key; the folder name is the id. Sorted by title. */
export function gamesFrom(modules: Record<string, { default: Game }>): GameEntry[] {
  return Object.entries(modules)
    .map(([key, mod]) => ({ id: key.split('/').at(-2) ?? key, game: mod.default }))
    .sort((a, b) => a.game.title.localeCompare(b.game.title))
}

export const games: GameEntry[] = gamesFrom({
  ...import.meta.glob<{ default: Game }>('../../../games/*/index.ts', { eager: true }),
  ...(import.meta.env.VITE_E2E
    ? import.meta.glob<{ default: Game }>('../../../e2e/fixtures/*/index.ts', { eager: true })
    : {}),
})
