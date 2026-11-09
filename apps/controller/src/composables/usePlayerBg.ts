import { computed, type Ref } from 'vue'
import { PLAYER_COLORS } from '@couch/shared'

// Full class names, so Tailwind finds them.
const PLAYER_BG = ['bg-player-0', 'bg-player-1', 'bg-player-2', 'bg-player-3', 'bg-player-4', 'bg-player-5']

/** The theme background class for a player colour. */
export function usePlayerBg(color: Ref<string>) {
  return computed(() => PLAYER_BG[PLAYER_COLORS.indexOf(color.value)] ?? '')
}
