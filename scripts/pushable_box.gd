extends CharacterBody2D

@export var push_speed: float = 100.0
@export var gravity: float = 980.0

var push_direction: float = 0.

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	# Move the box horizontally
	velocity.x = push_direction * push_speed
	move_and_slide()
	
func push(direction: float, speed: float) -> void:
	push_direction = direction
	push_speed = speed

func stop_pushing():
	push_direction = 0.0
