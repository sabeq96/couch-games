extends GutTest
# The four items: boost and shield on a kart, bananas in a small arena, rockets and the bot decision on the real track.

var arena: Node3D
var world: ItemWorld

func before_each():
	arena = Node3D.new()
	add_child_autofree(arena)
	world = ItemWorld.new()
	arena.add_child(world)

# A flat floor for karts that drive.
func _floor() -> void:
	var floor := StaticBody3D.new()
	floor.position = Vector3(0, -0.5, 0)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(60, 1, 60)
	var shape := CollisionShape3D.new()
	shape.shape = box_shape
	floor.add_child(shape)
	arena.add_child(floor)

func _track() -> Track:
	var track: Track = load("res://scenes/track.tscn").instantiate()
	arena.add_child(track)
	world.track = track
	return track

# A straight 400 m track along +Z from the origin (offset = z), with no walls: only the road width bounds rockets.
func _straight_track() -> Track:
	var track := Track.new()
	var centre := Path3D.new()
	centre.name = "CentreLine"
	centre.curve = Curve3D.new()
	centre.curve.add_point(Vector3.ZERO)
	centre.curve.add_point(Vector3(0, 0, 400))
	track.add_child(centre)
	arena.add_child(track)
	world.track = track
	return track

# A kart at rest at `at`, facing heading (0 = +Z).
func _kart(at: Vector3, heading := 0.0) -> Kart:
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	kart.position = at
	kart.heading = heading
	arena.add_child(kart)
	return kart

# A kart on the track at `offset`, facing the direction of travel.
func _kart_on(track: Track, offset: float, lateral := 0.0) -> Kart:
	var d := track.direction_at(offset)
	return _kart(track.point_at(offset, lateral), atan2(d.x, d.z))

# Gives the kart an item that has finished rolling.
func _hold(kart: Kart, id: String) -> void:
	kart.give_item(id)
	kart.roll_left = 0.0

func _use(kart: Kart, id: String) -> void:
	_hold(kart, id)
	kart.use_item_pressed(world)

func _in_world(group: String) -> Array:
	return world.get_children().filter(func(n): return n.is_in_group(group) and not n.is_queued_for_deletion())

# Physics frames until condition holds (or max_frames).
func _until(condition: Callable, max_frames: int) -> int:
	var start := Engine.get_physics_frames()
	while not condition.call() and Engine.get_physics_frames() - start < max_frames:
		await get_tree().physics_frame
	return Engine.get_physics_frames() - start

func _bot() -> BotDriver:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return BotDriver.new(rng)

func test_boost_item_boosts_1_5_s():
	var kart := _kart(Vector3.ZERO)
	_use(kart, "boost")
	assert_true(kart.is_boosted())
	await wait_physics_frames(90 - 3)
	assert_true(kart.is_boosted(), "still boosted just before 1.5 s")
	await wait_physics_frames(6)
	assert_false(kart.is_boosted(), "over after 1.5 s")

func test_shield_absorbs_one_hit():
	_floor()
	var kart := _kart(Vector3(0, 0, -6))
	kart.velocity = Vector3(0, 0, 10)
	var dropper := _kart(Vector3(0, 0, 2.5))
	_use(dropper, "banana")
	_use(kart, "shield")
	assert_true(kart.has_shield())
	await wait_physics_frames(1)
	assert_true(kart.get_node("Shield").visible, "the bubble shows")
	await _until(func(): return not kart.has_shield(), 120)
	assert_false(kart.has_shield(), "a banana pops the shield")
	assert_false(kart.is_spinning(), "no spin")
	assert_eq(_in_world("banana").size(), 0, "the banana is gone")
	await wait_physics_frames(1)
	assert_false(kart.get_node("Shield").visible, "the bubble is gone")
	world.hit(kart)
	assert_true(kart.is_spinning(), "the next hit spins")

func test_shield_expires_after_6_s():
	var kart := _kart(Vector3.ZERO)
	_use(kart, "shield")
	await wait_physics_frames(360 - 3)
	assert_true(kart.has_shield(), "still up just before 6 s")
	await wait_physics_frames(6)
	assert_false(kart.has_shield(), "gone after 6 s")

func test_banana_spins_first_kart():
	_floor()
	var dropper := _kart(Vector3(0, 0, 10))
	_use(dropper, "banana")
	var bananas := _in_world("banana")
	assert_eq(bananas.size(), 1)
	assert_almost_eq(bananas[0].position.distance_to(dropper.position), 2.5, 0.01, "dropped 2.5 m behind")
	assert_lt(bananas[0].position.z, dropper.position.z, "behind the dropper")
	var first := _kart(Vector3(0, 0, 0))
	first.velocity = Vector3(0, 0, 8)
	await _until(func(): return first.is_spinning(), 120)
	assert_true(first.is_spinning(), "the first kart over it spins")
	assert_false(dropper.is_spinning())
	assert_eq(_in_world("banana").size(), 0, "one hit, then gone")

func test_banana_owner_grace():
	_floor()
	var kart := _kart(Vector3.ZERO)
	var banana: Node3D = load("res://scenes/banana.tscn").instantiate()
	banana.dropped_by = kart
	banana.world = world
	banana.position = kart.position
	world.spawn(banana)
	await wait_physics_frames(24)
	assert_false(kart.is_spinning(), "the owner is safe at first")
	var frames := 24 + await _until(func(): return kart.is_spinning(), 60)
	assert_true(kart.is_spinning(), "then hit by its own banana")
	assert_between(frames, 30, 34, "after 0.5 s")

func test_banana_expires_after_30_s():
	var kart := _kart(Vector3.ZERO)
	_use(kart, "banana")
	await wait_physics_frames(30 * 60 - 5)
	assert_eq(_in_world("banana").size(), 1, "still there just before 30 s")
	await wait_physics_frames(10)
	assert_eq(_in_world("banana").size(), 0, "gone after 30 s")

func test_rocket_hits_kart_ahead():
	var track := _track()
	var shooter := _kart_on(track, 100.0)
	var target := _kart_on(track, 140.0, 2.0)
	world.karts = [shooter, target]
	world.order = [1, 0]
	world.distances = [100.0, 140.0]
	_use(shooter, "rocket")
	assert_eq(_in_world("rocket").size(), 1)
	assert_true(world.targeted_by_rocket(target), "aimed at the kart ahead")
	assert_false(world.targeted_by_rocket(shooter))
	var frames := await _until(func(): return target.is_spinning(), 120)
	assert_true(target.is_spinning(), "the kart ahead is hit")
	assert_false(shooter.is_spinning())
	gut.p("rocket hit after %d frames" % frames)
	await wait_physics_frames(1)
	assert_eq(_in_world("rocket").size(), 0, "the rocket is gone")
	assert_false(world.targeted_by_rocket(target))

# The leader fires with nobody ahead, aimed across the road: it flies straight, pops on the wall and spares the kart
# behind.
func test_rocket_without_target_pops():
	var track := _track()
	var shooter := _kart_on(track, 100.0)
	shooter.heading += 0.5
	var behind := _kart_on(track, 90.0)
	world.karts = [shooter, behind]
	world.order = [0, 1]
	world.distances = [100.0, 90.0]
	_use(shooter, "rocket")
	assert_eq(_in_world("rocket").size(), 1)
	assert_false(world.targeted_by_rocket(behind))
	var frames := await _until(func(): return _in_world("rocket").is_empty(), 240)
	assert_lt(frames, 60, "pops on the wall well before its 3 s")
	assert_false(behind.is_spinning(), "the kart behind is spared")
	assert_false(shooter.is_spinning())

func test_bot_uses_rocket_when_kart_ahead_in_range():
	var track := _track()
	var kart := _kart_on(track, 100.0)
	var ahead := _kart_on(track, 130.0)
	world.karts = [kart, ahead]
	world.order = [1, 0]
	world.distances = [100.0, 130.0]
	_hold(kart, "rocket")
	var bot := _bot()
	assert_true(bot.input_for(kart, track, 1.0 / 60.0, world).item, "fires at 30 m")
	assert_false(bot.input_for(kart, track, 1.0 / 60.0, world).item, "for one tick")
	world.distances = [100.0, 180.0]
	var far := _bot()
	assert_false(far.input_for(kart, track, 1.0 / 60.0, world).item, "holds at 80 m")

func test_bot_drops_banana_when_followed():
	var track := _track()
	var kart := _kart_on(track, 100.0)
	var behind := _kart_on(track, 90.0)
	world.karts = [kart, behind]
	world.order = [0, 1]
	world.distances = [100.0, 90.0]
	_hold(kart, "banana")
	var bot := _bot()
	assert_true(bot.input_for(kart, track, 1.0 / 60.0, world).item, "drops with a kart 10 m behind")
	assert_false(bot.input_for(kart, track, 1.0 / 60.0, world).item, "for one tick")
	world.distances = [100.0, 80.0]
	var far := _bot()
	assert_false(far.input_for(kart, track, 1.0 / 60.0, world).item, "holds with the kart 20 m behind")

func test_bot_raises_shield_when_targeted():
	var track := _track()
	var shooter := _kart_on(track, 100.0)
	var kart := _kart_on(track, 140.0)
	world.karts = [shooter, kart]
	world.order = [1, 0]
	world.distances = [100.0, 140.0]
	_hold(kart, "shield")
	var bot := _bot()
	assert_false(bot.input_for(kart, track, 1.0 / 60.0, world).item, "no reason yet")
	_use(shooter, "rocket")
	assert_true(bot.input_for(kart, track, 1.0 / 60.0, world).item, "a rocket targets it")
	var later := _bot()
	for rocket in _in_world("rocket"):
		rocket.free()
	kart.held_for = 5.5
	assert_true(later.input_for(kart, track, 1.0 / 60.0, world).item, "held over 5 s")

func test_untargeted_rocket_lives_3_s():
	var track := _straight_track()
	var shooter := _kart_on(track, 10.0)
	world.karts = [shooter]
	world.order = [0]
	world.distances = [10.0]
	_use(shooter, "rocket")
	await wait_physics_frames(175)
	assert_eq(_in_world("rocket").size(), 1, "still flying at 175 frames")
	var frames := 175 + await _until(func(): return _in_world("rocket").is_empty(), 60)
	assert_between(frames, 180 - 2, 180 + 2, "gone after 3 s")

func test_targeted_rocket_lives_6_s():
	var track := _straight_track()
	var shooter := _kart_on(track, 10.0)
	var target := _kart_on(track, 390.0) # beyond the 240 m a rocket flies in 6 s
	world.karts = [shooter, target]
	world.order = [1, 0]
	world.distances = [10.0, 390.0]
	_use(shooter, "rocket")
	assert_true(world.targeted_by_rocket(target))
	await wait_physics_frames(355)
	assert_eq(_in_world("rocket").size(), 1, "still flying at 355 frames")
	var frames := 355 + await _until(func(): return _in_world("rocket").is_empty(), 60)
	assert_between(frames, 360 - 2, 360 + 2, "gone after 6 s")
	assert_false(target.is_spinning())

func test_rocket_reaches_target_across_the_road():
	var track := _straight_track()
	var shooter := _kart_on(track, 10.0, -5.5)
	var target := _kart_on(track, 50.0, 5.5)
	world.karts = [shooter, target]
	world.order = [1, 0]
	world.distances = [10.0, 50.0]
	_use(shooter, "rocket")
	await _until(func(): return target.is_spinning(), 180)
	assert_true(target.is_spinning(), "hit at the opposite road edge")

func test_bot_boosts_on_a_straight_not_before_a_corner():
	var track := _track()
	var straight := 0.0
	var corner := 0.0
	var offset := 0.0
	while offset < track.length():
		if track.turn_ahead(offset, 40.0) < track.turn_ahead(straight, 40.0):
			straight = offset
		if track.turn_ahead(offset, 40.0) > track.turn_ahead(corner, 40.0):
			corner = offset
		offset += 5.0
	var boost := ItemRegistry.by_id("boost")
	var on_straight := _kart_on(track, straight)
	var before_corner := _kart_on(track, corner)
	assert_true(boost.bot_should_use(on_straight, world, 0.0), "boosts at offset %.0f" % straight)
	assert_false(boost.bot_should_use(before_corner, world, 0.0), "holds before the corner at %.0f" % corner)

func test_bot_never_presses_while_rolling_or_spinning():
	var track := _track()
	var kart := _kart_on(track, 100.0)
	var ahead := _kart_on(track, 130.0)
	world.karts = [kart, ahead]
	world.order = [1, 0]
	world.distances = [100.0, 130.0]
	kart.give_item("rocket")
	assert_true(ItemRegistry.by_id("rocket").bot_should_use(kart, world, 0.0), "the rule says yes")
	assert_false(_bot().input_for(kart, track, 1.0 / 60.0, world).item, "not while rolling")
	kart.roll_left = 0.0
	kart.spin_out()
	assert_false(_bot().input_for(kart, track, 1.0 / 60.0, world).item, "not while spinning")

func test_bot_drops_banana_after_holding_it_long():
	var track := _track()
	var kart := _kart_on(track, 100.0)
	world.karts = [kart]
	world.order = [0]
	world.distances = [100.0]
	_hold(kart, "banana")
	assert_false(_bot().input_for(kart, track, 1.0 / 60.0, world).item, "nobody behind")
	kart.held_for = 10.5
	assert_true(_bot().input_for(kart, track, 1.0 / 60.0, world).item, "dropped anyway after 10 s")

func test_bot_fires_rocket_after_holding_it_long():
	var track := _track()
	var kart := _kart_on(track, 100.0)
	world.karts = [kart]
	world.order = [0]
	world.distances = [100.0]
	_hold(kart, "rocket")
	assert_false(_bot().input_for(kart, track, 1.0 / 60.0, world).item, "nobody ahead")
	kart.held_for = 10.5
	assert_true(_bot().input_for(kart, track, 1.0 / 60.0, world).item, "fired anyway after 10 s")

func test_item_without_a_bot_rule_is_used_by_bots():
	var kart := _kart(Vector3.ZERO)
	var fake := ItemDef.new()
	fake.id = "fake"
	assert_true(fake.bot_should_use(kart, world, 0.0))

func test_adding_an_item_is_one_file():
	assert_eq(ItemRegistry.ITEMS.size(), 4)
	assert_eq(ItemRegistry.all().size(), ItemRegistry.ITEMS.size(), "one item per ITEMS line")
	var ids: Array[String] = []
	for item in ItemRegistry.all():
		ids.append(item.id)
		assert_ne(item.icon, "", item.id + " has an icon")
	ids.sort()
	assert_eq(ids, ["banana", "boost", "rocket", "shield"] as Array[String])
