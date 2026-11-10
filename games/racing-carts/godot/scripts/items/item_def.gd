class_name ItemDef extends RefCounted
## One item kind. Each item is a script extending this, listed once in ItemRegistry.ITEMS.

var id: String
var icon: String


## Roll odds at rank fraction r (0 = leader, 1 = last). Negative counts as 0.
func weight(_r: float) -> float:
	return 0.0


func use(_kart: Kart, _world: ItemWorld) -> void:
	pass


## held_for: s since the roll ended.
func bot_should_use(_kart: Kart, _world: ItemWorld, _held_for: float) -> bool:
	return false
