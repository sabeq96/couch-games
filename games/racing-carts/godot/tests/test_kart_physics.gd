extends GutTest

const DT := 1.0 / 60.0
const GAS := { "steer": 0.0, "gas": true, "brake": false, "item": false }
const BRAKE := { "steer": 0.0, "gas": false, "brake": true, "item": false }
const NONE := { "steer": 0.0, "gas": false, "brake": false, "item": false }

# Runs `seconds` of steps from velocity v at heading 0 (forward is +Z).
func _run(v: Vector3, input: Dictionary, seconds: float, top := KartTuning.MAX_SPEED) -> Dictionary:
	var state := { "velocity": v, "heading": 0.0 }
	for i in roundi(seconds / DT):
		state = KartPhysics.step(state.velocity, state.heading, input, top, DT)
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

func test_kart_bounce_values():
	var away := Vector3(0, 0, -1) # this kart is at -Z of the other
	var v := Vector3(2, 0, 15)
	assert_almost_eq(KartPhysics.kart_bounce(v, away, false, false), Vector3(2, 0, -3), Vector3.ONE * 1e-5)
	assert_almost_eq(KartPhysics.kart_bounce(v, away, true, true), Vector3(2, 0, -3), Vector3.ONE * 1e-5)
	# Boosted hitter: it bounces 2, the kart it hits flies 8.
	assert_almost_eq(KartPhysics.kart_bounce(v, away, true, false), Vector3(2, 0, -2), Vector3.ONE * 1e-5)
	assert_almost_eq(KartPhysics.kart_bounce(Vector3.ZERO, -away, false, true), Vector3(0, 0, 8), Vector3.ONE * 1e-5)
