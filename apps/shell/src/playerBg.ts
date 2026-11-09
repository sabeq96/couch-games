// Full class names, so Tailwind finds them.
const PLAYER_BG = ['bg-player-0', 'bg-player-1', 'bg-player-2', 'bg-player-3', 'bg-player-4', 'bg-player-5']

/** The theme background class for a party slot. */
export const playerBg = (slot: number): string => PLAYER_BG[slot] ?? ''
