extends AnimatableBody2D

enum Direction { RIGHT, LEFT, UP, DOWN }

## Which way the platform goes first. It travels move_distance that way, then comes back.
@export var direction : Direction = Direction.RIGHT
@export var move_distance: float = 200.0
@export var move_speed: float = 100.0

var start_position: Vector2
var target_position: Vector2
var moving_forward: bool = true

func _ready():
	start_position = global_position
	target_position = start_position + get_direction_vector() * move_distance

func get_direction_vector() -> Vector2:
	match direction:
		Direction.LEFT:
			return Vector2.LEFT
		Direction.UP:
			return Vector2.UP
		Direction.DOWN:
			return Vector2.DOWN
		_:
			return Vector2.RIGHT

func _physics_process(delta):
	var destination = target_position if moving_forward else start_position

	global_position = global_position.move_toward(destination, move_speed * delta)

	if global_position.distance_to(destination) < 1.0:
		moving_forward = !moving_forward
