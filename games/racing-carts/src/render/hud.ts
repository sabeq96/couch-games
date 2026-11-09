import { TOTAL_LAPS } from '../rules';

const INK = '#5b4638';
const SOFT = '#8a7466';
const PANEL = '#fffaf2';
const RIM = '#f0dcc4';
const CORAL = '#ff8a80';
const GO_HIDE_MS = 900;
/** The message pill sits at the top. */
const MESSAGE_TOP = '56px';
/** The HUD is laid out on a fixed 1920×1080 stage, scaled uniformly (letterboxed) to the window. */
export const STAGE_W = 1920;
export const STAGE_H = 1080;

/** Uniform scale and offsets that fit the stage into a w×h window, centred. */
export function fitStage(w: number, h: number): { scale: number; x: number; y: number } {
  const scale = Math.min(w / STAGE_W, h / STAGE_H);
  return { scale, x: (w - STAGE_W * scale) / 2, y: (h - STAGE_H * scale) / 2 };
}

const STYLE = `
.rc-panel{background:${PANEL};border-radius:48px;box-shadow:0 12px 0 ${RIM};box-sizing:border-box;color:${INK};}
.rc-dot{display:inline-block;border-radius:50%;border:6px solid #fff;box-shadow:0 4px 0 rgba(91,70,56,.15);flex:none;}
.rc-pop{animation:rc-pop .45s cubic-bezier(.2,1.6,.4,1) both;}
@keyframes rc-pop{from{transform:scale(.3);opacity:0}to{transform:scale(1);opacity:1}}
`;

type El = HTMLElement;

export interface RaceRow {
  name: string;
  color: string;
  lap: number;
  /** Icon of the held item (🎲 while rolling), or null. */
  item: string | null;
  /** Crossed the line after the last lap: shown with a 🏁 instead of the lap counter. */
  finished: boolean;
}

function sameRows(a: readonly RaceRow[], b: readonly RaceRow[]): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    const x = a[i], y = b[i];
    if (x.name !== y.name || x.color !== y.color || x.lap !== y.lap || x.item !== y.item || x.finished !== y.finished) {
      return false;
    }
  }
  return true;
}

function el(tag: string, css = '', text?: string, cls?: string): El {
  const node = document.createElement(tag);
  if (css) node.style.cssText = css;
  if (text !== undefined) node.textContent = text;
  if (cls) node.className = cls;
  return node;
}

function dot(color: string, size: number): El {
  const d = el('span', `width:${size}px;height:${size}px;background:${color};`);
  d.className = 'rc-dot';
  return d;
}

/** HTML overlay with big rounded pastel panels: countdown, race list and a message pill. */
export class Hud {
  private countdownEl: El;
  private raceEl: El;
  private messageEl: El;
  /** Rows last drawn by `race`, compared field by field so unchanged frames allocate nothing. */
  private raceRows: RaceRow[] = [];
  private raceDirty = true;
  private goTimer: number | undefined;
  private readonly fit: () => void;

  constructor(private root: HTMLElement) {
    root.textContent = '';
    if (!document.getElementById('rc-hud-style')) {
      const style = el('style');
      style.id = 'rc-hud-style';
      style.textContent = STYLE;
      document.head.appendChild(style);
    }
    // Everything is laid out in 1920×1080 stage pixels; the stage is scaled to whatever CSS viewport
    // the TV (or a laptop) reports, so the HUD looks the same everywhere.
    const stage = el(
      'div',
      `position:absolute;left:0;top:0;width:${STAGE_W}px;height:${STAGE_H}px;overflow:hidden;transform-origin:0 0;`,
    );
    root.appendChild(stage);
    const fit = (this.fit = (): void => {
      const f = fitStage(root.clientWidth || window.innerWidth, root.clientHeight || window.innerHeight);
      stage.style.transform = `translate(${f.x}px,${f.y}px) scale(${f.scale})`;
    });
    fit();
    window.addEventListener('resize', fit);
    const layer = (css: string): El => {
      const d = el('div', 'position:absolute;display:none;' + css);
      stage.appendChild(d);
      return d;
    };
    // Explicit edges, not `inset`: that shorthand arrived in Chrome 87 and the TV is ~Chrome 85.
    this.raceEl = layer('left:40px;top:40px;width:500px;padding:22px 26px;flex-direction:column;gap:6px;');
    this.raceEl.className = 'rc-panel';
    // Upper third, so the bubble never hides the karts the camera keeps centred.
    this.countdownEl = layer('left:0;right:0;top:110px;justify-content:center;');
    this.messageEl = layer(`left:0;right:0;top:${MESSAGE_TOP};justify-content:center;`);
  }

  /** Stops listening for window resizes and cancels the GO timer. */
  dispose(): void {
    window.removeEventListener('resize', this.fit);
    window.clearTimeout(this.goTimer);
  }

  /** Writes `display` only when it changes (`race` runs every frame). */
  private show(node: El, on: boolean): void {
    const want = on ? 'flex' : 'none';
    if (node.style.display !== want) node.style.display = want;
  }

  countdown(n: number | 'GO'): void {
    window.clearTimeout(this.goTimer);
    const box = this.countdownEl;
    box.textContent = '';
    const go = n === 'GO';
    const bubble = el(
      'div',
      `width:260px;height:260px;border-radius:50%;display:flex;align-items:center;justify-content:center;` +
        `font-size:${go ? 110 : 170}px;font-weight:900;color:#fff;background:${go ? '#9BE7C4' : CORAL};` +
        `box-shadow:0 16px 0 ${go ? '#6cc9a0' : '#e8675d'};text-shadow:0 6px 0 rgba(91,70,56,.18);`,
      go ? 'GO!' : String(n),
      'rc-pop',
    );
    box.append(bubble);
    this.show(box, true);
    if (go) this.goTimer = window.setTimeout(() => this.show(box, false), GO_HIDE_MS);
  }

  race(rows: readonly RaceRow[]): void {
    this.show(this.raceEl, true);
    // Called every frame: only touch the DOM when a row changed.
    if (!this.raceDirty && sameRows(rows, this.raceRows)) return;
    this.raceDirty = false;
    this.raceRows = rows.map((r) => ({ name: r.name, color: r.color, lap: r.lap, item: r.item, finished: r.finished }));
    const box = this.raceEl;
    box.textContent = '';
    // "Lap" over the column of lap counters ("Lap 1/3" on every row would squeeze the names).
    box.append(el('div', `font-size:28px;font-weight:900;color:${SOFT};text-align:right;height:30px;line-height:30px;`, 'Lap'));
    rows.forEach((r, i) => {
      const row = el('div', 'display:flex;align-items:center;gap:16px;height:62px;');
      row.append(
        el('div', `width:44px;font-size:40px;font-weight:900;text-align:right;color:${i === 0 ? CORAL : INK};`, String(i + 1)),
        dot(r.color, 44),
        el('div', 'flex:1;min-width:0;font-size:36px;font-weight:900;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;', r.name),
      );
      if (r.item) {
        row.append(
          el('div', `font-size:36px;line-height:52px;width:52px;height:52px;text-align:center;border-radius:50%;background:#ffe9cf;flex:none;`, r.item),
        );
      }
      row.append(
        r.finished
          ? el('div', 'font-size:36px;white-space:nowrap;', '🏁')
          : el('div', `font-size:36px;color:${SOFT};white-space:nowrap;`, `${Math.min(r.lap, TOTAL_LAPS)}/${TOTAL_LAPS}`),
      );
      box.append(row);
    });
  }

  message(text: string | null): void {
    const box = this.messageEl;
    box.textContent = '';
    if (text === null) {
      this.show(box, false);
      return;
    }
    box.append(el('div', 'padding:26px 56px;font-size:52px;font-weight:900;text-align:center;', text, 'rc-panel rc-pop'));
    this.show(box, true);
  }
}
