extends GutTest
# The sound: every event has a file, a missing file is silent, the engine loops share their volume and follow speed,
# and lap / finish sounds are for human karts only.

var sfx: Sfx

func before_each():
	sfx = Sfx.new()
	add_child_autofree(sfx)

func _kart() -> Kart:
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	add_child_autofree(kart)
	return kart

func _players() -> Array:
	return sfx.get_children().filter(func(c): return c is AudioStreamPlayer)

func test_every_event_maps_to_a_file():
	var names: Array[String] = Sfx.ONE_SHOTS.duplicate()
	names.append_array(Sfx.LOOPS)
	for sound in names:
		assert_true(ResourceLoader.exists(Sfx.DIR + sound + ".mp3"), sound)
	for sound in ["mine_drop", "mine_explode"]:
		assert_false(ResourceLoader.exists(Sfx.DIR + sound + ".mp3"), "%s was renamed" % sound)
	sfx.play("boost")
	assert_eq(_players().size(), 1, "a one-shot gets a player")
	assert_eq(_players()[0].stream, sfx._stream("boost"), "with its stream")

func test_a_played_one_shot_frees_itself():
	sfx.play("boost")
	var player: AudioStreamPlayer = _players()[0]
	assert_true(player.finished.is_connected(player.queue_free), "freed when done")
	player.finished.emit() # with no audio device (tests) nothing really plays, so finish it by hand
	await wait_process_frames(1)
	assert_false(is_instance_valid(player), "gone after finishing")

func test_loops_loop():
	for sound in Sfx.LOOPS:
		assert_true(sfx._stream(sound).loop, sound)

func test_missing_sound_is_silent():
	watch_signals(sfx)
	sfx.play("no_such_sound")
	sfx.play("no_such_sound")
	assert_eq(_players().size(), 0, "no player")
	assert_signal_emit_count(sfx, "played", 2, "still announced")
	assert_eq(sfx._streams.size(), 1, "looked up once, so warned once")
	assert_null(sfx._streams["no_such_sound"])

func test_engine_loops_share_volume():
	var karts: Array[Kart] = []
	for i in 6:
		karts.append(_kart())
		sfx.watch_kart(karts[i], true)
	assert_eq(sfx._engines.size(), 6, "one per human kart")
	var power := 0.0 # loops out of phase add up in power (amplitude squared)
	for player in sfx._engines.values():
		power += pow(db_to_linear(player.volume_db), 2.0)
	assert_almost_eq(sqrt(power), Sfx.ENGINE_VOLUME, 0.001, "six together sound as loud as one loop")
	assert_almost_eq(db_to_linear(sfx._engines.values()[0].volume_db), Sfx.ENGINE_VOLUME / sqrt(6.0), 0.001)
	karts[0].free()
	assert_eq(sfx._engines.size(), 5, "a freed kart drops its loop")
	assert_almost_eq(db_to_linear(sfx._engines.values()[0].volume_db), Sfx.ENGINE_VOLUME / sqrt(5.0), 0.001, "the rest get louder")
	assert_eq(Sfx.engine_volume(1), Sfx.ENGINE_VOLUME, "one loop alone at the engine volume")

func test_bots_have_no_engine():
	sfx.watch_kart(_kart(), false)
	assert_eq(sfx._engines.size(), 0)

func test_engine_pitch_follows_speed():
	assert_almost_eq(Sfx.engine_pitch(0.0), 0.8, 0.001, "standing")
	assert_almost_eq(Sfx.engine_pitch(1000.0), 1.6, 0.001, "capped")
	assert_gt(Sfx.engine_pitch(KartTuning.MAX_SPEED), Sfx.engine_pitch(KartTuning.MAX_SPEED / 2.0), "faster, higher")
	var kart := _kart()
	sfx.watch_kart(kart, true)
	kart.set_physics_process(false)
	kart.velocity = Vector3(0, 0, KartTuning.MAX_SPEED)
	await wait_physics_frames(2)
	assert_almost_eq(sfx._engines[kart].pitch_scale, Sfx.engine_pitch(KartTuning.MAX_SPEED), 0.001)

func test_kart_signals_play_their_sounds():
	var kart := _kart()
	sfx.watch_kart(kart, false)
	watch_signals(sfx)
	kart.bumped.emit(false)
	assert_signal_emitted_with_parameters(sfx, "played", ["wall_bump"])
	kart.bumped.emit(true)
	assert_signal_emitted_with_parameters(sfx, "played", ["kart_bump"])
	kart.shield(1.0)
	assert_signal_emitted_with_parameters(sfx, "played", ["shield_up"])
	kart.hit()
	assert_signal_emitted_with_parameters(sfx, "played", ["shield_break"])
	kart.hit()
	assert_signal_emitted_with_parameters(sfx, "played", ["kart_spinout"])
	kart.boost(1.0)
	assert_signal_emitted_with_parameters(sfx, "played", ["boost"])
	kart.entered_mud.emit()
	assert_signal_emitted_with_parameters(sfx, "played", ["mud"])

func test_a_running_boost_does_not_restart_its_sound():
	var kart := _kart()
	sfx.watch_kart(kart, false)
	watch_signals(sfx)
	kart.boost(1.0)
	kart.boost(1.0)
	assert_signal_emit_count(sfx, "played", 1)

func test_sounds_only_for_human_events():
	var race: Race = load("res://scenes/race.tscn").instantiate()
	add_child_autofree(race)
	var human := race._is_human.find(true)
	var bot := race._is_human.find(false)
	watch_signals(race._sfx)
	race._progress[bot].laps_done = 1
	race._announce_laps(bot)
	assert_signal_not_emitted(race._sfx, "played", "a bot's lap is silent")
	race._progress[human].laps_done = 1
	race._announce_laps(human)
	assert_signal_emitted_with_parameters(race._sfx, "played", ["lap_complete"])
	race._progress[human].laps_done = RaceRules.TOTAL_LAPS - 1
	race._announce_laps(human)
	assert_signal_emitted_with_parameters(race._sfx, "played", ["final_lap"])
	race._progress[human].laps_done = RaceRules.TOTAL_LAPS
	race._announce_laps(human)
	assert_signal_emitted_with_parameters(race._sfx, "played", ["race_finish"])
	race._announce_laps(human)
	assert_signal_emit_count(race._sfx, "played", 3, "each lap once")

func test_countdown_beeps_then_go_and_music_plays():
	var race: Race = load("res://scenes/race.tscn").instantiate()
	add_child_autofree(race)
	watch_signals(race._sfx)
	await wait_physics_frames(roundi(RaceRules.COUNTDOWN * 60) + 5)
	assert_signal_emit_count(race._sfx, "played", 4, "3 beeps and GO")
	assert_signal_emitted_with_parameters(race._sfx, "played", ["countdown_go"])
	assert_eq(race._sfx._streams[Sfx.MUSIC] != null, true, "music loaded")
