class_name Rocket extends Area3D
## A fired rocket. With a target it follows the track at its launch lateral and homes onto the target once within
## HOMING_RANGE; without one it flies straight. It hits the first kart it touches (never its shooter) and pops on a
## wall (leaving the road) or at the end of its life.

const SPEED := 40.0 ## m/s
const HOMING_RANGE := 10.0 ## m
const LIFE := 6.0 ## s with a target
const LIFE_UNTARGETED := 3.0 ## s
const HEIGHT := 0.5 ## m above the road

var fired_by: Kart
var target: Kart ## null when fired with nobody ahead

var _world: ItemWorld
var _offset := 0.0 ## m along the track, while following it
var _lateral := 0.0 ## m right of the centre line, while following the track
var _direction := Vector3.FORWARD ## flat unit, while flying straight
var _life_left := 0.0


## at: the launch point on the road; direction: flat unit, the shooter's forward.
func launch(shooter: Kart, aimed_at: Kart, world: ItemWorld, at: Vector3, direction: Vector3) -> void:
	fired_by = shooter
	target = aimed_at
	_world = world
	_offset = world.track.offset_of(at)
	_lateral = world.track.lateral_of(at)
	_direction = direction
	_life_left = LIFE if target != null else LIFE_UNTARGETED
	position = at + Vector3.UP * HEIGHT


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	for area in get_overlapping_areas():
		var kart := area.get_parent() as Kart
		if kart != null and kart != fired_by:
			_world.hit(kart)
			queue_free()
			return

	var track := _world.track
	var aim := target.position + Vector3.UP * HEIGHT if target != null else Vector3.ZERO
	if target != null and position.distance_to(aim) <= HOMING_RANGE:
		_direction = position.direction_to(aim)
		position += _direction * minf(SPEED * delta, position.distance_to(aim))
	elif target != null:
		_offset += SPEED * delta
		var next := track.point_at(_offset, _lateral) + Vector3.UP * HEIGHT
		_direction = position.direction_to(next)
		position = next
	else:
		position += _direction * SPEED * delta
	if absf(track.lateral_of(position)) > Track.ROAD_HALF_WIDTH:
		queue_free()
		return
	var flat := Vector3(_direction.x, 0.0, _direction.z)
	if not flat.is_zero_approx():
		look_at(position + flat)
