extends GutTest
# Item boxes: one box in a small arena, the 8 boxes on the real track, and the ITEM press through the race.

const BOX_Z := 0.0

var arena: Node3D
var world: ItemWorld
var race: Race

func before_each():
	arena = Node3D.new()
	add_child_autofree(arena)
	var floor := StaticBody3D.new()
	floor.position = Vector3(0, -0.5, 0)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(60, 1, 60)
	var shape := CollisionShape3D.new()
	shape.shape = box_shape
	floor.add_child(shape)
	arena.add_child(floor)
	world = ItemWorld.new()
	arena.add_child(world)

func after_each():
	_key(KEY_SPACE, false)

func _box() -> ItemBox:
	var box: ItemBox = load("res://scenes/item_box.tscn").instantiate()
	box.position = Vector3(0, 0, BOX_Z)
	box.world = world
	arena.add_child(box)
	return box

# A kart driving +Z through the box, alone in the world.
func _kart() -> Kart:
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	kart.position = Vector3(0, 0, BOX_Z - 6)
	kart.input = { "steer": 0.0, "gas": false, "brake": false, "item": false }
	kart.velocity = Vector3(0, 0, 10)
	arena.add_child(kart)
	world.karts = [kart]
	world.order = [0]
	world.distances = [0.0]
	return kart

# Physics frames until condition holds (or max_frames).
func _until(condition: Callable, max_frames: int) -> int:
	var start := Engine.get_physics_frames()
	while not condition.call() and Engine.get_physics_frames() - start < max_frames:
		await get_tree().physics_frame
	return Engine.get_physics_frames() - start

func test_box_gives_an_item():
	var box := _box()
	var kart := _kart()
	await _until(func(): return kart.held_item != "", 60)
	assert_not_null(ItemRegistry.by_id(kart.held_item), "one of the items")
	assert_gt(kart.roll_left, 0.0, "rolling")
	assert_false(box.visible, "the box is gone")

func test_box_respawns_after_3_s():
	var box := _box()
	var kart := _kart()
	await _until(func(): return not box.visible, 60)
	assert_false(box.is_available())
	var frames := await _until(func(): return box.visible, 400)
	assert_between(frames, roundi(KartTuning.BOX_RESPAWN * 60) - 2, roundi(KartTuning.BOX_RESPAWN * 60) + 2, "about BOX_RESPAWN")
	assert_true(box.is_available())

func test_pickup_while_holding_gives_nothing():
	var box := _box()
	var kart := _kart()
	kart.give_item("boost")
	kart.roll_left = 0.0
	kart.held_for = 2.0
	await _until(func(): return not box.visible, 60)
	assert_false(box.visible, "the box still disappears")
	assert_eq(kart.held_item, "boost")
	assert_eq(kart.roll_left, 0.0, "no new roll")
	assert_gt(kart.held_for, 2.0, "the same item, still held")
	await _until(func(): return box.visible, 400)
	assert_true(box.visible, "and respawns")

func test_boxes_sit_on_two_rows():
	var track: Track = load("res://scenes/track.tscn").instantiate()
	add_child_autofree(track)
	var boxes := get_tree().get_nodes_in_group("item_box").filter(func(b): return track.is_ancestor_of(b))
	assert_eq(boxes.size(), 8)
	var spots: Array[Vector3] = []
	for fraction in [0.3, 0.7]:
		for lateral in [-4.5, -1.5, 1.5, 4.5]:
			spots.append(track.point_at(fraction * track.length(), lateral))
	for spot in spots:
		var near := boxes.filter(func(b): return b.global_position.distance_to(spot) < 0.05)
		assert_eq(near.size(), 1, "one box at %s" % spot)

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

# Off the web, slot 0 is the keyboard and Space is ITEM.
func test_item_needs_a_fresh_press():
	race = load("res://scenes/race.tscn").instantiate()
	add_child_autofree(race)
	await wait_physics_frames(roundi(RaceRules.COUNTDOWN * 60) + 5)
	var kart: Kart
	for child in race.get_children():
		if child is Kart and child.slot == 0:
			kart = child
	_key(KEY_SPACE, true)
	await wait_physics_frames(2)
	kart.give_item("boost")
	await wait_physics_frames(roundi(KartTuning.ITEM_ROLL_TIME * 60) + 10)
	assert_eq(kart.held_item, "boost", "ITEM held across the roll does not fire")
	_key(KEY_SPACE, false)
	await wait_physics_frames(2)
	assert_eq(kart.held_item, "boost", "releasing does not fire")
	_key(KEY_SPACE, true)
	await wait_physics_frames(2)
	assert_eq(kart.held_item, "", "a fresh press uses it")
	assert_true(kart.is_boosted())
