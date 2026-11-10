class_name Kart extends CharacterBody3D
## A kart: drives by KartPhysics from `input`, bounces off walls and other karts, boosts on pads, slows on mud, and
## holds one item (rolled for ITEM_ROLL_TIME after a pickup) until it is used.
## The kart faces local +Z (KartPhysics.forward), and rotation.y = heading. It stays at y = 0.

const SPIN_TURNS := 2.0 ## full visual turns of the body during a spin-out
const SLIDE_SPEED := 2.0 ## m/s sideways above which the kart counts as sliding
const BOUNCE_GAP := 0.25 ## s without contact before a wall, or the same kart, bounces it again as a new contact

signal bounced(at: Vector3, boosted: bool) ## a new wall or kart contact; boosted: either kart was boosted
signal spun_out
signal pad_boosted(pad: Area3D)

var slot := -1 ## party slot, -1 for bots
var color := Color.WHITE
var heading := 0.0
var input: Dictionary = BridgeCodec.NEUTRAL.duplicate()
var top_speed_scale := 1.0 ## catch-up, set by the race
var held_item := "" ## ItemDef id, "" when none; set at pickup, usable once roll_left is 0
var roll_left := 0.0 ## s
var held_for := 0.0 ## s since the roll ended

var _boost_left := 0.0
var _spin_left := 0.0
var _shield_left := 0.0
var _since_wall := INF
var _on_mud_now := false
var _bumped := {} # other kart's instance id -> physics frame of the last bump handled for the pair

@onready var _body: Node3D = $Body
@onready var _sensor: Area3D = $Sensor
@onready var _shield_bubble: Node3D = $Shield


func _ready() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 1.0
	$Body/Model/"kart-oobi".material_override = paint
	_sensor.area_entered.connect(_on_area_entered)
	rotation.y = heading


## Refreshes the boost; never shortens what is left.
func boost(seconds: float) -> void:
	_boost_left = maxf(_boost_left, seconds)


func spin_out() -> void:
	_spin_left = KartTuning.SPIN_TIME
	spun_out.emit()


func is_boosted() -> bool:
	return _boost_left > 0.0


## Sideways speed in the kart's own frame above SLIDE_SPEED.
func is_sliding() -> bool:
	return absf(velocity.dot(KartPhysics.forward(heading).cross(Vector3.UP))) > SLIDE_SPEED


## As of the last physics tick.
func is_on_mud() -> bool:
	return _on_mud_now


func is_spinning() -> bool:
	return _spin_left > 0.0


## Starts the roll of an item; does nothing while one is held or rolling.
func give_item(id: String) -> void:
	if held_item != "":
		return
	held_item = id
	roll_left = KartTuning.ITEM_ROLL_TIME
	held_for = 0.0


## ITEM was pressed (the race finds the rising edge): uses the held item, unless it is still rolling or the kart spins.
func use_item_pressed(world: ItemWorld) -> void:
	if held_item == "" or roll_left > 0.0 or is_spinning():
		return
	var item := ItemRegistry.by_id(held_item)
	held_item = ""
	item.use(self, world)


func shield(seconds: float) -> void:
	_shield_left = seconds


func has_shield() -> bool:
	return _shield_left > 0.0


## The shield pops if up, otherwise the kart spins out.
func hit() -> void:
	if has_shield():
		_shield_left = 0.0
	else:
		spin_out()


func touched_wall_recently() -> bool:
	return _since_wall < KartTuning.CATCHUP_WALL_PAUSE


func _physics_process(delta: float) -> void:
	var spinning := _spin_left > 0.0
	var top := KartTuning.MAX_SPEED * top_speed_scale
	if is_boosted():
		top *= KartTuning.BOOST_FACTOR
	var on_mud := _on_mud()
	_on_mud_now = on_mud
	if on_mud:
		top *= KartTuning.MUD_TOP_FACTOR
	var state := KartPhysics.step(velocity, heading, BridgeCodec.NEUTRAL if spinning else input, top, delta, on_mud)
	velocity = state.velocity
	heading = state.heading
	rotation.y = heading
	move_and_slide()
	_bounce()
	position.y = 0.0
	velocity.y = 0.0

	_boost_left = maxf(0.0, _boost_left - delta)
	_spin_left = maxf(0.0, _spin_left - delta)
	_shield_left = maxf(0.0, _shield_left - delta)
	_shield_bubble.visible = has_shield()
	if held_item != "":
		if roll_left > 0.0:
			roll_left = maxf(0.0, roll_left - delta)
		else:
			held_for += delta
	_since_wall += delta
	_body.rotation.y = TAU * SPIN_TURNS * (1.0 - _spin_left / KartTuning.SPIN_TIME) if _spin_left > 0.0 else 0.0


func _bounce() -> void:
	var wall_done := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		normal.y = 0.0
		var other := collision.get_collider()
		if other is Kart:
			_bump(other, normal.normalized(), collision.get_position())
		elif not wall_done:
			wall_done = true
			velocity = KartPhysics.wall_bounce(velocity, normal.normalized(), is_boosted())
			if _since_wall >= BOUNCE_GAP:
				bounced.emit(collision.get_position(), is_boosted())
			_since_wall = 0.0


## Applies the bounce to both karts, once per pair per physics tick, whichever of them sees the contact first.
## away: from the other kart toward this one; at: the contact point.
func _bump(other: Kart, away: Vector3, at: Vector3) -> void:
	var frame := Engine.get_physics_frames()
	var last: int = _bumped.get(other.get_instance_id(), -1)
	if last == frame:
		return
	_bumped[other.get_instance_id()] = frame
	other._bumped[get_instance_id()] = frame
	if last < 0 or frame - last >= BOUNCE_GAP * Engine.physics_ticks_per_second:
		bounced.emit(at, is_boosted() or other.is_boosted())
	var after := KartPhysics.kart_bounce(velocity, other.velocity, away, is_boosted(), other.is_boosted())
	velocity = after[0]
	other.velocity = after[1]


func _on_mud() -> bool:
	for area in _sensor.get_overlapping_areas():
		if area.is_in_group("mud"):
			return true
	return false


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("boost_pad"):
		boost(KartTuning.PAD_BOOST_TIME)
		pad_boosted.emit(area)
