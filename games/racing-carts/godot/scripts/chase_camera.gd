class_name ChaseCamera extends Camera3D
## Follows `target` from behind and above, easing toward the kart's heading and position. `shake()` jolts it briefly.

const BEHIND := 7.0 ## m
const ABOVE := 3.0 ## m
const LOOK_AHEAD := 4.0 ## m, the aim point ahead of the kart
const LOOK_HEIGHT := 1.0 ## m
const HEADING_SMOOTHING := 6.0 ## 1/s
const POSITION_SMOOTHING := 8.0 ## 1/s
const FOV := 70.0 ## degrees
const SHAKE_AMPLITUDE := 0.3 ## m, decaying linearly to 0
const SHAKE_TIME := 0.4 ## s
const SHAKE_RATE := 40.0 ## rad/s of the shake wobble

var target: Kart: ## a new target snaps the camera behind it; setting the same one again changes nothing
	set(kart):
		if kart != target:
			target = kart
			_snapped = false

var _heading := 0.0
var _base := Vector3.ZERO ## eased position, before the shake
var _snapped := false
var _shake_left := 0.0
var _shake_time := 0.0


func _ready() -> void:
	fov = FOV


func shake() -> void:
	_shake_left = SHAKE_TIME
	_shake_time = 0.0


## The current shake displacement; zero when not shaking.
func shake_offset() -> Vector3:
	if _shake_left <= 0.0:
		return Vector3.ZERO
	var t := _shake_time * SHAKE_RATE
	return Vector3(sin(t), cos(t * 1.3), sin(t * 0.7)).normalized() * SHAKE_AMPLITUDE * _shake_left / SHAKE_TIME


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var just_snapped := not _snapped
	if just_snapped:
		_heading = target.heading
		_base = _wanted()
		_snapped = true
	else:
		_heading = lerp_angle(_heading, target.heading, 1.0 - exp(-HEADING_SMOOTHING * delta))
		_base = _base.lerp(_wanted(), 1.0 - exp(-POSITION_SMOOTHING * delta))
	if _shake_left > 0.0:
		_shake_time += delta
		_shake_left = maxf(_shake_left - delta, 0.0)
	global_position = _base + shake_offset()
	look_at(target.position + KartPhysics.forward(_heading) * LOOK_AHEAD + Vector3.UP * LOOK_HEIGHT)
	if just_snapped:
		reset_physics_interpolation() # a cut to the new target, not a sweep


func _wanted() -> Vector3:
	return target.position - KartPhysics.forward(_heading) * BEHIND + Vector3.UP * ABOVE
