class_name KartPhysics extends RefCounted
## Pure kart handling and bounce rules; Kart only wires them to the scene. Values from KartTuning.
## The kart's velocity is split into a forward speed and a sideways (lateral) speed in its own frame. When the kart
## turns, the velocity follows only (1 - SLIP) of the heading change; the rest becomes sideways speed (a slide), which
## decays by GRIP, as does sideways speed from bounces.


## The direction a kart with this heading faces; its rotation.y is the heading.
static func forward(heading: float) -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


## input: `{steer, gas, brake}`, steer +1 is full right. on_mud: above top speed the kart slows by MUD_DECEL, not
## COAST_DECEL. Returns `{velocity, heading}`.
static func step(velocity: Vector3, heading: float, input: Dictionary, top_speed: float, dt: float, on_mud := false) -> Dictionary:
	var fwd := forward(heading)
	var right := fwd.cross(Vector3.UP)
	var f := velocity.dot(fwd)
	var lateral := velocity.dot(right)

	var above_top_decel := KartTuning.MUD_DECEL if on_mud else KartTuning.COAST_DECEL
	if input.gas:
		if f > top_speed:
			f = maxf(top_speed, f - above_top_decel * dt)
		else:
			f = minf(top_speed, f + KartTuning.ACCEL * dt)
	elif input.brake:
		f = move_toward(f, -KartTuning.REVERSE_MAX, KartTuning.BRAKE_DECEL * dt)
	else:
		f = move_toward(f, 0.0, (above_top_decel if f > top_speed else KartTuning.COAST_DECEL) * dt)

	var turn := -float(input.steer) * KartTuning.STEER_RATE * clampf(absf(f) / 5.0, 0.0, 1.0)
	if f < 0.0:
		turn = -turn
	var turned := turn * dt
	heading += turned

	var moved := (fwd * f + right * lateral).rotated(Vector3.UP, (1.0 - KartTuning.SLIP) * turned)
	fwd = forward(heading)
	right = fwd.cross(Vector3.UP)
	return { "velocity": fwd * moved.dot(fwd) + right * moved.dot(right) * exp(-KartTuning.GRIP * dt), "heading": heading }


## normal: the wall's unit normal, pointing away from the wall.
static func wall_bounce(velocity: Vector3, normal: Vector3, boosted: bool) -> Vector3:
	var tangential := velocity - normal * velocity.dot(normal)
	return tangential * KartTuning.WALL_SPEED_KEEP + normal * (KartTuning.WALL_BOUNCE_BOOSTED if boosted else KartTuning.WALL_BOUNCE)


## a, b: the two karts' velocities; n: the unit normal from b to a. Returns `[a, b]` after the bounce. Along n, each
## kart leaves the pair's mean speed at its fixed bounce speed (a rear-end at matched speed is a nudge, not a stop);
## the speeds across n stay. Bounces never spin a kart out.
static func kart_bounce(a: Vector3, b: Vector3, n: Vector3, a_boosted: bool, b_boosted: bool) -> Array[Vector3]:
	var mean := (a + b).dot(n) / 2.0
	return [
		a - n * a.dot(n) + n * (mean + _kart_bounce_speed(a_boosted, b_boosted)),
		b - n * b.dot(n) + n * (mean - _kart_bounce_speed(b_boosted, a_boosted)),
	]


static func _kart_bounce_speed(self_boosted: bool, other_boosted: bool) -> float:
	if self_boosted and not other_boosted:
		return KartTuning.KART_BOUNCE_BOOSTED_SELF
	if other_boosted and not self_boosted:
		return KartTuning.KART_BOUNCE_BOOSTED_OTHER
	return KartTuning.KART_BOUNCE
