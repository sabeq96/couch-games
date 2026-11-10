extends SceneTree
## Generator, not part of the game (excluded from the export): places the repeated dressing (trees, bushes, stones,
## flowers, fences) as MultiMeshes outside the walls of track.tscn, plus the start arch's bunting, and saves
## res://scenes/scenery/greenery.tscn and res://scenes/scenery/bunting.tres. Rerun it after moving the track.
## Run windowed (the headless renderer keeps no MultiMesh buffers, so it would save empty ones):
##   scripts/godot.sh --path games/racing-carts/godot -s tools/dress_track.gd

const MESHES := "res://scenes/scenery/meshes/"
## Places other scenery takes; nothing random goes within the radius.
const KEEP_OUT := [
	[Vector3(5, 0, -16), 26.0], # spectators, flags and the start arch, outside the start straight
	[Vector3(-60, 0, 120), 16.0], # the pond
	[Vector3(-20, 0, 60), 10.0], # the windmill
	[Vector3(60, 0, 150), 10.0], # the second windmill
]
## Fences only around these spots (start, hairpin, sweeper), to keep the triangle count down.
const FENCED := [Vector3(10, 0, 0), Vector3(112, 0, 28), Vector3(-160, 0, 130)]
const TILE := 160.0 ## m
const AREA := Rect2(-255, -70, 465, 375) # x, z of the grass

var track: Track
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 20261110
	track = load("res://scenes/track.tscn").instantiate()
	root.add_child(track)
	await process_frame
	var greenery := Node3D.new()
	greenery.name = "Greenery"
	_scatter(greenery, "TreesRound", "tree_default", 40, 14.0, 4.5)
	_scatter(greenery, "TreesOak", "tree_oak", 35, 14.0, 6.0)
	_scatter(greenery, "TreesCone", "tree_cone", 35, 14.0, 5.5)
	_scatter(greenery, "Bushes", "plant_bushLarge", 45, 11.0, 6.0)
	_scatter(greenery, "Stones", "stone_largeA", 20, 11.0, 3.5)
	_scatter(greenery, "StonesTall", "stone_tallA", 12, 14.0, 3.0)
	_scatter(greenery, "FlowersPink", "flower_redA", 50, 9.5, 4.0, 30.0)
	_scatter(greenery, "FlowersLilac", "flower_purpleA", 50, 9.5, 4.0, 30.0)
	_scatter(greenery, "FlowersButter", "flower_yellowA", 50, 9.5, 5.0, 30.0)
	_fences(greenery)
	for child in greenery.get_children():
		child.owner = greenery
	var scene := PackedScene.new()
	scene.pack(greenery)
	print("save greenery: ", ResourceSaver.save(scene, "res://scenes/scenery/greenery.tscn"))
	print("save bunting: ", ResourceSaver.save(_bunting(), "res://scenes/scenery/bunting.tres"))
	quit()


## One MultiMeshInstance3D per TILE square, so each view's frustum culls the tiles it does not see.
func _add_tiles(parent: Node3D, node_name: String, mesh_name: String, transforms: Array[Transform3D]) -> void:
	var tiles := {}
	for t in transforms:
		var key := Vector2i(floori((t.origin.x - AREA.position.x) / TILE), floori((t.origin.z - AREA.position.y) / TILE))
		if not tiles.has(key):
			tiles[key] = [] as Array[Transform3D]
		tiles[key].append(t)
	for key in tiles:
		parent.add_child(_instance("%s_%d_%d" % [node_name, key.x, key.y], mesh_name, tiles[key]))


func _instance(node_name: String, mesh_name: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = load(MESHES + mesh_name + ".res")
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	print(node_name, ": ", transforms.size())
	return node


## count instances at random spots at least `near` m from the centre line (and at most `far`, if given).
func _scatter(parent: Node3D, node_name: String, mesh_name: String, count: int, near: float, size: float,
		far := INF) -> void:
	var transforms: Array[Transform3D] = []
	var tries := 0
	while transforms.size() < count and tries < count * 200:
		tries += 1
		var p := Vector3(rng.randf_range(AREA.position.x, AREA.end.x), 0, rng.randf_range(AREA.position.y, AREA.end.y))
		if far < INF:
			# flowers: pick a spot near the road instead, so they are seen
			var offset := rng.randf_range(0, track.length())
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			p = track.point_at(offset, side * rng.randf_range(near, far))
			p.y = 0
		var lateral := absf(track.lateral_of(p))
		if lateral < near or lateral > far or _kept_out(p):
			continue
		var scale := size * rng.randf_range(0.8, 1.25)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale)
		transforms.append(Transform3D(basis, p))
	_add_tiles(parent, node_name, mesh_name, transforms)


func _kept_out(p: Vector3) -> bool:
	for zone in KEEP_OUT:
		if p.distance_to(zone[0]) < zone[1]:
			return true
	return false


## Fence segments (3 m) along both sides, 10 m out, near the FENCED spots; dropped where the other side of a tight turn is too close.
func _fences(parent: Node3D) -> void:
	var transforms: Array[Transform3D] = []
	var offset := 0.0
	while offset < track.length():
		for side in [-1.0, 1.0]:
			var p := track.point_at(offset, side * 10.0)
			p.y = 0
			if absf(track.lateral_of(p)) < 9.5 or p.distance_to(Vector3(5, 0, -16)) < 12.0 and side < 0:
				continue
			if FENCED.all(func(at: Vector3) -> bool: return p.distance_to(at) > 60.0):
				continue
			var dir := track.direction_at(offset)
			var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).scaled(Vector3.ONE * 3.0)
			transforms.append(Transform3D(basis, p))
		offset += 3.0
	_add_tiles(parent, "Fences", "fence_simple", transforms)


## Pennants hanging from the arch's beam (local Z across the road, beam at y = 6).
func _bunting() -> MultiMesh:
	var colours := [Color("#F8A5C2"), Color("#A8E6CF"), Color("#FFE29A"), Color("#CDB4F6"), Color("#A0D2EB")]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = load("res://scenes/scenery/pennant.tres")
	var count := 17
	multimesh.instance_count = count
	for i in count:
		var z := -8.0 + 16.0 * i / (count - 1)
		var sag := 0.6 * (1.0 - pow(z / 8.0, 2)) # the string sags in the middle
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI / 2) * Basis(Vector3.BACK, PI), Vector3(0, 5.4 - sag, z)))
		multimesh.set_instance_color(i, colours[i % colours.size()])
	return multimesh
