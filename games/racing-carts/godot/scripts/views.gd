class_name Views extends Control
## The split screen: one view per kart given to `setup`, laid out by ViewLayout, each a SubViewport on the race's
## world with its own ChaseCamera, framed by a border in the kart's colour.

const BORDER := 4 ## px

var _slots: Array[int] = [] ## view order
var _frames: Array[ColorRect] = []
var _cameras: Array[ChaseCamera] = []


func _ready() -> void:
	resized.connect(_layout)


## karts_by_slot: the karts to view, lowest slot first.
func setup(karts_by_slot: Array[Kart], world: World3D) -> void:
	for kart in karts_by_slot:
		var frame := ColorRect.new()
		frame.color = kart.color
		var container := SubViewportContainer.new()
		container.stretch = true
		var viewport := SubViewport.new()
		viewport.world_3d = world
		var camera := ChaseCamera.new()
		viewport.add_child(camera)
		container.add_child(viewport)
		frame.add_child(container)
		add_child(frame)
		camera.current = true
		camera.target = kart
		_slots.append(kart.slot)
		_frames.append(frame)
		_cameras.append(camera)
	_layout()


func view_count() -> int:
	return _cameras.size()


## The camera of the view for that party slot, or null.
func camera_for(slot: int) -> ChaseCamera:
	var i := _slots.find(slot)
	return _cameras[i] if i >= 0 else null


func _layout() -> void:
	var rects := ViewLayout.rects(_frames.size(), size)
	for i in _frames.size():
		_frames[i].position = rects[i].position
		_frames[i].size = rects[i].size
		var container: SubViewportContainer = _frames[i].get_child(0)
		container.position = Vector2(BORDER, BORDER)
		container.size = (rects[i].size - Vector2(BORDER, BORDER) * 2).max(Vector2.ZERO)
