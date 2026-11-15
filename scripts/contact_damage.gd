extends Area2D
## Hurts the player while they touch this area. Add it to any enemy as a child
## (Collision Layer: none, Collision Mask: PLAYER) with a shape the size of the enemy.
##
## The player only takes a hit when they are not invulnerable (see player.gd),
## so staying in contact hurts once every `invulnerable_time` seconds, not every frame.

@export var damage : int = 1


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)   # global_position = where the knockback pushes away from
