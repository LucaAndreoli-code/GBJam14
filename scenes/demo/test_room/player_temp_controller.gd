extends CharacterBody2D

const SPEED = 32.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("dpad_left", "dpad_right", "dpad_up", "dpad_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
