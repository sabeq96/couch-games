class_name Kart extends CharacterBody3D
## A kart: drives by KartPhysics from `input`, bounces off walls and other karts, boosts on pads, slows on mud.
## The kart faces local +Z (KartPhysics.forward), and rotation.y = heading. It stays at y = 0.

const T := preload("res://scripts/kart_tuning.gd")
const SPIN_TURNS := 2.0 ## full visual turns of the body during a spin-out

var slot := -1 ## party slot, -1 for bots
var color := Color.WHITE
var heading := 0.0
var input: Dictionary = BridgeCodec.NEUTRAL.duplicate()
var top_speed_scale := 1.0 ## catch-up, set by the race

var _boost_left := 0.0
var _spin_left := 0.0
var _since_wall := INF
var _bumped := {} # other kart's instance id -> physics frame of the last bump handled for the pair

@onready var _body: Node3D = $Body
@onready var _sensor: Area3D = $Sensor


func _ready() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 1.0
	for mesh: MeshInstance3D in [$Body/Chassis, $Body/Seat]:
		mesh.material_override = paint
	_sensor.area_entered.connect(_on_area_entered)
	rotation.y = heading


## Refreshes the boost; never shortens what is left.
func boost(seconds: float) -> void:
	_boost_left = maxf(_boost_left, seconds)


func spin_out() -> void:
	_spin_left = T.SPIN_TIME


func is_boosted() -> bool:
	return _boost_left > 0.0


func touched_wall_recently() -> bool:
	return _since_wall < T.CATCHUP_WALL_PAUSE


func _physics_process(delta: float) -> void:
	var spinning := _spin_left > 0.0
	var top := T.MAX_SPEED * top_speed_scale
	if is_boosted():
		top *= T.BOOST_FACTOR
	if _on_mud():
		top *= T.MUD_TOP_FACTOR
	var state := KartPhysics.step(velocity, heading, BridgeCodec.NEUTRAL if spinning else input, top, delta)
	velocity = state.velocity
	heading = state.heading
	rotation.y = heading
	move_and_slide()
	_bounce()
	position.y = 0.0
	velocity.y = 0.0

	_boost_left = maxf(0.0, _boost_left - delta)
	_spin_left = maxf(0.0, _spin_left - delta)
	_since_wall += delta
	_body.rotation.y = TAU * SPIN_TURNS * (1.0 - _spin_left / T.SPIN_TIME) if _spin_left > 0.0 else 0.0


func _bounce() -> void:
	var wall_done := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.25: # a floor-like contact, not a wall or a kart
			continue
		var other := collision.get_collider()
		if other is Kart:
			_bump(other, normal.normalized())
		elif not wall_done:
			wall_done = true
			velocity = KartPhysics.wall_bounce(velocity, normal.normalized(), is_boosted())
			_since_wall = 0.0


## Applies the bounce to both karts, once per pair per physics tick, whichever of them sees the contact first.
## away: from the other kart toward this one.
func _bump(other: Kart, away: Vector3) -> void:
	var frame := Engine.get_physics_frames()
	if _bumped.get(other.get_instance_id(), -1) == frame:
		return
	_bumped[other.get_instance_id()] = frame
	other._bumped[get_instance_id()] = frame
	var mine := is_boosted()
	var theirs := other.is_boosted()
	velocity = KartPhysics.kart_bounce(velocity, away, mine, theirs)
	other.velocity = KartPhysics.kart_bounce(other.velocity, -away, theirs, mine)


func _on_mud() -> bool:
	for area in _sensor.get_overlapping_areas():
		if area.is_in_group("mud"):
			return true
	return false


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("boost_pad"):
		boost(T.PAD_BOOST_TIME)
