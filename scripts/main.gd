extends Node2D
#main node handles all logic

#var level: int = 1
var player: Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.44,0.12,0.53,1.00))
	#diable comment when player_died signal is created properly
	#_setup_level()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#diable comment when player_died signal is created properly
#func _setup_level() -> void:
	##connect exit
	#var exit = $LevelRoot.get_node_or_null("Exit")
	#if exit:
		#exit.body_entered.connect(_on_exit_body_entered)
	##connect enemies
	#var enemies = $LevelRoot.get_node_or_null("Enemies")
	#if enemies:
		#for enemy in enemies.get_children():
			#enemy.player_died.connect(_on_player_died)

#chaging levels
func change_level(target_level: String,target_spawn: String) -> void:
	var error = get_tree().change_scene_to_file(target_level)

	if error != OK:
		push_error("Failed to load level!")
		return

	await get_tree().scene_changed

	var spawn_point = get_tree().current_scene.find_child(target_spawn, true, false)

	if spawn_point:
		player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = spawn_point.global_position
	else:
		push_error("Spawn point not found: " + target_spawn)

#SIGNAL HANDLERS
func _on_exit_body_entered(body: Node2D) -> void:
	print(body)
	

func _on_player_died(body):
	body.die()
	print("Player killed")
