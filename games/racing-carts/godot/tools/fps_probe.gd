extends SceneTree
## Measures the race's native fps with 6 human views, effects firing. Not exported (tools/*), not part of the race.
## Run windowed, without --fixed-fps:
##   scripts/godot.sh --path games/racing-carts/godot --resolution 1920x1080 -s tools/fps_probe.gd
## Six players are forced in through the Bridge; BotDrivers steer them all, so pads, slides, bumps and items happen.
## Every second two karts are boosted and a spark burst and confetti are spawned in front of each view. After GO it
## measures for MEASURE seconds, prints fps, the largest draw-call count and primitives, and the emitters emitting, then quits.
## Flags after `--`, to find what costs: nospawn (no probe bursts or boosts: only what the race does itself),
## nopetals (frees the ambient petals), nokartfx (frees the karts' continuous effects).

const WARMUP := 4.0 ## s: the 3 s countdown and a second of racing
const MEASURE := 6.0 ## s
const PLAYER_COLORS: Array[Color] = [
	Color("#ff8fab"), Color("#8fd3ff"), Color("#b8e986"), Color("#ffd166"), Color("#c3a6ff"), Color("#7ee0c3"),
]

var _race: Node
var _bridge: Node
var _bots := []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _frames := 0
var _measured := 0.0
var _max_draw_calls := 0
var _max_primitives := 0
var _max_emitting := 0
var _next_fire := WARMUP
var _pruned := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_race = load("res://scenes/race.tscn").instantiate()
	_bridge = _race.get_node("Bridge")
	_bridge.ready.connect(_six_players) # after Bridge._ready, before Race._ready reads the players
	var driver := Node.new()
	driver.process_physics_priority = -1
	driver.set_script(_driver_script())
	driver.set_meta("probe", self)
	root.add_child(driver)
	root.add_child(_race)


func _six_players() -> void:
	var players: Array[Dictionary] = []
	for slot in 6:
		players.append({ "slot": slot, "name": "Player %d" % (slot + 1), "color": PLAYER_COLORS[slot] })
	_bridge.players = players
	_bridge.set_physics_process(false) # the probe feeds the inputs
	for slot in 6:
		_bots.append(BotDriver.new(_rng))


## Called by the driver node every physics tick, before the race reads the inputs.
func drive(delta: float) -> void:
	var karts: Array = _race._karts
	for i in karts.size():
		_bridge._inputs[karts[i].slot] = _bots[i].input_for(karts[i], _race._track, delta, _race._world)


func _process(delta: float) -> bool:
	_time += delta
	var flags := OS.get_cmdline_user_args()
	if not _pruned and _time > 0.5:
		_pruned = true
		for node in _race.find_children("*", "CPUParticles3D", true, false):
			if ("nopetals" in flags and node.name.begins_with("Petals")) \
					or ("nokartfx" in flags and node.get_parent() is Kart):
				node.queue_free()
	if _time >= _next_fire and "_fx" in _race and not "nospawn" in flags:
		_next_fire += 1.0
		_fire_effects()
	if _time >= WARMUP:
		_frames += 1
		_measured += delta
		_max_draw_calls = maxi(_max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_max_primitives = maxi(_max_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		if _frames % 30 == 0: # the node walk is not free; sample it
			_max_emitting = maxi(_max_emitting, _emitting())
	if _measured >= MEASURE:
		print("fps_probe: %d views, %s, %.0f fps, max draw calls %d, max primitives %d, max emitters emitting %d" % [
			_race._views.view_count(), str(root.size), _frames / _measured, _max_draw_calls, _max_primitives,
			_max_emitting])
		quit()
	return false


func _fire_effects() -> void:
	var karts: Array = _race._karts
	for i in 2:
		karts[_rng.randi() % karts.size()].boost(1.0)
	for kart in karts:
		var ahead: Vector3 = kart.position + KartPhysics.forward(kart.heading) * 4.0 + Vector3.UP
		_race._fx.spawn("sparks_big", ahead)
		_race._fx.spawn("confetti", ahead)


func _emitting() -> int:
	var count := 0
	for node in _race.find_children("*", "CPUParticles3D", true, false):
		if node.emitting:
			count += 1
	return count


func _driver_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _physics_process(delta):\n\tget_meta(\"probe\").drive(delta)\n"
	script.reload()
	return script
