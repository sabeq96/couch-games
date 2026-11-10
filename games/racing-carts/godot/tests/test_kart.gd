extends GutTest
# Karts in a small arena: a floor, a wall across +Z, a mud strip, a track-sized mud patch and a boost pad.

const WALL_FACE_Z := 19.5 # the wall's face toward the arena; its normal is -Z
const MUD_X := -30.0
const PAD_X := 30.0
const PATCH_X := 50.0 # a mud patch like the track's, 6 m wide and 8 m along Z, centred on z = 0

var arena: Node3D

func before_each():
	arena = Node3D.new()
	add_child_autofree(arena)
	_static_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120)) # floor, top at y = 0
	_static_box(Vector3(0, 0.45, WALL_FACE_Z + 0.5), Vector3(40, 1.1, 1)) # wall
	_area(Vector3(MUD_X, 0, 0), Vector3(10, 1, 60), "mud")
	_area(Vector3(PATCH_X, 0, 0), Vector3(6, 1, 8), "mud")
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

func test_mud_patch_slows_a_kart_at_top_speed():
	var kart := _kart(Vector3(PATCH_X, 0, -20), 0.0) # holding GAS
	kart.velocity = Vector3(0, 0, KartTuning.MAX_SPEED)
	var frames := 0
	# The sensor (radius 1 m) is off the patch once the kart is 1 m past its far edge at z = 4.
	while kart.position.z < 5.0 and frames < 120:
		await get_tree().physics_frame
		frames += 1
	gut.p("speed after the mud patch: %.2f m/s" % _speed(kart))
	assert_lte(_speed(kart), 15.0)

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
	var before := 0.0
	var frames := 0
	# Each await resumes before the karts' next tick, so the loop ends right after the contact tick.
	while hit.velocity.z <= 0.0 and frames < 120:
		before = hitter.velocity.z
		await get_tree().physics_frame
		frames += 1
	assert_almost_eq(hit.velocity.z - hitter.velocity.z, 2.0 * KartTuning.KART_BOUNCE, 0.1, "they part at the fixed speeds")
	# The hitter gains ACCEL * dt on the contact tick before the bounce.
	var mean := (before + KartTuning.ACCEL / 60.0) / 2.0
	assert_almost_eq((hit.velocity.z + hitter.velocity.z) / 2.0, mean, 0.1, "around the pair's mean speed")
	var gap := hitter.position.distance_to(hit.position)
	await wait_physics_frames(10)
	assert_gt(hitter.position.distance_to(hit.position), gap, "they move apart")
	assert_eq(hitter.heading, 0.0, "a bump does not spin")
	assert_eq(hit.heading, PI)

# Two karts coasting along +Z, the rear one 5 cm behind and a little faster. Returns the forward speeds
# `[front_before, rear_before, front_after, rear_after]` around the contact tick.
func _rear_end(front_speed: float, rear_speed: float, rear_boosted: bool) -> Array[float]:
	var front := _kart(Vector3(10, 0, -38), 0.0, false)
	var rear := _kart(Vector3(10, 0, -40.05), 0.0, false)
	front.velocity = Vector3(0, 0, front_speed)
	rear.velocity = Vector3(0, 0, rear_speed)
	if rear_boosted:
		rear.boost(1.0)
	var front_before := front.velocity.z
	var rear_before := rear.velocity.z
	var frames := 0
	await get_tree().physics_frame
	while absf(front.velocity.z - front_before) < 1.0 and absf(rear.velocity.z - rear_before) < 1.0 and frames < 60:
		front_before = front.velocity.z
		rear_before = rear.velocity.z
		await get_tree().physics_frame
		frames += 1
	assert_lt(frames, 60, "they touched")
	gut.p("rear-end: front %.2f -> %.2f m/s, rear %.2f -> %.2f m/s" % [front_before, front.velocity.z, rear_before, rear.velocity.z])
	return [front_before, rear_before, front.velocity.z, rear.velocity.z]

func test_rear_end_at_matched_speed_is_a_nudge():
	var v := await _rear_end(19.5, 20.0, false)
	assert_gt(v[2], v[0], "the front kart speeds up")
	assert_lt(v[3], v[1], "the rear kart slows")
	assert_gt(v[3], 0.75 * v[1], "the rear kart keeps most of its speed")
	assert_gt(v[2], 0.75 * v[0], "the front kart keeps most of its speed")

func test_boosted_rear_end_shoves_the_front_kart():
	var v := await _rear_end(19.5, 25.0, true)
	assert_gte(v[2] - v[0], 4.0, "the front kart gains at least 4 m/s")

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

func test_body_takes_the_kart_colour():
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	kart.color = Color("#7FB3FF")
	arena.add_child(kart)
	var paint: StandardMaterial3D = kart.get_node("Body/Model/kart-oobi").material_override
	assert_not_null(paint, "the body is painted")
	if paint:
		assert_eq(paint.albedo_color, kart.color)

func test_collider_is_unchanged():
	var shape: CylinderShape3D = _kart(Vector3.ZERO, 0.0).get_node("CollisionShape3D").shape
	assert_almost_eq(shape.radius, 1.0, 0.001)
	assert_almost_eq(shape.height, 0.8, 0.001)

func test_wall_contact_signals_one_bounce():
	var kart := _kart(Vector3(0, 0, 8), 0.0, false) # coasting into the wall
	kart.velocity = Vector3(0, 0, 20)
	watch_signals(kart)
	await wait_physics_frames(60)
	assert_true(kart.touched_wall_recently(), "reached the wall")
	assert_signal_emit_count(kart, "bounced", 1, "one contact, one bounce")
	assert_false(get_signal_parameters(kart, "bounced")[1], "not boosted")

func test_karts_bump_signals_boosted_bounce():
	var hitter := _kart(Vector3(0, 0, -30), 0.0) # drives +Z
	var hit := _kart(Vector3(0, 0, -26), PI, false)
	hitter.boost(5.0)
	watch_signals(hitter)
	watch_signals(hit)
	var frames := 0
	while hit.velocity.z <= 0.0 and frames < 120:
		await get_tree().physics_frame
		frames += 1
	await wait_physics_frames(5) # still touching or just apart: no second bounce
	var bounces: int = get_signal_emit_count(hitter, "bounced") + get_signal_emit_count(hit, "bounced")
	assert_eq(bounces, 1, "one bounce for the pair")
	var kart := hitter if get_signal_emit_count(hitter, "bounced") == 1 else hit
	assert_true(get_signal_parameters(kart, "bounced")[1], "boosted: the hitter was")

func test_pad_and_spin_out_signal():
	var kart := _kart(Vector3(PAD_X, 0, -6), 0.0)
	watch_signals(kart)
	var frames := 0
	while not kart.is_boosted() and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_signal_emitted(kart, "pad_boosted")
	kart.spin_out()
	assert_signal_emitted(kart, "spun_out")
