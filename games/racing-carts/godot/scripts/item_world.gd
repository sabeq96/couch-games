class_name ItemWorld extends Node
## What items see of the race and do to it: the karts in race order, the track, spawning and hits.
## The race owns it and sets `order` and `distances` every tick.

var karts: Array[Kart] = [] ## a kart's id is its index
var track: Track
var order: Array[int] = [] ## kart ids, leader first (RaceRules.ranking)
var distances: Array[float] = [] ## race distance by kart id
var rng := RandomNumberGenerator.new()

signal kart_hit(kart: Kart) ## after an item hit a kart (shield or not); the race shakes that player's view


## A box touched by a kart: rolls an item for it, unless it already holds or rolls one.
func on_box(kart: Kart) -> void:
	if kart.held_item == "":
		kart.give_item(ItemRegistry.roll(rank_fraction(kart), rng).id)


## 0 for the leader, 1 for the last kart, 0 when alone.
func rank_fraction(kart: Kart) -> float:
	if order.size() <= 1:
		return 0.0
	return float(_rank(kart)) / (order.size() - 1)


## The next kart ahead in race order, or null for the leader.
func kart_ahead(kart: Kart) -> Kart:
	var rank := _rank(kart)
	return karts[order[rank - 1]] if rank > 0 else null


## The next kart behind in race order, or null for the last.
func kart_behind(kart: Kart) -> Kart:
	var rank := _rank(kart)
	return karts[order[rank + 1]] if rank >= 0 and rank < order.size() - 1 else null


## Race distance from a to b (positive when b is ahead).
func gap_to(a: Kart, b: Kart) -> float:
	return distances[karts.find(b)] - distances[karts.find(a)]


func spawn(node: Node3D) -> void:
	add_child(node)
	node.reset_physics_interpolation() # appears where it was placed, not moved there


func hit(kart: Kart) -> void:
	kart.hit()
	kart_hit.emit(kart)


## True while a live rocket is aimed at the kart.
func targeted_by_rocket(kart: Kart) -> bool:
	for child in get_children():
		if child is Rocket and child.target == kart and not child.is_queued_for_deletion():
			return true
	return false


func _rank(kart: Kart) -> int:
	return order.find(karts.find(kart))
