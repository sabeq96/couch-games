/** The selection index after moving one step in a grid of `count` items, `cols` wide. Clamped, no wrap. */
export function move(index: number, key: 'up' | 'down' | 'left' | 'right', count: number, cols: number): number {
  const col = index % cols
  if (key === 'left') return col > 0 ? index - 1 : index
  if (key === 'right') return col < cols - 1 && index + 1 < count ? index + 1 : index
  if (key === 'up') return index - cols >= 0 ? index - cols : index
  return index + cols < count ? index + cols : index
}
