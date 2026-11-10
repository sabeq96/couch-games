extends ItemDef
## ⚡ Boost: a longer boost than a pad's. Bots use it on a straight.

const TIME := 1.5 ## s
const STRAIGHT := 0.3 ## rad, the most the track may turn over LOOKAHEAD for a bot to use it
const LOOKAHEAD := 40.0 ## m


func _init() -> void:
	id = "boost"
	hud_color = Color("#FFC48A")


func weight(r: float) -> float:
	return 1.0 + 3.0 * r


func use(kart: Kart, _world: ItemWorld) -> void:
	kart.boost(TIME)


func bot_should_use(kart: Kart, world: ItemWorld, _held_for: float) -> bool:
	return world.track.turn_ahead(world.track.offset_of(kart.position), LOOKAHEAD) < STRAIGHT
