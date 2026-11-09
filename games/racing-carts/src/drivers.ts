import type { Player, TiltRacerInput } from '@couch/shared';
import { botInput, createBotBrain, type BotBrain } from './bots/bot';
import type { Driver, Game } from './game';
import { NEUTRAL_INPUT, type InputSnapshot } from './rules';

/** Names for karts nobody drives; they follow the slot colours. */
export const BOT_NAMES: readonly string[] = ['Coral', 'Sky', 'Mint', 'Butter', 'Lavender', 'Peach'];

/** The simulation runs at a fixed 60 Hz (see FixedStepper), so bot drivers step their brain by this much. */
const BOT_DT = 1 / 60;

/** A player's latest input, the item press not yet seen by a step, and the snapshot handed to the game. */
interface HumanInput {
  latest: TiltRacerInput;
  itemLatch: boolean;
  out: InputSnapshot;
}

/** Who drives each kart: the round's players by slot, bots for every other kart. */
export class Drivers {
  private humans = new Map<number, { driver: Driver; input: HumanInput }>();
  private bots: Driver[];
  /** One brain per kart id, created on first use. */
  private brains: BotBrain[] = [];

  constructor(
    private readonly game: Game,
    players: readonly Player[],
    private readonly rand: () => number = Math.random,
  ) {
    for (const p of players) {
      const input: HumanInput = { latest: { ...NEUTRAL_INPUT }, itemLatch: false, out: { ...NEUTRAL_INPUT } };
      this.humans.set(p.slot, { driver: { kind: 'human', name: p.name, input: () => this.read(input) }, input });
    }
    this.bots = BOT_NAMES.map((name, id): Driver => ({ kind: 'bot', name, input: () => this.botInputFor(id) }));
  }

  /**
   * Stores a player's input. A fresh ITEM press (up → down) is latched until one step reads it, so the
   * simulation sees exactly one press however long the button is held. Unknown slots are ignored.
   */
  setInput(slot: number, input: TiltRacerInput): void {
    const h = this.humans.get(slot);
    if (!h) return;
    const s = h.input;
    if (input.item && !s.latest.item) s.itemLatch = true;
    s.latest.steer = input.steer;
    s.latest.gas = input.gas;
    s.latest.brake = input.brake;
    s.latest.item = input.item;
  }

  driverFor(kartId: number): Driver {
    return this.humans.get(kartId)?.driver ?? this.bots[kartId] ?? this.bots[0];
  }

  /** The player's input for one fixed step; reuses one snapshot per player. */
  private read(s: HumanInput): InputSnapshot {
    const out = s.out;
    out.steer = s.latest.steer;
    out.gas = s.latest.gas;
    out.brake = s.latest.brake;
    out.item = s.itemLatch;
    s.itemLatch = false;
    return out;
  }

  /** What the bot driving `kartId` does this step. Allocation-free apart from the input snapshot itself. */
  private botInputFor(kartId: number): InputSnapshot {
    const karts = this.game.karts;
    for (let i = 0; i < karts.length; i++) {
      if (karts[i].id !== kartId) continue;
      const brain = this.brains[kartId] ?? (this.brains[kartId] = createBotBrain(this.rand));
      return botInput(brain, karts[i], this.game.track, BOT_DT, this.rand, this.game.world);
    }
    return NEUTRAL_INPUT;
  }
}
