extends GutTest
# ViewLayout: split-screen rects in pixels, in view order, tiling the screen exactly.

const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(1080, 1920), Vector2(1024, 768), Vector2(2560, 1080)]

func test_layout_counts():
	for count in range(1, 7):
		assert_eq(ViewLayout.rects(count, Vector2(1920, 1080)).size(), count, "%d views" % count)

func test_layout_shapes():
	var three := ViewLayout.rects(3, Vector2(1000, 600))
	assert_eq(three[0], Rect2(0, 0, 500, 300), "3: top left half")
	assert_eq(three[1], Rect2(500, 0, 500, 300), "3: top right half")
	assert_eq(three[2], Rect2(0, 300, 1000, 300), "3: full-width bottom")
	var five := ViewLayout.rects(5, Vector2(900, 600))
	assert_eq(five[0], Rect2(0, 0, 300, 300), "5: top third 1")
	assert_eq(five[1], Rect2(300, 0, 300, 300), "5: top third 2")
	assert_eq(five[2], Rect2(600, 0, 300, 300), "5: top third 3")
	assert_eq(five[3], Rect2(0, 300, 450, 300), "5: bottom left half")
	assert_eq(five[4], Rect2(450, 300, 450, 300), "5: bottom right half")
	assert_eq(ViewLayout.rects(2, Vector2(1000, 600)), [Rect2(0, 0, 500, 600), Rect2(500, 0, 500, 600)], "2: side by side")

func test_layout_tiles_exactly():
	for size in SIZES:
		for count in range(1, 7):
			var rects := ViewLayout.rects(count, size)
			var area := 0.0
			for i in rects.size():
				var r := rects[i]
				assert_eq(r.position, r.position.round(), "integer position %s" % r)
				assert_eq(r.size, r.size.round(), "integer size %s" % r)
				assert_true(Rect2(Vector2.ZERO, size).encloses(r), "%s inside %s" % [r, size])
				area += r.get_area()
				for j in range(i + 1, rects.size()):
					assert_false(r.intersects(rects[j]), "%d views at %s: %s overlaps %s" % [count, size, r, rects[j]])
			assert_eq(area, size.x * size.y, "%d views at %s cover the screen" % [count, size])
