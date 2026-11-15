extends AnimatedSprite2D
## The splash the Queen Crab makes when its claw hits the ground.
## The boss spawns two of these (one for each side). Each one travels outward along the
## ground and hurts the player while its dense smoke frames are showing.
## The player can dodge by jumping over it or by staying out of its way.

@export var damage : int = 1
@export var travel_speed : float = 160.0        # px/second along the ground
@export var damage_frames : Vector2i = Vector2i(2, 9)   # first and last frame that can hurt

# 1 = travels to the right, -1 = to the left. The boss sets this BEFORE add_child().
var direction : int = 1
var has_hit := false     # a splash only hurts once

@onready var hitbox : Area2D = $Hitbox


func _ready() -> void:
	flip_h = direction > 0                        # the smoke art points to the left
	sprite_frames.set_animation_loop("default", false)
	animation_finished.connect(queue_free)
	play("default")


func _physics_process(delta: float) -> void:
	global_position.x += direction * travel_speed * delta

	if has_hit or frame < damage_frames.x or frame > damage_frames.y:
		return

	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			has_hit = true
			break
