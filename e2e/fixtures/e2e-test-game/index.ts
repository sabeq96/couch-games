import type { Game } from '@couch/shared'
import cover from './cover.svg'

// A tiny game for e2e tests; only in builds with VITE_E2E.
export default {
  title: 'Test Game',
  cover,
  layout: 'dpad',
  players: { min: 1, max: 2 },
  load: () => import('./game'),
} satisfies Game<'dpad'>
