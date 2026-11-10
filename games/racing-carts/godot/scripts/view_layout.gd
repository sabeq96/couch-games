class_name ViewLayout extends RefCounted
## Split-screen layouts: one row for 1–2 views, two rows for 3–6 (the top row takes the odd one).
## Rects are in pixels, in view order, with integer edges that tile the screen exactly.


static func rects(count: int, size: Vector2) -> Array[Rect2]:
	var rows: Array[int] = [count]
	if count > 2:
		rows = [ceili(count / 2.0), count - ceili(count / 2.0)]
	var result: Array[Rect2] = []
	for row in rows.size():
		var top := floorf(size.y * row / rows.size())
		var bottom := floorf(size.y * (row + 1) / rows.size())
		for col in rows[row]:
			var left := floorf(size.x * col / rows[row])
			var right := floorf(size.x * (col + 1) / rows[row])
			result.append(Rect2(left, top, right - left, bottom - top))
	return result
