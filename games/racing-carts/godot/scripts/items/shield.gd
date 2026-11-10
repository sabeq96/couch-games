extends ItemDef
## 🛡️ Shield: absorbs the next hit, or lasts SHIELD_TIME. Bots raise it when a rocket comes, or after holding it a while.

const HELD_LONG := 5.0 ## s a bot holds it before raising it anyway


func _init() -> void:
	id = "shield"
	icon = "🛡️"


func weight(r: float) -> float:
	return 3.0 - 2.0 * r


func use(kart: Kart, _world: ItemWorld) -> void:
	kart.shield(KartTuning.SHIELD_TIME)


func bot_should_use(kart: Kart, world: ItemWorld, held_for: float) -> bool:
	return held_for > HELD_LONG or world.targeted_by_rocket(kart)
