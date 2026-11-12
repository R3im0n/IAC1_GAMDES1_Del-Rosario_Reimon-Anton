extends AnimatedSprite2D

var bullet_impact_effect = preload("res://scenes/bullet_impact.tscn")
var speed: int = 600
var direction : int
var damage : int = 1
var has_hit := false   # stops a bullet touching two things in one frame from hitting twice

func _physics_process(delta: float):
	move_local_x(direction * speed * delta)


func _on_timer_timeout():
	queue_free()


func _on_hitbox_area_entered(area):
	if has_hit:
		return
	has_hit = true
	print("Bullet  area entered")
	bullet_impact()


func _on_hitbox_body_entered(body):
	if has_hit:
		return
	has_hit = true
	print("Bullet  body entered")

	# Hit a destructible tile layer? Find which tile we hit and damage it.
	if body.has_method("damage_tile"):
		damage_tile_at(body)

	bullet_impact()


func damage_tile_at(layer) -> void:
	# The bullet moves ~10px per physics frame, so by the time the hit is detected
	# its centre can be just outside the tile or already inside it. Check the centre
	# first, then probe a little further along the direction of travel.
	var travel := Vector2.RIGHT.rotated(global_rotation) * signf(direction)
	for offset in [0.0, 4.0, 8.0]:
		var cell : Vector2i = layer.local_to_map(layer.to_local(global_position + travel * offset))
		if layer.get_cell_source_id(cell) != -1:
			layer.damage_tile(cell, damage)
			return


func get_damage() -> int:
	return damage

func bullet_impact():
	var bullet_impact_effect_instance = bullet_impact_effect.instantiate() as Node2D
	bullet_impact_effect_instance.global_position = global_position
	get_parent().add_child(bullet_impact_effect_instance)
	queue_free()
