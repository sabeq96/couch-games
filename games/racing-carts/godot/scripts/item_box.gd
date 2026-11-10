class_name ItemBox extends Area3D
## An item box: a kart touching it takes it (the world rolls an item, if the kart holds none) and it comes back
## BOX_RESPAWN seconds later.

const TURN_RATE := 1.0 ## rad/s of the cube

var world: ItemWorld ## set by the race; without one (a track on its own) a pickup only hides the box

var _respawn_left := 0.0

@onready var _cube: Node3D = $Cube


func _ready() -> void:
	_cube.physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF # spun per frame in _process
	area_entered.connect(_on_area_entered)


func is_available() -> bool:
	return _respawn_left <= 0.0


func _process(delta: float) -> void:
	_cube.rotate_y(TURN_RATE * delta)


func _physics_process(delta: float) -> void:
	if _respawn_left > 0.0:
		_respawn_left = maxf(0.0, _respawn_left - delta)
		visible = _respawn_left <= 0.0


func _on_area_entered(area: Area3D) -> void:
	var kart := area.get_parent() as Kart
	if kart == null or not is_available():
		return
	_respawn_left = KartTuning.BOX_RESPAWN
	visible = false
	if world != null:
		var rolls := kart.held_item == ""
		world.on_box(kart)
		world.play_sound("item_box_pickup")
		if rolls:
			world.play_sound("item_roulette")
		if world.fx != null:
			world.fx.spawn("box_burst", global_position)
