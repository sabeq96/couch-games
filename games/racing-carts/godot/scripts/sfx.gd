class_name Sfx extends Node
## The sound: one-shots by name, the race music, and an engine loop per human kart. Sounds are files in
## assets/sounds/. Gameplay never calls this directly: the race wires kart signals here (watch_kart), and items reach
## it through ItemWorld.play_sound. Players are not positional: with split screen a position would mean nothing.
## A missing or broken file stays silent and logs one warning.

const DIR := "res://assets/sounds/"
const ONE_SHOTS: Array[String] = [
	"countdown_beep", "countdown_go", "lap_complete", "final_lap", "race_finish", "item_box_pickup", "item_roulette",
	"boost", "shield_up", "shield_break", "banana_drop", "banana_slip", "rocket_fire", "rocket_explode", "kart_bump",
	"wall_bump", "kart_spinout", "mud",
]
const ENGINE := "engine_loop"
const MUSIC := "music_race"
const LOOPS: Array[String] = [ENGINE, MUSIC]
const MUSIC_VOLUME := 0.5 ## linear
const ENGINE_VOLUME := 0.35 ## linear, shared by all engine loops
const ENGINE_PITCH_MIN := 0.8 ## standing still
const ENGINE_PITCH_MAX := 1.6 ## at the top speed of a boost
const EXIT_MIX_WAIT_MS := 50 ## off the web, on leaving the tree: time for the audio thread to release stopped playbacks

signal played(sound: String) ## every request, also for a file that is missing

var _streams := {} # name -> AudioStream, or null when the file is missing
var _engines := {} # kart -> AudioStreamPlayer


## The engine pitch for a speed in m/s, between ENGINE_PITCH_MIN and ENGINE_PITCH_MAX.
static func engine_pitch(speed: float) -> float:
	var top := KartTuning.MAX_SPEED * KartTuning.BOOST_FACTOR
	return lerpf(ENGINE_PITCH_MIN, ENGINE_PITCH_MAX, clampf(speed / top, 0.0, 1.0))


## Each loop's linear volume when `count` loops play: together they are never louder than ENGINE_VOLUME.
static func engine_volume(count: int) -> float:
	return ENGINE_VOLUME / maxi(count, 1)


## Plays a one-shot; overlapping plays are fine, each player frees itself when done.
func play(sound: String) -> void:
	played.emit(sound)
	var stream := _stream(sound)
	if stream == null:
		return
	var player := _player(stream, 1.0)
	player.finished.connect(player.queue_free)
	_start(player)


func start_music() -> void:
	var stream := _stream(MUSIC)
	if stream != null:
		_start(_player(stream, MUSIC_VOLUME))


## Wires a kart's signals to their sounds; a human kart also gets an engine loop.
## `kart` is typed CharacterBody3D, not Kart: Kart reaches ItemWorld, which holds a Sfx, and a type cycle won't compile.
func watch_kart(kart: CharacterBody3D, human: bool) -> void:
	kart.bumped.connect(func(with_kart: bool): play("kart_bump" if with_kart else "wall_bump"))
	kart.spun_out.connect(play.bind("kart_spinout"))
	kart.boost_started.connect(play.bind("boost"))
	kart.shield_raised.connect(play.bind("shield_up"))
	kart.shield_broken.connect(play.bind("shield_break"))
	kart.entered_mud.connect(play.bind("mud"))
	if human:
		_add_engine(kart)


func _process(_delta: float) -> void:
	for kart: CharacterBody3D in _engines:
		_engines[kart].pitch_scale = engine_pitch(kart.velocity.length())


func _add_engine(kart: CharacterBody3D) -> void:
	var stream := _stream(ENGINE)
	if stream == null:
		return
	_engines[kart] = _player(stream, 1.0)
	_start(_engines[kart])
	for player in _engines.values():
		player.volume_db = linear_to_db(engine_volume(_engines.size()))
	kart.tree_exiting.connect(_remove_engine.bind(kart))


func _remove_engine(kart: CharacterBody3D) -> void:
	_engines[kart].queue_free()
	_engines.erase(kart)
	for player in _engines.values():
		player.volume_db = linear_to_db(engine_volume(_engines.size()))


## Starts a player, except with no audio device (headless runs, tests): there its playbacks outlive the quit and leak.
func _start(player: AudioStreamPlayer) -> void:
	if AudioServer.get_driver_name() != "Dummy":
		player.play()


func _player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	add_child(player)
	return player


## The stream for a sound, loaded once; null (and one warning) when its file is missing.
func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + ".mp3"
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream == null:
			push_warning("Sound %s is missing (%s)" % [sound, path])
		elif sound in LOOPS and stream is AudioStreamMP3:
			stream = stream.duplicate()
			stream.loop = true
		_streams[sound] = stream
	return _streams[sound]


## On the web, a player still playing when the engine quits pauses its sample after the audio context is gone, which
## throws in the page. Stopping everything first on the quit request avoids that.
## Off the web, a stopped playback is only released after the audio thread mixes once more; on a quit (EXIT_TREE comes
## after the last frame) that never happens and the playbacks leak at exit. A short wait lets that mix run.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		for child in get_children():
			child.stop()
		if what == NOTIFICATION_EXIT_TREE and AudioServer.get_driver_name() != "Dummy" and not OS.has_feature("web"):
			OS.delay_msec(EXIT_MIX_WAIT_MS)
