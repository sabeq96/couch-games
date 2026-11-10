extends ItemDef
## 🚀 Rocket: fired at the kart ahead in race order (straight ahead when there is none). Bots fire it when a kart is
## ahead within range, or after holding it HELD_LONG.

const AHEAD := 2.0 ## m ahead of the kart at launch
const RANGE := 60.0 ## m of race distance to the kart ahead for a bot to fire
const HELD_LONG := 10.0 ## s a bot holds it before firing it anyway (at whatever is ahead, or straight)


func _init() -> void:
	id = "rocket"
	hud_color = Color("#FFADAD")


func weight(r: float) -> float:
	return 0.5 + 3.0 * r


func use(kart: Kart, world: ItemWorld) -> void:
	var rocket: Rocket = load("res://scenes/rocket.tscn").instantiate()
	var forward := KartPhysics.forward(kart.heading)
	rocket.launch(kart, world.kart_ahead(kart), world, kart.position + forward * AHEAD, forward)
	world.spawn(rocket)
	world.play_sound("rocket_fire")


func bot_should_use(kart: Kart, world: ItemWorld, held_for: float) -> bool:
	var ahead := world.kart_ahead(kart)
	return held_for > HELD_LONG or (ahead != null and world.gap_to(kart, ahead) <= RANGE)
