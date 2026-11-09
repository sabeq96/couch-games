import type { Game } from '@couch/shared';
import cover from './cover.png';

export default {
  title: 'Racing Carts',
  cover,
  layout: 'tilt-racer',
  players: { min: 1, max: 6 },
  load: () => import('./src/game'),
} satisfies Game<'tilt-racer'>;
