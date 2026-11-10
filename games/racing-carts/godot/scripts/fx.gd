class_name Fx extends Node3D
## The particle effects, each a scene under scenes/fx/. One-shots are spawned at a point under this node and free
## themselves after their lifetime; continuous ones are attached to their owner and toggle `emitting` themselves
## (FxToggle). Gameplay rules emit signals or call ItemWorld's play_sound/spawn_fx/attach_fx; the race wires karts.
## They are CPUParticles3D: in the Compatibility renderer each active GPUParticles3D cost a fixed ~0.35 ms a frame,
## and two different ParticleProcessMaterials leaked a shader at exit (Godot 4.7.1).

const SCENES := {
	# continuous
	"boost_flame": preload("res://scenes/fx/boost_flame.tscn"),
	"slide_dust": preload("res://scenes/fx/slide_dust.tscn"),
	"mud_splash": preload("res://scenes/fx/mud_splash.tscn"),
	"rocket_trail": preload("res://scenes/fx/rocket_trail.tscn"),
	# one-shots
	"sparks": preload("res://scenes/fx/sparks.tscn"),
	"sparks_big": preload("res://scenes/fx/sparks_big.tscn"),
	"slip_stars": preload("res://scenes/fx/slip_stars.tscn"),
	"rocket_burst": preload("res://scenes/fx/rocket_burst.tscn"),
	"box_burst": preload("res://scenes/fx/box_burst.tscn"),
	"pad_flash": preload("res://scenes/fx/pad_flash.tscn"),
	"confetti": preload("res://scenes/fx/confetti.tscn"),
}
const FREE_MARGIN := 0.5 ## s a one-shot lives past its lifetime


## Plays a one-shot effect at a world position; it frees itself after its lifetime (+ FREE_MARGIN).
## With `on`, it rides on that node instead, `at` being in that node's frame.
func spawn(effect: String, at: Vector3, on: Node3D = null) -> CPUParticles3D:
	var node: CPUParticles3D = SCENES[effect].instantiate()
	node.position = at if on != null else to_local(at)
	(on if on != null else self).add_child(node)
	node.reset_physics_interpolation() # appears where it was placed, not moved there
	# Physics time, so a one-shot is gone after a fixed number of ticks, also in headless tests.
	get_tree().create_timer(node.lifetime + FREE_MARGIN, true, true).timeout.connect(node.queue_free)
	return node


## Adds a continuous effect to its owner; it moves with it and is freed with it.
func attach(effect: String, owner_node: Node3D) -> CPUParticles3D:
	var node: CPUParticles3D = SCENES[effect].instantiate()
	owner_node.add_child(node)
	return node
