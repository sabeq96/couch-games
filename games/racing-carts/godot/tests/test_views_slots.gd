extends GutTest
# Views built straight from karts with gaps between slots, as when players 1, 3 and 6 of a party play.

const KART_SCENE := preload("res://scenes/kart.tscn")

func test_views_with_slot_gaps():
	var karts: Array[Kart] = []
	for slot in [0, 2, 5]:
		var kart: Kart = KART_SCENE.instantiate()
		kart.slot = slot
		kart.position = Vector3(slot * 10.0, 0, 0)
		add_child_autofree(kart)
		karts.append(kart)
	var views := Views.new()
	add_child_autofree(views)
	views.size = Vector2(1200, 600)
	views.setup(karts, World3D.new())
	assert_eq(views.view_count(), 3)
	for kart in karts:
		assert_eq(views.camera_for(kart.slot).target, kart, "slot %d follows its kart" % kart.slot)
		assert_not_null(views.hud_for(kart.slot), "slot %d has a HUD" % kart.slot)
	assert_null(views.camera_for(1), "no view for a slot nobody plays")
	assert_null(views.hud_for(1))
	var frames := views.get_children().filter(func(c): return c is ColorRect)
	var rects := ViewLayout.rects(3, views.size)
	for i in frames.size():
		assert_eq(frames[i].color, karts[i].color, "view %d is slot %d's, in slot order" % [i, karts[i].slot])
		assert_eq(Rect2(frames[i].position, frames[i].size), rects[i], "view %d in layout position %d" % [i, i])
