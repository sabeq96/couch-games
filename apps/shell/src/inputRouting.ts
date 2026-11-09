import { decodeInput, type DpadInput, type LayoutId, type LayoutInputs } from '@couch/shared'
import type { Route } from './layoutFor'

export interface RoutingState {
  route: Route
  leadId: string | undefined
  /** The layout the shell last sent to each member (connection id). */
  sentLayout: ReadonlyMap<string, LayoutId>
  /** Connection ids in the current round's roster. */
  roundIds: ReadonlySet<string>
}

export type Routed =
  | { to: 'presses'; input: DpadInput }
  | { to: 'round'; slot: number; input: LayoutInputs[LayoutId] }
  | null

/**
 * Where a member's input goes. It is decoded against the layout the shell last sent that member, so input from a
 * layout the phone has not switched away from yet is dropped. During a round only roster members reach the game;
 * on library and results only the lead's dpad reaches the shell.
 */
export function routeInput(id: string, slot: number, fields: Record<string, unknown>, s: RoutingState): Routed {
  const layout = s.sentLayout.get(id)
  if (!layout) return null
  const input = decodeInput(layout, fields)
  if (!input) return null
  if (s.route.name === 'play') return s.roundIds.has(id) ? { to: 'round', slot, input } : null
  return id === s.leadId && layout === 'dpad' ? { to: 'presses', input: input as DpadInput } : null
}
