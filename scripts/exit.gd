extends Area2D

@export_file("*.tscn") var target_level: String
@export var target_spawn: String = "SpawnPoint"
var player_inside := false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not player_inside:
			player_inside = true
			Main.change_level(target_level,target_spawn)
			
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
