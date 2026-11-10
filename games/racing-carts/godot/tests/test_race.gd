extends GutTest
# The race scene off the web: Bridge plays slot 0 on the keyboard (Up is GAS) and slot 1 idle, bots fill the rest.

var race: Race

func before_each():
	race = load("res://scenes/race.tscn").instantiate()
	add_child_autofree(race)

func after_each():
	_key(KEY_UP, false)

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _karts() -> Array[Kart]:
	var karts: Array[Kart] = []
	for child in race.get_children():
		if child is Kart:
			karts.append(child)
	return karts

func _kart_in_slot(slot: int) -> Kart:
	for kart in _karts():
		if kart.slot == slot:
			return kart
	return null

func test_six_karts_humans_first():
	var karts := _karts()
	assert_eq(karts.size(), 6)
	assert_eq(karts.map(func(k): return k.slot), [0, 1, -1, -1, -1, -1])

func test_nothing_moves_during_the_countdown_then_gas_drives():
	_key(KEY_UP, true)
	var before := _karts().map(func(k): return k.position)
	await wait_physics_frames(roundi(RaceRules.COUNTDOWN * 60) - 10)
	assert_eq(_karts().map(func(k): return k.position), before, "still on the grid")
	await wait_physics_frames(70)
	assert_gt(_kart_in_slot(0).position.distance_to(before[0]), 1.0, "slot 0 drove off after GO")
