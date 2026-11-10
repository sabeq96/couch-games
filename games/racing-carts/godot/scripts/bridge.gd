class_name Bridge
extends Node
## Talks to the shell page through `window.racingCarts`: players and inputs in, results and kart positions out.
## Away from the web it plays two players itself: slot 0 on the keyboard (arrows, Space for ITEM), slot 1 idle.

var players: Array[Dictionary] = []

var _web := OS.has_feature("web")
var _page  # JavaScriptObject for window.racingCarts, or null when the page has none.
var _e2e := false
var _inputs := {}
var _finished := false


func _ready() -> void:
	# Read inputs before the race reads them in the same physics tick.
	process_physics_priority = -1
	if _web:
		_page = JavaScriptBridge.get_interface("racingCarts")
		if _page == null:
			return
		players = BridgeCodec.parse_players(str(_page.players))
		_e2e = _page.e2e == true
		_page.ready()
	else:
		players = [
			{ "slot": 0, "name": "Player 1", "color": Color("#ff8fab") },
			{ "slot": 1, "name": "Player 2", "color": Color("#8fd3ff") },
		]


func _physics_process(_delta: float) -> void:
	if _web:
		if _page != null:
			_inputs = BridgeCodec.parse_inputs(str(_page.inputs), _slots())
	else:
		_inputs = { 0: _keyboard(), 1: BridgeCodec.NEUTRAL.duplicate() }


func input_for(slot: int) -> Dictionary:
	return _inputs.get(slot, BridgeCodec.NEUTRAL)


## places: `[{slot, place}]`, each player's place among all karts. Only the first call counts.
func send_finish(places: Array[Dictionary]) -> void:
	if _finished:
		return
	_finished = true
	var json := BridgeCodec.results_json(places)
	if _web:
		if _page != null:
			_page.finish(json)
	else:
		print(json)
		get_tree().quit()


## True when the page asks the race to end now (`window.racingCarts.finishNow === true`); e2e tests set it.
func finish_now() -> bool:
	if not _web or _page == null:
		return false
	var flag = _page.finishNow
	return flag is bool and flag


## Kart positions `[{"slot":0,"x":0,"z":0}]` for the e2e tests; does nothing outside them.
func report_karts(karts: Array[Dictionary]) -> void:
	if _e2e and _page != null:
		_page.karts = JSON.stringify(karts)


func _slots() -> Array[int]:
	var slots: Array[int] = []
	for p in players:
		slots.append(p.slot)
	return slots


func _keyboard() -> Dictionary:
	return {
		"steer": float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		"gas": Input.is_physical_key_pressed(KEY_UP),
		"brake": Input.is_physical_key_pressed(KEY_DOWN),
		"item": Input.is_physical_key_pressed(KEY_SPACE),
	}
