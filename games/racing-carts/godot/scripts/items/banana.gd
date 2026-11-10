extends ItemDef
## 🍌 Banana: dropped behind the kart; the first kart to touch it is hit. Bots drop it when followed closely, or after
## holding it HELD_LONG.

const BEHIND := 2.5 ## m behind the kart
const FOLLOWED_WITHIN := 15.0 ## m, how close a kart behind makes a bot drop it
const HELD_LONG := 10.0 ## s a bot holds it before dropping it anyway


func _init() -> void:
	id = "banana"
	hud_color = Color("#FFEE99")


func weight(r: float) -> float:
	return 3.0 - 2.0 * r


func use(kart: Kart, world: ItemWorld) -> void:
	var banana: Banana = load("res://scenes/banana.tscn").instantiate()
	banana.dropped_by = kart
	banana.world = world
	banana.position = kart.position - KartPhysics.forward(kart.heading) * BEHIND
	world.spawn(banana)


func bot_should_use(kart: Kart, world: ItemWorld, held_for: float) -> bool:
	var behind := world.kart_behind(kart)
	return held_for > HELD_LONG or (behind != null and world.gap_to(behind, kart) <= FOLLOWED_WITHIN)
