extends GutTest
# A bot drives the real track.

var track: Track

func before_each():
	track = load("res://scenes/track.tscn").instantiate()
	add_child_autofree(track)

# One kart on grid slot 0.
func _kart_on_the_grid() -> Kart:
	var grid := track.grid_transform(0)
	var d := -grid.basis.z
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	kart.position = grid.origin
	kart.heading = atan2(d.x, d.z)
	add_child_autofree(kart)
	return kart

func _bot(seed: int) -> BotDriver:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return BotDriver.new(rng)

func test_bot_stays_on_the_road_and_gains_distance():
	var kart := _kart_on_the_grid()
	var bot := _bot(7)
	var progress := TrackProgress.new(track.length())
	progress.update(track.offset_of(kart.position))
	var start := progress.distance()
	var worst := 0.0
	for i in 20 * 60:
		kart.input = bot.input_for(kart, track, 1.0 / 60.0)
		await get_tree().physics_frame
		var offset := track.offset_of(kart.position)
		progress.update(offset)
		worst = maxf(worst, kart.position.distance_to(track.point_at(offset, 0.0)))
	assert_lt(worst, 6.0, "furthest from the centre line")
	assert_gt(progress.distance() - start, 200.0, "distance gained")
	gut.p("bot: %.0f m in 20 s, worst lateral %.2f m" % [progress.distance() - start, worst])

func test_bot_completes_a_lap():
	var kart := _kart_on_the_grid()
	var bot := _bot(7)
	var progress := TrackProgress.new(track.length())
	progress.update(track.offset_of(kart.position))
	var frames := 0
	while progress.laps_done < 1 and frames < 120 * 60:
		kart.input = bot.input_for(kart, track, 1.0 / 60.0)
		await get_tree().physics_frame
		progress.update(track.offset_of(kart.position))
		frames += 1
	assert_eq(progress.laps_done, 1, "a lap within 120 s")
	gut.p("bot lap: %.1f s" % (frames / 60.0))

func test_bot_without_an_item_never_presses_item():
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	add_child_autofree(kart)
	var world := ItemWorld.new()
	world.track = track
	add_child_autofree(world)
	var bot := BotDriver.new(RandomNumberGenerator.new())
	for i in 30:
		assert_false(bot.input_for(kart, track, 1.0 / 60.0, world).item)
