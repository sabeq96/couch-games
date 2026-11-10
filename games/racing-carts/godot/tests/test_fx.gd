extends GutTest
# The particle effects: every scene under scenes/fx/, one-shots that free themselves, and the kart's continuous
# effects following its state.

const FX_DIR := "res://scenes/fx/"
const MAX_PARTICLES := 64

var arena: Node3D
var fx: Fx

func before_each():
	arena = Node3D.new()
	add_child_autofree(arena)
	var floor := StaticBody3D.new()
	floor.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(60, 1, 60)
	floor.add_child(shape)
	arena.add_child(floor)
	fx = Fx.new()
	arena.add_child(fx)

func _kart() -> Kart:
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	kart.input = { "steer": 0.0, "gas": false, "brake": false, "item": false }
	arena.add_child(kart)
	return kart

func test_each_fx_scene_instances():
	var files := Array(DirAccess.get_files_at(FX_DIR)).filter(func(f): return f.ends_with(".tscn"))
	assert_gt(files.size(), 10, "fx scenes found")
	for file in files:
		var node = load(FX_DIR + file).instantiate()
		assert_true(node is CPUParticles3D, file)
		if node is CPUParticles3D:
			assert_lte(node.amount, MAX_PARTICLES, "%s: at most %d particles" % [file, MAX_PARTICLES])
		node.free()
	for name in Fx.SCENES:
		assert_true(files.has(Fx.SCENES[name].resource_path.get_file()), "%s is under %s" % [name, FX_DIR])

func test_one_shot_fx_free_themselves():
	var longest := 0.0
	var spawned := 0
	for name in Fx.SCENES:
		var probe: CPUParticles3D = Fx.SCENES[name].instantiate()
		var one_shot := probe.one_shot
		probe.free()
		if one_shot:
			longest = maxf(longest, fx.spawn(name, Vector3(0, 1, 0)).lifetime)
			spawned += 1
	assert_gt(spawned, 5, "one-shots spawned")
	assert_eq(fx.get_child_count(), spawned, "alive while they play")
	await wait_seconds(longest + Fx.FREE_MARGIN + 0.1)
	assert_eq(fx.get_child_count(), 0, "all freed")

func test_boost_flame_follows_boost():
	var kart := _kart()
	var flame := fx.attach("boost_flame", kart)
	await wait_physics_frames(2)
	assert_false(flame.emitting, "off before the boost")
	kart.boost(0.2)
	await wait_physics_frames(2)
	assert_true(flame.emitting, "on while boosted")
	await wait_seconds(0.3)
	assert_false(kart.is_boosted(), "boost over")
	assert_false(flame.emitting, "off after the boost")

func test_slide_dust_threshold():
	var kart := _kart()
	kart.set_physics_process(false) # keep the velocity as set; KartPhysics would let the slide decay
	var dust := fx.attach("slide_dust", kart)
	var right := KartPhysics.forward(kart.heading).cross(Vector3.UP)
	kart.velocity = KartPhysics.forward(kart.heading) * 15.0 + right * 1.5
	await wait_physics_frames(2)
	assert_false(dust.emitting, "1.5 m/s sideways: no dust")
	kart.velocity = KartPhysics.forward(kart.heading) * 15.0 - right * 2.5
	await wait_physics_frames(2)
	assert_true(dust.emitting, "2.5 m/s sideways: dust")

func test_one_shot_on_a_node_rides_on_it_and_frees():
	var kart := _kart()
	var stars := fx.spawn("slip_stars", Vector3.UP, kart)
	assert_eq(stars.get_parent(), kart, "rides on the kart")
	assert_eq(stars.position, Vector3.UP, "placed in the kart's frame")
	await wait_seconds(stars.lifetime + Fx.FREE_MARGIN + 0.1)
	assert_false(is_instance_valid(stars), "freed")

func test_box_pickup_bursts_through_the_world():
	var world := ItemWorld.new()
	world.fx = fx
	arena.add_child(world)
	var box: ItemBox = load("res://scenes/item_box.tscn").instantiate()
	box.world = world
	box.position = Vector3(3, 0, 0)
	arena.add_child(box)
	var kart := _kart()
	box._on_area_entered(kart.get_node("Sensor"))
	assert_eq(fx.get_child_count(), 1, "one burst")
	assert_eq(fx.get_child(0).global_position, box.global_position, "at the box")
	assert_ne(kart.held_item, "", "the pickup still rolls an item")

func test_world_spawns_and_attaches_through_its_fx():
	var world := ItemWorld.new()
	world.fx = fx
	arena.add_child(world)
	var burst := world.spawn_fx("box_burst", Vector3(1, 2, 3))
	assert_eq(burst.get_parent(), fx, "under the Fx")
	assert_eq(burst.global_position, Vector3(1, 2, 3), "at the point")
	var owner_node := Node3D.new()
	arena.add_child(owner_node)
	assert_eq(world.attach_fx("rocket_trail", owner_node).get_parent(), owner_node, "on its owner")

func test_box_pickup_sounds_follow_the_roll():
	var sfx := Sfx.new()
	arena.add_child(sfx)
	var world := ItemWorld.new()
	world.sfx = sfx
	arena.add_child(world)
	var kart := _kart()
	world.karts = [kart]
	world.order = [0]
	world.distances = [0.0]
	var box: ItemBox = load("res://scenes/item_box.tscn").instantiate()
	box.world = world
	arena.add_child(box)
	watch_signals(sfx)
	box._on_area_entered(kart.get_node("Sensor"))
	assert_signal_emit_count(sfx, "played", 2, "pickup and roulette")
	assert_signal_emitted_with_parameters(sfx, "played", ["item_roulette"])
	box._respawn_left = 0.0
	box._on_area_entered(kart.get_node("Sensor"))
	assert_signal_emit_count(sfx, "played", 3, "already rolling: only the pickup")
	assert_signal_emitted_with_parameters(sfx, "played", ["item_box_pickup"])
