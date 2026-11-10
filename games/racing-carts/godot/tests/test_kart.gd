extends GutTest
# Karts in a small arena: a floor, a wall across +Z, a mud strip and a boost pad.

const WALL_FACE_Z := 19.5 # the wall's face toward the arena; its normal is -Z
const MUD_X := -30.0
const PAD_X := 30.0

var arena: Node3D

func before_each():
	arena = Node3D.new()
	add_child_autofree(arena)
	_static_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120)) # floor, top at y = 0
	_static_box(Vector3(0, 0.45, WALL_FACE_Z + 0.5), Vector3(40, 1.1, 1)) # wall
	_area(Vector3(MUD_X, 0, 0), Vector3(10, 1, 60), "mud")
	_area(Vector3(PAD_X, 0, 0), Vector3(3, 1, 4), "boost_pad")

func _static_box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(_shape(size))
	arena.add_child(body)

func _area(pos: Vector3, size: Vector3, group: String) -> void:
	var area := Area3D.new()
	area.position = pos
	area.add_to_group(group)
	area.add_child(_shape(size))
	arena.add_child(area)

func _shape(size: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	return shape

func _kart(pos: Vector3, heading: float, gas := true) -> Kart:
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	kart.position = pos
	kart.heading = heading
	kart.input = { "steer": 0.0, "gas": gas, "brake": false, "item": false }
	arena.add_child(kart)
	return kart

func _speed(kart: Kart) -> float:
	return kart.velocity.length()

func test_wall_bounce_is_fixed_and_outward():
	# Head-on at 20 m/s, coasting. Each await resumes once per tick, before the kart's next tick, so the velocity read
	# is the one right after the contact tick.
	var kart := _kart(Vector3(0, 0, 8), 0.0, false) # facing +Z, the wall
	kart.velocity = Vector3(0, 0, 20)
	var frames := 0
	while not kart.touched_wall_recently() and frames < 120:
		await get_tree().physics_frame
		frames += 1
	assert_true(kart.touched_wall_recently(), "reached the wall")
	assert_almost_eq(kart.velocity.dot(Vector3.FORWARD), KartTuning.WALL_BOUNCE, 0.1, "normal velocity off the wall")
	assert_lt(kart.position.z, WALL_FACE_Z - 0.9, "outside the wall")
	assert_eq(kart.position.y, 0.0)

func test_touched_wall_recently_expires():
	var kart := _kart(Vector3(0, 0, 8), 0.0, false)
	kart.velocity = Vector3(0, 0, 20)
	while not kart.touched_wall_recently():
		await wait_physics_frames(1)
	kart.input = { "steer": 0.0, "gas": false, "brake": false, "item": false }
	await wait_physics_frames(roundi(KartTuning.CATCHUP_WALL_PAUSE * 60) - 5)
	assert_true(kart.touched_wall_recently())
	await wait_physics_frames(10)
	assert_false(kart.touched_wall_recently())

func test_mud_halves_top_speed():
	var kart := _kart(Vector3(MUD_X, 0, -25), 0.0)
	await wait_physics_frames(150)
	assert_almost_eq(_speed(kart), KartTuning.MAX_SPEED * KartTuning.MUD_TOP_FACTOR, 0.1)
	assert_almost_eq(kart.position.x, MUD_X, 0.01, "still on the mud")

func test_pad_boosts_for_one_second():
	var kart := _kart(Vector3(PAD_X, 0, -6), 0.0)
	var frames := 0
	while not kart.is_boosted() and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_true(kart.is_boosted(), "the pad boosts")
	var boosted_at := Engine.get_physics_frames()
	while kart.is_boosted() and Engine.get_physics_frames() - boosted_at < 120:
		await wait_physics_frames(1)
	assert_between(Engine.get_physics_frames() - boosted_at, 58, 62, "about PAD_BOOST_TIME at 60 Hz")

func test_boost_refreshes_and_never_shortens():
	var kart := _kart(Vector3.ZERO, 0.0, false)
	kart.boost(1.0)
	kart.boost(0.2)
	await wait_physics_frames(30)
	assert_true(kart.is_boosted(), "0.2 s did not shorten 1 s")
	kart.boost(1.0)
	await wait_physics_frames(50)
	assert_true(kart.is_boosted(), "refreshed to a full second")

func test_karts_bump_apart():
	var hitter := _kart(Vector3(0, 0, -30), 0.0) # drives +Z
	var hit := _kart(Vector3(0, 0, -26), PI, false) # facing it, idle
	var frames := 0
	while hitter.velocity.z >= 0.0 and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_almost_eq(hitter.velocity.z, -KartTuning.KART_BOUNCE, 0.1, "the hitter bounces back")
	assert_almost_eq(hit.velocity.z, KartTuning.KART_BOUNCE, 0.1, "the hit kart is pushed on")
	var gap := hitter.position.distance_to(hit.position)
	await wait_physics_frames(10)
	assert_gt(hitter.position.distance_to(hit.position), gap, "they move apart")
	assert_eq(hitter.heading, 0.0, "a bump does not spin")
	assert_eq(hit.heading, PI)

func test_spin_ignores_input_for_spin_time():
	var kart := _kart(Vector3.ZERO, 0.0)
	kart.input = { "steer": 1.0, "gas": true, "brake": false, "item": false }
	kart.velocity = Vector3(0, 0, 10)
	kart.spin_out()
	var spin_frames := roundi(KartTuning.SPIN_TIME * 60)
	await wait_physics_frames(spin_frames - 2)
	assert_eq(kart.heading, 0.0, "steer ignored")
	assert_lt(_speed(kart), 10.0 - 1.0, "speed decays, gas ignored")
	await wait_physics_frames(6)
	assert_lt(kart.heading, 0.0, "steers right again")
	var after_spin := _speed(kart)
	await wait_physics_frames(6)
	assert_gt(_speed(kart), after_spin, "accelerates again")
