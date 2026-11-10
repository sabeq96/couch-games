class_name Race extends Node3D
## The race: six karts on the grid (players by slot, bots after), a countdown, TOTAL_LAPS laps, catch-up, the finish
## rule, the results, and the items: box pickups through ItemWorld, ITEM on a fresh press. Rules live in RaceRules;
## this script wires them to the scene.

const KART_SCENE := preload("res://scenes/kart.tscn")
## Soft colours for the bots, distinct from the shell's player colours.
const BOT_COLORS: Array[Color] = [
	Color("#F8A5C2"), Color("#8EE3EF"), Color("#D4E79E"), Color("#E7A8E0"), Color("#D9C4A3"), Color("#CFD8DC"),
]
const GO_SHOWN := 1.0 ## s the GO label stays up
const MAX_SHADOWED_VIEWS := 2 ## more views than this turn the sun's shadows off
const COUNTDOWN_SCREEN_SHARE := 0.2 ## countdown font size, as a share of the screen height

enum Phase { COUNTDOWN, RACING, DONE }

var _phase := Phase.COUNTDOWN
var _time := 0.0 ## s since the scene started; the race clock is _time - COUNTDOWN
var _karts: Array[Kart] = [] ## in grid order; a kart's id is its index
var _progress: Array[TrackProgress] = []
var _finished_at: Array[float] = [] ## race seconds, -1 while racing
var _is_human: Array[bool] = []
var _bots := {} # kart id -> BotDriver
var _item_down: Array[bool] = [] ## ITEM held on the previous tick, by kart id
var _ranking: Array[int] = [] ## kart ids, leader first; the grid order until GO
var _rng := RandomNumberGenerator.new()

@onready var _track: Track = $Track
@onready var _bridge: Bridge = $Bridge
@onready var _views: Views = $Views
@onready var _sun: DirectionalLight3D = $Sun
@onready var _countdown: Label = $HUD/Countdown
@onready var _world: ItemWorld = $ItemWorld


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
		kart.reset_physics_interpolation() # placed on the grid, not moved there
		_karts.append(kart)
		var progress := TrackProgress.new(_track.length())
		progress.update(_track.offset_of(kart.position))
		_progress.append(progress)
		_finished_at.append(-1.0)
		_is_human.append(grid[i] >= 0)
		_item_down.append(false)
		_ranking.append(i)
	_world.karts = _karts
	_world.track = _track
	_world.rng = _rng
	for box in get_tree().get_nodes_in_group("item_box"):
		box.world = _world
	_world.kart_hit.connect(_on_kart_hit)
	_setup_views()
	_countdown.text = str(ceili(RaceRules.COUNTDOWN))
	get_viewport().size_changed.connect(_size_countdown)
	_size_countdown()


func _physics_process(delta: float) -> void:
	_time += delta
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
	_show_huds()
	_report()


func _race_tick(delta: float) -> void:
	var now := _time - RaceRules.COUNTDOWN
	var standings: Array[Dictionary] = []
	var distances: Array[float] = []
	for i in _karts.size():
		var kart := _karts[i]
		kart.input = _bridge.input_for(kart.slot) if kart.slot >= 0 else _bots[i].input_for(kart, _track, delta, _world)
		_progress[i].update(_track.offset_of(kart.position))
		if _finished_at[i] < 0.0 and _progress[i].laps_done >= RaceRules.TOTAL_LAPS:
			_finished_at[i] = now
		standings.append({ "id": i, "finished_at": _finished_at[i], "distance": _progress[i].distance() })
		distances.append(_progress[i].distance())
	var ranking := RaceRules.ranking(standings)
	_ranking = ranking
	for rank in ranking.size():
		var kart := _karts[ranking[rank]]
		kart.top_speed_scale = RaceRules.catchup_scale(rank, _karts.size(), kart.touched_wall_recently())
	_world.order = ranking
	_world.distances = distances
	if _views.camera_for(-1) != null:
		_views.camera_for(-1).target = _karts[ranking[0]]
	_use_items()

	if RaceRules.is_over(now, _finished_at, _is_human) or _bridge.finish_now():
		_phase = Phase.DONE
		for kart in _karts:
			kart.input = BridgeCodec.NEUTRAL.duplicate()
		var id_to_slot := {}
		for i in _karts.size():
			if _karts[i].slot >= 0:
				id_to_slot[i] = _karts[i].slot
		_bridge.send_finish(RaceRules.places(ranking, id_to_slot))


## ITEM uses the held item on a press (a rising edge), for players and bots alike.
func _use_items() -> void:
	for i in _karts.size():
		var kart := _karts[i]
		var down: bool = kart.input.item
		if down and not _item_down[i]:
			kart.use_item_pressed(_world)
		_item_down[i] = down


## Feeds every view's HUD: place, lap, held item and, once done, the finishing place.
func _show_huds() -> void:
	for rank in _ranking.size():
		var id := _ranking[rank]
		var kart := _karts[id]
		var hud := _views.hud_for(kart.slot)
		if hud == null or (kart.slot < 0 and rank > 0):
			continue # no view, or a bot that is not the leader followed by the bots-only view
		var lap := mini(_progress[id].laps_done + 1, RaceRules.TOTAL_LAPS)
		var finished := rank + 1 if _finished_at[id] >= 0.0 else 0
		hud.show_state(rank + 1, lap, RaceRules.TOTAL_LAPS, kart.held_item, kart.roll_left > 0.0, finished)


func _size_countdown() -> void:
	var height := get_viewport().get_visible_rect().size.y
	_countdown.add_theme_font_size_override("font_size", roundi(height * COUNTDOWN_SCREEN_SHARE))


## One view per player, lowest slot first (the grid already is). With no players, one view follows the leader.
func _setup_views() -> void:
	var viewed: Array[Kart] = []
	for kart in _karts:
		if kart.slot >= 0:
			viewed.append(kart)
	if viewed.is_empty():
		viewed.append(_karts[0])
	_views.setup(viewed, get_viewport().find_world_3d())
	if _views.view_count() > MAX_SHADOWED_VIEWS:
		_sun.shadow_enabled = false
	_bridge.report_views(_views.view_count())


## A hit shakes only the view of the kart hit.
func _on_kart_hit(kart: Kart) -> void:
	if kart.slot >= 0 and _views.camera_for(kart.slot) != null:
		_views.camera_for(kart.slot).shake()


func _report() -> void:
	var karts: Array[Dictionary] = []
	for kart in _karts:
		if kart.slot >= 0:
			karts.append({ "slot": kart.slot, "x": kart.position.x, "z": kart.position.z })
	_bridge.report_karts(karts)
