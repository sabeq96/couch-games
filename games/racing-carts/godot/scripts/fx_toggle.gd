class_name FxToggle extends CPUParticles3D
## A continuous effect on its owner (the parent): emits while the parent's `when` method returns true and, when
## min_speed is set, the parent moves faster than that.

@export var when: StringName
@export var min_speed := 0.0 ## m/s, 0 for no speed condition


func _physics_process(_delta: float) -> void:
	var parent := get_parent()
	var on: bool = parent.call(when) and (min_speed <= 0.0 or parent.velocity.length() > min_speed)
	if on != emitting:
		emitting = on
