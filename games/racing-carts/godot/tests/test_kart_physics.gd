extends GutTest

const DT := 1.0 / 60.0
const GAS := { "steer": 0.0, "gas": true, "brake": false, "item": false }
const BRAKE := { "steer": 0.0, "gas": false, "brake": true, "item": false }
const NONE := { "steer": 0.0, "gas": false, "brake": false, "item": false }

# Runs `seconds` of steps from velocity v at heading 0 (forward is +Z).
func _run(v: Vector3, input: Dictionary, seconds: float, top := KartTuning.MAX_SPEED, on_mud := false) -> Dictionary:
	var state := { "velocity": v, "heading": 0.0 }
	for i in roundi(seconds / DT):
		state = KartPhysics.step(state.velocity, state.heading, input, top, DT, on_mud)
	return state

func test_gas_accelerates_to_top_speed():
	var one := KartPhysics.step(Vector3.ZERO, 0.0, GAS, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(one.velocity, Vector3(0, 0, KartTuning.ACCEL * DT), Vector3.ONE * 1e-5)
	var state := _run(Vector3.ZERO, GAS, 3.0)
	assert_almost_eq(state.velocity, Vector3(0, 0, KartTuning.MAX_SPEED), Vector3.ONE * 1e-4)

func test_gas_above_top_speed_eases_down():
	var one := KartPhysics.step(Vector3(0, 0, 30), 0.0, GAS, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(one.velocity.z, 30.0 - KartTuning.COAST_DECEL * DT, 1e-5)
	assert_almost_eq(_run(Vector3(0, 0, 30), GAS, 5.0).velocity.z, KartTuning.MAX_SPEED, 1e-4)

func test_mud_slows_harder_above_top_speed():
	var mud_top := KartTuning.MAX_SPEED * KartTuning.MUD_TOP_FACTOR
	for input in [GAS, NONE]:
		var one := KartPhysics.step(Vector3(0, 0, 20), 0.0, input, mud_top, DT, true)
		assert_almost_eq(one.velocity.z, 20.0 - KartTuning.MUD_DECEL * DT, 1e-5)
	# Below the mud top speed, coasting is as usual.
	var slow := KartPhysics.step(Vector3(0, 0, 5), 0.0, NONE, mud_top, DT, true)
	assert_almost_eq(slow.velocity.z, 5.0 - KartTuning.COAST_DECEL * DT, 1e-5)
	assert_almost_eq(_run(Vector3(0, 0, 20), GAS, 2.0, mud_top, true).velocity.z, mud_top, 1e-4, "settles at the mud top speed")

func test_brake_then_reverse_capped():
	var one := KartPhysics.step(Vector3(0, 0, 10), 0.0, BRAKE, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(one.velocity.z, 10.0 - KartTuning.BRAKE_DECEL * DT, 1e-5)
	var state := _run(Vector3(0, 0, 10), BRAKE, 3.0)
	assert_almost_eq(state.velocity, Vector3(0, 0, -KartTuning.REVERSE_MAX), Vector3.ONE * 1e-4)

func test_coast_slows_down():
	var one := KartPhysics.step(Vector3(0, 0, 10), 0.0, NONE, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(one.velocity.z, 10.0 - KartTuning.COAST_DECEL * DT, 1e-5)
	assert_almost_eq(_run(Vector3(0, 0, 10), NONE, 3.0).velocity, Vector3.ZERO, Vector3.ONE * 1e-4)

func test_no_turn_when_stopped():
	var state := KartPhysics.step(Vector3.ZERO, 0.0, { "steer": 1.0, "gas": false, "brake": false, "item": false }, KartTuning.MAX_SPEED, DT)
	assert_eq(state.heading, 0.0)

func test_steer_right_moving_forward_turns_to_the_kart_right():
	# Heading 0: forward is +Z, and the kart's right (forward × up, seen from above) is -X.
	var right := KartPhysics.forward(0.0).cross(Vector3.UP)
	assert_almost_eq(right, Vector3.LEFT, Vector3.ONE * 1e-6)
	var steer_right := { "steer": 1.0, "gas": true, "brake": false, "item": false }
	var state := KartPhysics.step(Vector3(0, 0, 10), 0.0, steer_right, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(state.heading, -KartTuning.STEER_RATE * DT, 1e-6)
	assert_lt(state.velocity.x, 0.0, "moves toward -X, the kart's right")

func test_steer_right_reversing_turns_the_other_way():
	var steer_right := { "steer": 1.0, "gas": false, "brake": true, "item": false }
	var state := KartPhysics.step(Vector3(0, 0, -KartTuning.REVERSE_MAX), 0.0, steer_right, KartTuning.MAX_SPEED, DT)
	assert_gt(state.heading, 0.0)

func test_turn_rate_scales_below_5_mps():
	var steer := { "steer": 1.0, "gas": false, "brake": false, "item": false }
	var state := KartPhysics.step(Vector3(0, 0, 2.5 + KartTuning.COAST_DECEL * DT), 0.0, steer, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(state.heading, -KartTuning.STEER_RATE * 0.5 * DT, 1e-6)

func test_lateral_slides_and_decays():
	# Heading 0: lateral is along X. 5 m/s sideways keeps sliding, decaying by grip.
	var state := KartPhysics.step(Vector3(5, 0, 0), 0.0, NONE, KartTuning.MAX_SPEED, DT)
	assert_almost_eq(state.velocity.x, 5.0 * exp(-KartTuning.GRIP * DT), 1e-5)
	assert_ne(state.velocity.x, 0.0)
	assert_almost_eq(state.velocity.z, 0.0, 1e-6)

# Full lock right for 1 s with GAS, holding speed v; returns the lateral speed relative to the heading at the end.
func _lateral_after_full_lock(v: float) -> float:
	var steer_right := { "steer": 1.0, "gas": true, "brake": false, "item": false }
	var state := _run(Vector3(0, 0, v), steer_right, 1.0, v)
	return state.velocity.dot(KartPhysics.forward(state.heading).cross(Vector3.UP))

func test_fast_turn_slides():
	var lateral := _lateral_after_full_lock(KartTuning.MAX_SPEED)
	assert_between(absf(lateral), 3.0, 8.0)
	assert_lt(lateral, 0.0, "slides outward, to the left of a right turn")

func test_slow_turn_stays_tight():
	assert_lt(absf(_lateral_after_full_lock(4.0)), 1.0)

func test_full_lock_at_80_percent_turns_tighter_than_12_m():
	# Steady state on full lock at 0.8 x MAX_SPEED: path radius = speed / how fast the velocity direction turns.
	var v := 0.8 * KartTuning.MAX_SPEED
	var steer_right := { "steer": 1.0, "gas": true, "brake": false, "item": false }
	var state := _run(Vector3(0, 0, v), steer_right, 3.0, v)
	var before: Vector3 = state.velocity
	for i in 30:
		state = KartPhysics.step(state.velocity, state.heading, steer_right, v, DT)
	var turned := absf(before.signed_angle_to(state.velocity as Vector3, Vector3.UP))
	var radius: float = state.velocity.length() * (30 * DT) / turned
	assert_lt(radius, 12.0)

func test_wall_bounce_fixed_values():
	var n := Vector3(0, 0, -1)
	assert_almost_eq(KartPhysics.wall_bounce(Vector3(0, 0, 20), n, false), n * KartTuning.WALL_BOUNCE, Vector3.ONE * 1e-5)
	assert_almost_eq(KartPhysics.wall_bounce(Vector3(0, 0, 20), n, true), n * KartTuning.WALL_BOUNCE_BOOSTED, Vector3.ONE * 1e-5)
	# A glancing hit: the tangential part keeps 80 %, the normal part is the fixed bounce.
	var glancing := KartPhysics.wall_bounce(Vector3(10, 0, 20), n, false)
	assert_almost_eq(glancing, Vector3(10 * KartTuning.WALL_SPEED_KEEP, 0, -KartTuning.WALL_BOUNCE), Vector3.ONE * 1e-5)

func test_kart_bounce_in_the_pair_frame():
	var n := Vector3(0, 0, 1) # from b to a: a is ahead, at +Z of b
	var eps := Vector3.ONE * 1e-5
	# b drives into an idle a at 20 m/s: they part at 3 m/s each from the pair's mean speed; sideways speed stays.
	var out := KartPhysics.kart_bounce(Vector3.ZERO, Vector3(1, 0, 20), n, false, false)
	assert_almost_eq(out[0], Vector3(0, 0, 10 + KartTuning.KART_BOUNCE), eps)
	assert_almost_eq(out[1], Vector3(1, 0, 10 - KartTuning.KART_BOUNCE), eps)
	# A rear-end at about the same speed nudges: the front kart speeds up, the rear one slows a little.
	out = KartPhysics.kart_bounce(Vector3(0, 0, 19.5), Vector3(0, 0, 20), n, false, false)
	assert_almost_eq(out[0], Vector3(0, 0, 19.75 + KartTuning.KART_BOUNCE), eps)
	assert_almost_eq(out[1], Vector3(0, 0, 19.75 - KartTuning.KART_BOUNCE), eps)
	out = KartPhysics.kart_bounce(Vector3(0, 0, 19.5), Vector3(0, 0, 20), n, true, true)
	assert_almost_eq(out[0], Vector3(0, 0, 19.75 + KartTuning.KART_BOUNCE), eps, "both boosted: the plain bounce")
	# A boosted b hits a: a flies off at 8, b bounces 2.
	out = KartPhysics.kart_bounce(Vector3(0, 0, 20), Vector3(0, 0, 30), n, false, true)
	assert_almost_eq(out[0], Vector3(0, 0, 25 + KartTuning.KART_BOUNCE_BOOSTED_OTHER), eps)
	assert_almost_eq(out[1], Vector3(0, 0, 25 - KartTuning.KART_BOUNCE_BOOSTED_SELF), eps)
