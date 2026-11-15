extends Node2D
#main node handles all logic

#var level: int = 1
var player: Node2D

# ---------------------------------------------------------------------------
# WORLD STATE THAT SURVIVES CHANGING LEVELS
# ---------------------------------------------------------------------------
# Every level is its own scene that is thrown away when you leave it, so anything that has to
# stay changed (killed enemies, collected keys, opened doors, destroyed tiles) and the keys the
# player carries are remembered here, in the Main autoload.
#
# Changes made inside a level are "pending" until the player LEAVES through an exit:
#   - leaving through an exit -> they are saved for good (commit_progress)
#   - dying (the level restarts) -> they are thrown away, so the level starts over from its start
# Set this to true if dying should NOT undo what you did in the level.
const KEEP_PROGRESS_ON_DEATH := false

var removed : Dictionary = {}           # object id -> true   (saved)
var pending_removed : Dictionary = {}   # object id -> true   (this visit only, not saved yet)
var removed_cells : Dictionary = {}     # tile layer id -> { cell: true }
var pending_cells : Dictionary = {}
var key_counts : Dictionary = {}        # key id -> how many the player has
var pending_key_delta : Dictionary = {} # changes to key_counts made during this visit

# The spawn point the player entered the current level at ("" = the player's starting spot in the scene).
# Dying sends the player back here, i.e. the start of the level.
var current_entry_spawn: String = ""

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
	commit_progress()   # leaving the level: what happened in it is now permanent
	var error = get_tree().change_scene_to_file(target_level)

	if error != OK:
		push_error("Failed to load level!")
		return

	current_entry_spawn = target_spawn   # remembered so dying can send the player back here

	await get_tree().scene_changed

	if target_spawn == "":
		return   # no spawn point given: the player stays where the scene placed them

	var spawn_point = get_tree().current_scene.find_child(target_spawn, true, false)

	if spawn_point:
		player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = spawn_point.global_position
	else:
		push_error("Spawn point not found: " + target_spawn)


# Reloads the current level and puts the player back at its start
func restart_level() -> void:
	if not KEEP_PROGRESS_ON_DEATH:
		discard_progress()   # dying undoes what was done since entering this level
	var scene = get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		return
	change_level(scene.scene_file_path, current_entry_spawn)

#SIGNAL HANDLERS
func _on_exit_body_entered(body: Node2D) -> void:
	print(body)
	

func _on_player_died(body):
	body.die()
	print("Player killed")


# ---------------------------------------------------------------------------
# Remembering things between levels
# ---------------------------------------------------------------------------

# A unique name for something placed in a level: "<level file>:<path inside the level>".
# Things created while playing (like a coin dropped by an enemy) have no owner and are not remembered.
func object_id(node: Node) -> String:
	var level := node.owner
	if level == null or level.scene_file_path == "":
		return ""
	return level.scene_file_path + ":" + str(level.get_path_to(node))


# Has this object been killed / collected / opened / destroyed earlier? (call from _ready)
func is_removed(node: Node) -> bool:
	var id := object_id(node)
	return id != "" and (removed.has(id) or pending_removed.has(id))


# Remember that this object is gone for good (call when it is killed / collected / opened)
func mark_removed(node: Node) -> void:
	var id := object_id(node)
	if id != "":
		pending_removed[id] = true


# Tiles of a TileMapLayer that were destroyed earlier
func get_removed_cells(layer: Node) -> Array[Vector2i]:
	var id := object_id(layer)
	var result : Array[Vector2i] = []
	for source in [removed_cells, pending_cells]:
		if source.has(id):
			for cell in source[id]:
				result.append(cell)
	return result


func mark_cell_removed(layer: Node, cell: Vector2i) -> void:
	var id := object_id(layer)
	if id == "":
		return
	if not pending_cells.has(id):
		pending_cells[id] = {}
	pending_cells[id][cell] = true


# ----- keys the player carries (they stay with the player when changing levels) -----

func add_key(id: String) -> void:
	pending_key_delta[id] = pending_key_delta.get(id, 0) + 1


func has_key(id: String) -> bool:
	return key_counts.get(id, 0) + pending_key_delta.get(id, 0) > 0


func use_key(id: String) -> void:
	pending_key_delta[id] = pending_key_delta.get(id, 0) - 1


# ----- saving / discarding what happened in the current level -----

func commit_progress() -> void:
	removed.merge(pending_removed)
	for id in pending_cells:
		if not removed_cells.has(id):
			removed_cells[id] = {}
		removed_cells[id].merge(pending_cells[id])
	for id in pending_key_delta:
		key_counts[id] = key_counts.get(id, 0) + pending_key_delta[id]
	discard_progress()


func discard_progress() -> void:
	pending_removed.clear()
	pending_cells.clear()
	pending_key_delta.clear()
