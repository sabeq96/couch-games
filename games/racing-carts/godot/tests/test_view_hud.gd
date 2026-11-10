extends GutTest
# ViewHud: place, lap, held item and the finished state of one view, in plain text (no emoji).

var hud: ViewHud

func before_each():
	hud = ViewHud.new()
	add_child_autofree(hud)
	hud.size = Vector2(960, 540)

func _labels() -> Array[Label]:
	var found: Array[Label] = []
	for node in hud.find_children("*", "Label", true, false):
		found.append(node)
	return found

func _visible_texts() -> Array[String]:
	var texts: Array[String] = []
	for label in _labels():
		if label.is_visible_in_tree() and label.text != "":
			texts.append(label.text)
	return texts

func test_hud_shows_place_lap_item():
	hud.show_state(2, 2, 3, "banana", false, 0)
	assert_eq(hud.place_text(), "2nd")
	assert_eq(hud.lap_text(), "LAP 2/3")
	assert_eq(hud.item_text(), "BANANA")
	assert_true(hud.item_visible())
	assert_eq(hud.item_color(), ItemRegistry.by_id("banana").hud_color, "the pill uses the item's hud_color")
	assert_eq(hud.finished_text(), "")
	for place in range(1, 7):
		hud.show_state(place, 1, 3, "", false, 0)
		assert_eq(hud.place_text(), ["1st", "2nd", "3rd", "4th", "5th", "6th"][place - 1])
	assert_false(hud.item_visible(), "no pill without an item")

func test_hud_rolling_shows_question_mark():
	hud.show_state(1, 1, 3, "rocket", true, 0)
	assert_eq(hud.item_text(), "?")
	assert_true(hud.item_visible())

func test_hud_finished_state():
	hud.show_state(3, 3, 3, "", false, 2)
	assert_eq(hud.finished_text(), "FINISHED 2nd")
	assert_has(_visible_texts(), "FINISHED 2nd")
	hud.show_state(3, 3, 3, "", false, 0)
	assert_false(_visible_texts().has("FINISHED 2nd"), "hidden while racing")

func test_hud_font_scales_with_view():
	hud.size = Vector2(960, 600)
	await wait_physics_frames(1)
	for label in _labels():
		assert_eq(label.get_theme_font_size("font_size"), 50, label.name + " at 600 px high")
	hud.size = Vector2(480, 200)
	await wait_physics_frames(1)
	for label in _labels():
		assert_eq(label.get_theme_font_size("font_size"), 24, label.name + " never below 24")

func test_no_emoji_in_hud():
	var ids: Array[String] = [""]
	for item in ItemRegistry.all():
		ids.append(item.id)
	for id in ids:
		for rolling in [false, true]:
			for finished in [0, 4]:
				hud.show_state(4, 2, 3, id, rolling, finished)
				for label in _labels():
					for i in label.text.length():
						assert_lt(label.text.unicode_at(i), 0x2000, "%s: %s" % [label.name, label.text])
