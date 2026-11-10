class_name ItemRegistry extends RefCounted
## Every item, one line each, and the weighted roll.

const ITEMS := [
	preload("res://scripts/items/boost.gd"),
	preload("res://scripts/items/shield.gd"),
	preload("res://scripts/items/banana.gd"),
	preload("res://scripts/items/rocket.gd"),
]

static var _items: Array[ItemDef] = [] # one instance per ITEMS script, made on first use


static func all() -> Array[ItemDef]:
	if _items.is_empty():
		for script in ITEMS:
			_items.append(script.new())
	return _items


## An item drawn by weight(r); negative weights count as 0.
static func roll(r: float, rng: RandomNumberGenerator) -> ItemDef:
	var items := all()
	var weights: Array[float] = []
	for item in items:
		weights.append(item.weight(r))
	return items[pick(weights, rng)]


## An index drawn with probability proportional to its weight; negative weights count as 0.
static func pick(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	var last := 0
	for i in weights.size():
		if weights[i] > 0.0:
			total += weights[i]
			last = i
	var x := rng.randf() * total
	for i in weights.size():
		if weights[i] > 0.0:
			x -= weights[i]
			if x < 0.0:
				return i
	return last


static func by_id(id: String) -> ItemDef:
	for item in all():
		if item.id == id:
			return item
	return null
