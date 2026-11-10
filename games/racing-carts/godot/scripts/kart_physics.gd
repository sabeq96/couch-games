class_name KartPhysics extends RefCounted
## Pure kart handling and bounce rules; Kart only wires them to the scene. Values from KartTuning.
## The kart's velocity is split into a forward speed and a sideways (lateral) speed in its own frame. When the kart
## turns, the velocity follows only (1 - SLIP) of the heading change; the rest becomes sideways speed (a slide), which
## decays by GRIP, as does sideways speed from bounces.


## The direction a kart with this heading faces; its rotation.y is the heading.
static func forward(heading: float) -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


## input: `{steer, gas, brake}`, steer +1 is full right. Returns `{velocity, heading}`.
static func step(velocity: Vector3, heading: float, input: Dictionary, top_speed: float, dt: float) -> Dictionary:
	var fwd := forward(heading)
	var right := fwd.cross(Vector3.UP)
	var f := velocity.dot(fwd)
	var lateral := velocity.dot(right)

	if input.gas:
		if f > top_speed:
			f = maxf(top_speed, f - KartTuning.COAST_DECEL * dt)
		else:
			f = minf(top_speed, f + KartTuning.ACCEL * dt)
	elif input.brake:
		f = move_toward(f, -KartTuning.REVERSE_MAX, KartTuning.BRAKE_DECEL * dt)
	else:
		f = move_toward(f, 0.0, KartTuning.COAST_DECEL * dt)

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


## away: the unit vector from the other kart to this one. Bounces never spin a kart out.
static func kart_bounce(velocity: Vector3, away: Vector3, self_boosted: bool, other_boosted: bool) -> Vector3:
	var speed := KartTuning.KART_BOUNCE
	if self_boosted and not other_boosted:
		speed = KartTuning.KART_BOUNCE_BOOSTED_SELF
	elif other_boosted and not self_boosted:
		speed = KartTuning.KART_BOUNCE_BOOSTED_OTHER
	return velocity - away * velocity.dot(away) + away * speed
