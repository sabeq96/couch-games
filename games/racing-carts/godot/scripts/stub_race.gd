extends Node3D
## Milestone 1 stand-in for the race: one box per player on a floor. GAS drives, steer turns, and the first
## ITEM press finishes the race with that player first.

const SPEED := 5.0 # m/s
const TURN_RATE := 2.0 # rad/s at full steer

@onready var _bridge: Bridge = $Bridge
var _boxes := {} # slot -> MeshInstance3D
var _item_was_down := {} # slot -> bool


func _ready() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60, 60)
	add_child(_mesh(floor_mesh, Color(0.3, 0.32, 0.35)))

	var camera := Camera3D.new()
	camera.position = Vector3(0, 25, 0)
	camera.rotation_degrees.x = -90
	add_child(camera)
	camera.make_current()

	var n := _bridge.players.size()
	for i in n:
		var player: Dictionary = _bridge.players[i]
		var box := _mesh(BoxMesh.new(), player.color)
		box.position = Vector3((i - (n - 1) / 2.0) * 2.0, 0.5, 0)
		add_child(box)
		_boxes[player.slot] = box


func _physics_process(delta: float) -> void:
	var karts: Array[Dictionary] = []
	var pressed := -1
	for slot in _slots():
		var input := _bridge.input_for(slot)
		var box: MeshInstance3D = _boxes[slot]
		box.rotate_y(-input.steer * TURN_RATE * delta)
		if input.gas:
			box.position += -box.basis.z * SPEED * delta
		if input.item and not _item_was_down.get(slot, false) and pressed < 0:
			pressed = slot
		_item_was_down[slot] = input.item
		karts.append({ "slot": slot, "x": box.position.x, "z": box.position.z })
	_bridge.report_karts(karts)
	if pressed >= 0:
		var order: Array[int] = [pressed]
		for slot in _slots():
			if slot != pressed:
				order.append(slot)
		_bridge.send_finish(order)


## Player slots in slot order.
func _slots() -> Array[int]:
	var slots: Array[int] = []
	for slot in _boxes:
		slots.append(slot)
	slots.sort()
	return slots


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance
