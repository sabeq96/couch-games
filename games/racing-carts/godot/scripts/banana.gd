class_name Banana extends Area3D
## A dropped banana: the first kart to touch it is hit (its dropper only after OWNER_GRACE), and it is gone after LIFE.

const LIFE := 30.0 ## s
const OWNER_GRACE := 0.5 ## s the dropper is safe from it

var dropped_by: Kart
var world: ItemWorld

var _age := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for area in get_overlapping_areas():
		var kart := area.get_parent() as Kart
		if kart == null or (kart == dropped_by and _age < OWNER_GRACE):
			continue
		if not kart.has_shield():
			world.play_sound("banana_slip") # a shield absorbs the hit: no slip
		world.hit(kart)
		queue_free()
		return
