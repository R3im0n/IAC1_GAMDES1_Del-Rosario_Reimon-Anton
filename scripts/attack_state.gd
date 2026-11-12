extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var chase_speed : float = 60.0

var target : Node2D = null

func on_physics_process(delta: float):
	if target == null or !is_instance_valid(target):
		return
	var dir := signf(target.global_position.x - character_body_2d.global_position.x)
	character_body_2d.velocity.x = dir * chase_speed
	if dir != 0:
		animated_sprite_2d.flip_h = dir > 0   # invert this if the dino faces the wrong way
	animated_sprite_2d.play("attack")         # or "idle", whichever animation fits
