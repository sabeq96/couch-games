extends ItemDef
## 🍌 Banana: dropped behind the kart; the first kart to touch it is hit. Bots drop it when followed closely.

const BEHIND := 2.5 ## m behind the kart
const FOLLOWED_WITHIN := 15.0 ## m, how close a kart behind makes a bot drop it


func _init() -> void:
	id = "banana"
	icon = "🍌"


func weight(r: float) -> float:
	return 3.0 - 2.0 * r


func use(kart: Kart, world: ItemWorld) -> void:
	var banana: Banana = load("res://scenes/banana.tscn").instantiate()
	banana.dropped_by = kart
	banana.world = world
	banana.position = kart.position - KartPhysics.forward(kart.heading) * BEHIND
	world.spawn(banana)


func bot_should_use(kart: Kart, world: ItemWorld, _held_for: float) -> bool:
	var behind := world.kart_behind(kart)
	return behind != null and world.gap_to(behind, kart) <= FOLLOWED_WITHIN
