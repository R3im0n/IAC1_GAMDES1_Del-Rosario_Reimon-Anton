extends CharacterBody2D
var enemy_death_effect = preload("res://scenes/enemy_death_effect.tscn")
const coin_pickup = preload("res://scenes/coin.tscn")

@export var health: int = 5
@export var drop_chance: float = 1.0

func _on_hitbox_area_entered(area: Area2D) -> void:
	var bullet = area.get_parent()
	if not bullet.has_method("get_damage"):
		return
	health -= bullet.get_damage()
	if health <= 0:
		die.call_deferred()

func die() -> void:
	var fx = enemy_death_effect.instantiate() as Node2D
	fx.global_position = global_position
	get_parent().add_child(fx)

	if randf() <= drop_chance:
		var pickup = coin_pickup.instantiate()
		get_parent().add_child(pickup)
		pickup.global_position = global_position

	queue_free()
