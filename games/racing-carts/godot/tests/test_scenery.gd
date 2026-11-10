extends GutTest
# The track dressing: every scenery scene instances, the windmill turns, and nothing in the track's Scenery can touch
# a kart (no body on a layer the kart masks) or stands on the road (everything low sits outside the walls).

const SCENES := [
	"res://scenes/scenery/windmill.tscn",
	"res://scenes/scenery/balloon.tscn",
	"res://scenes/scenery/cloud.tscn",
	"res://scenes/scenery/flag.tscn",
	"res://scenes/scenery/spectator.tscn",
	"res://scenes/scenery/start_arch.tscn",
	"res://scenes/scenery/pond.tscn",
	"res://scenes/scenery/greenery.tscn",
	"res://scenes/scenery/hills.tscn",
]
const OUTSIDE_WALLS := 8.0 # m from the centre line; the walls' outer faces are at 7
const OVERHEAD := 4.0 # m; things this high (the arch's beam and bunting, balloons, clouds) may be over the road

func _track() -> Track:
	var track: Track = load("res://scenes/track.tscn").instantiate()
	add_child_autofree(track)
	return track

func test_every_scenery_scene_instances():
	for path in SCENES:
		var scene: PackedScene = load(path)
		assert_not_null(scene, path)
		if scene:
			var node := scene.instantiate()
			assert_true(node is Node3D, path)
			node.free()

func test_windmill_turns():
	var windmill: Node3D = load("res://scenes/scenery/windmill.tscn").instantiate()
	add_child_autofree(windmill)
	var blades: Node3D = windmill.get_node("Blades")
	var before := blades.rotation.z
	await wait_physics_frames(60)
	assert_gt(absf(angle_difference(before, blades.rotation.z)), 0.1, "the blades turned")

func test_track_has_scenery():
	var scenery := _track().get_node_or_null("Scenery")
	assert_not_null(scenery)
	if scenery:
		for path in SCENES:
			assert_true(_instances_of(scenery, path) > 0, "the track uses " + path)

func test_no_scenery_collides_with_karts():
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	add_child_autofree(kart)
	var masks: int = kart.collision_mask | kart.get_node("Sensor").collision_mask
	assert_ne(masks, 0, "the kart masks some layer")
	for body in _track().get_node("Scenery").find_children("*", "CollisionObject3D", true, false):
		assert_eq(body.collision_layer & masks, 0, str(body.get_path()))

func test_scenery_stays_off_the_road():
	var track := _track()
	var checked := 0
	for node in track.get_node("Scenery").find_children("*", "GeometryInstance3D", true, false):
		for point in _points(node):
			if point.y >= OVERHEAD:
				continue
			checked += 1
			assert_gt(absf(track.lateral_of(point)), OUTSIDE_WALLS, "%s at %s" % [node.get_path(), point])
	assert_gt(checked, 100, "low scenery checked")

## World positions of a geometry node: each instance of a MultiMesh, else the node itself.
func _points(node: GeometryInstance3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is MultiMeshInstance3D:
		var origins := _saved_origins(node.multimesh)
		assert_eq(origins.size(), node.multimesh.instance_count, str(node.get_path()))
		for origin in origins:
			points.append(node.global_transform * origin)
	else:
		points.append(node.global_position)
	return points

## Instance origins as saved in the MultiMesh's file. The headless renderer GUT runs on keeps no MultiMesh buffer, so
## get_instance_transform returns identity there; the saved buffer is read instead (12 floats per transform, origin at
## 3, 7 and 11, then 4 per colour and 4 per custom data).
func _saved_origins(multimesh: MultiMesh) -> Array[Vector3]:
	var path := multimesh.resource_path.get_slice("::", 0)
	var header := "[resource]"
	if multimesh.resource_path.contains("::"):
		header = '[sub_resource type="MultiMesh" id="%s"]' % multimesh.resource_path.get_slice("::", 1)
	var text := FileAccess.get_file_as_string(path)
	var from := text.find("buffer = PackedFloat32Array(", text.find(header)) + "buffer = PackedFloat32Array(".length()
	var values := text.substr(from, text.find(")", from) - from).split_floats(",")
	var stride := 12 + (4 if multimesh.use_colors else 0) + (4 if multimesh.use_custom_data else 0)
	var origins: Array[Vector3] = []
	for i in range(0, values.size(), stride):
		origins.append(Vector3(values[i + 3], values[i + 7], values[i + 11]))
	return origins

func _instances_of(root: Node, path: String) -> int:
	var count := 0
	for node in root.find_children("*", "", true, false):
		if node.scene_file_path == path:
			count += 1
	return count
