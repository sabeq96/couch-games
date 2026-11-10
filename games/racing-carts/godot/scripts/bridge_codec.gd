class_name BridgeCodec
extends RefCounted
## Pure encode/decode of the JSON the shell exchanges with the game.

const NEUTRAL := { "steer": 0.0, "gas": false, "brake": false, "item": false }


## Players JSON `[{"slot":0,"name":"Alex","color":"#ff8fab"}]`; invalid entries are dropped.
static func parse_players(json: String) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	var data = _parse(json)
	if not data is Array:
		return players
	for entry in data:
		if not entry is Dictionary:
			continue
		if not (entry.get("slot") is float or entry.get("slot") is int):
			continue
		if not entry.get("name") is String or not entry.get("color") is String:
			continue
		if not (entry.color as String).is_valid_html_color():
			continue
		players.append({ "slot": int(entry.slot), "name": entry.name, "color": Color(entry.color) })
	return players


## Inputs JSON `{"0":{"steer":0.5,"gas":true,"brake":false,"item":false}}`, keyed by slot as a string.
## Returns an entry for every slot in `slots`; missing or malformed ones are NEUTRAL.
static func parse_inputs(json: String, slots: Array[int]) -> Dictionary:
	var data = _parse(json)
	var inputs := {}
	for slot in slots:
		inputs[slot] = _parse_input(data.get(str(slot)) if data is Dictionary else null)
	return inputs


## places: `[{slot, place}]`, serialised as given.
static func results_json(places: Array[Dictionary]) -> String:
	return JSON.stringify(places, "", false)


static func _parse_input(entry) -> Dictionary:
	if not entry is Dictionary:
		return NEUTRAL.duplicate()
	var steer = entry.get("steer")
	return {
		"steer": clampf(float(steer), -1.0, 1.0) if steer is float or steer is int else 0.0,
		"gas": entry.get("gas") == true,
		"brake": entry.get("brake") == true,
		"item": entry.get("item") == true,
	}


## Like JSON.parse_string, but returns null on invalid JSON without logging an engine error.
static func _parse(json: String):
	var parser := JSON.new()
	if parser.parse(json) != OK:
		return null
	return parser.data
