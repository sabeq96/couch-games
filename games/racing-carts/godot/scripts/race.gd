class_name Race extends Node3D
## The race: six karts on the grid (players by slot, bots after), a countdown, TOTAL_LAPS laps, catch-up, the finish
## rule and the results. Rules live in RaceRules; this script wires them to the scene.

const KART_SCENE := preload("res://scenes/kart.tscn")
## Soft colours for the bots, distinct from the shell's player colours.
const BOT_COLORS: Array[Color] = [
	Color("#F8A5C2"), Color("#8EE3EF"), Color("#D4E79E"), Color("#E7A8E0"), Color("#D9C4A3"), Color("#CFD8DC"),
]
const GO_SHOWN := 1.0 ## s the GO label stays up
const CAMERA_BEHIND := 8.0 ## m
const CAMERA_ABOVE := 4.0 ## m
const CAMERA_SMOOTHING := 5.0 ## 1/s

enum Phase { COUNTDOWN, RACING, DONE }

var _phase := Phase.COUNTDOWN
var _time := 0.0 ## s since the scene started; the race clock is _time - COUNTDOWN
var _karts: Array[Kart] = [] ## in grid order; a kart's id is its index
var _progress: Array[TrackProgress] = []
var _finished_at: Array[float] = [] ## race seconds, -1 while racing
var _bots := {} # kart id -> BotDriver
var _rng := RandomNumberGenerator.new()

@onready var _track: Track = $Track
@onready var _bridge: Bridge = $Bridge
@onready var _camera: Camera3D = $Camera3D
@onready var _countdown: Label = $HUD/Countdown


func _ready() -> void:
	_rng.randomize()
	var colors := {}
	var humans: Array[int] = []
	for player in _bridge.players:
		colors[player.slot] = player.color
		humans.append(player.slot)
	var grid := RaceRules.grid(humans)
	for i in grid.size():
		var at := _track.grid_transform(i)
		var d := -at.basis.z
		var kart: Kart = KART_SCENE.instantiate()
		kart.slot = grid[i]
		kart.color = colors[grid[i]] if grid[i] >= 0 else BOT_COLORS[_bots.size()]
		kart.heading = atan2(d.x, d.z)
		kart.position = at.origin
		if grid[i] < 0:
			_bots[i] = BotDriver.new(_rng)
		add_child(kart)
		_karts.append(kart)
		var progress := TrackProgress.new(_track.length())
		progress.update(_track.offset_of(kart.position))
		_progress.append(progress)
		_finished_at.append(-1.0)
	_camera.position = _camera_target()
	_camera.look_at(_karts[0].position + Vector3.UP)
	_countdown.text = str(ceili(RaceRules.COUNTDOWN))


func _physics_process(delta: float) -> void:
	_time += delta
	_follow(delta)
	match _phase:
		Phase.COUNTDOWN:
			if _time >= RaceRules.COUNTDOWN:
				_phase = Phase.RACING
				_countdown.text = "GO"
			else:
				_countdown.text = str(ceili(RaceRules.COUNTDOWN - _time))
		Phase.RACING:
			if _time >= RaceRules.COUNTDOWN + GO_SHOWN:
				_countdown.visible = false
			_race_tick(delta)
	_report()


func _race_tick(delta: float) -> void:
	var now := _time - RaceRules.COUNTDOWN
	var standings: Array[Dictionary] = []
	for i in _karts.size():
		var kart := _karts[i]
		kart.input = _bridge.input_for(kart.slot) if kart.slot >= 0 else _bots[i].input_for(kart, _track, delta)
		_progress[i].update(_track.offset_of(kart.position))
		if _finished_at[i] < 0.0 and _progress[i].laps_done >= RaceRules.TOTAL_LAPS:
			_finished_at[i] = now
		standings.append({ "id": i, "finished_at": _finished_at[i], "distance": _progress[i].distance() })
	var ranking := RaceRules.ranking(standings)
	for rank in ranking.size():
		var kart := _karts[ranking[rank]]
		kart.top_speed_scale = RaceRules.catchup_scale(rank, _karts.size(), kart.touched_wall_recently())

	if _is_over(now) or _bridge.finish_now():
		_phase = Phase.DONE
		for kart in _karts:
			kart.input = BridgeCodec.NEUTRAL.duplicate()
		var id_to_slot := {}
		for i in _karts.size():
			if _karts[i].slot >= 0:
				id_to_slot[i] = _karts[i].slot
		_bridge.send_finish(RaceRules.places(ranking, id_to_slot))


func _is_over(now: float) -> bool:
	var first_human := -1.0
	var humans_all_finished := true
	var has_human := false
	var last_bot := -1.0
	var bots_all_finished := not _bots.is_empty()
	for i in _karts.size():
		var at := _finished_at[i]
		if _karts[i].slot >= 0:
			has_human = true
			humans_all_finished = humans_all_finished and at >= 0.0
			if at >= 0.0 and (first_human < 0.0 or at < first_human):
				first_human = at
		else:
			bots_all_finished = bots_all_finished and at >= 0.0
			last_bot = maxf(last_bot, at)
	return RaceRules.is_over(now, first_human, has_human and humans_all_finished, last_bot if bots_all_finished else -1.0)


## Temporary camera (milestone 4 brings one per view): chases the lowest-slot player's kart, the first on the grid.
func _follow(delta: float) -> void:
	_camera.position = _camera.position.lerp(_camera_target(), 1.0 - exp(-CAMERA_SMOOTHING * delta))
	_camera.look_at(_karts[0].position + Vector3.UP)


func _camera_target() -> Vector3:
	var kart := _karts[0]
	return kart.position - KartPhysics.forward(kart.heading) * CAMERA_BEHIND + Vector3.UP * CAMERA_ABOVE


func _report() -> void:
	var karts: Array[Dictionary] = []
	for kart in _karts:
		if kart.slot >= 0:
			karts.append({ "slot": kart.slot, "x": kart.position.x, "z": kart.position.z })
	_bridge.report_karts(karts)
