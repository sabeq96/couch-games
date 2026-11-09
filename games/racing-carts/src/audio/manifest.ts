/** Every sound the game can play. Files live at `src/audio/files/<name>.mp3`; see docs/audio-assets.md. */
export const MUSIC = ['music_lobby', 'music_race'] as const;
export const SFX = [
  'countdown_beep',
  'countdown_go',
  'engine_loop',
  'item_box_pickup',
  'item_roulette',
  'boost',
  'shield_up',
  'shield_break',
  'mine_drop',
  'mine_explode',
  'rocket_fire',
  'rocket_explode',
  'kart_spinout',
  'wall_bump',
  'kart_bump',
  'lap_complete',
  'final_lap',
  'race_finish',
  'player_join',
] as const;
export type MusicName = (typeof MUSIC)[number];
export type SoundName = MusicName | (typeof SFX)[number];
export const ALL_SOUNDS: readonly SoundName[] = [...MUSIC, ...SFX];

/** Built URL of each file in `./files`, keyed by its path (the files are bundled, not served from `public/`). */
export const SOUND_URLS: Record<string, string> = import.meta.glob<string>('./files/*.mp3', {
  query: '?url',
  import: 'default',
  eager: true,
});

export function soundUrl(name: SoundName): string {
  return SOUND_URLS[`./files/${name}.mp3`] ?? '';
}
