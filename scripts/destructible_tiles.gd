extends TileMapLayer

enum DestroyMode { SINGLE, CONNECTED, RADIUS }

@export var tile_health: int = 3
@export var destroy_mode: DestroyMode = DestroyMode.CONNECTED

# RADIUS mode: how many cells around the broken tile also get destroyed
@export var blast_radius: int = 1
# CONNECTED mode: do tiles touching only at a corner count as part of the clump?
@export var diagonal_connections: bool = false
# Seconds between each tile vanishing (0 = all at once). Tiles go in order of
# distance from the one that was hit, so a small value gives a ripple effect.
@export var chain_delay: float = 0.0

var damaged_tiles: Dictionary = {}


func _ready() -> void:
	# tiles destroyed on an earlier visit stay destroyed
	for cell in Main.get_removed_cells(self):
		erase_cell(cell)


func damage_tile(tile_position: Vector2i, amount: int):
	# Check if a tile exists
	if get_cell_source_id(tile_position) == -1:
		return

	# Initialize tile health
	if not damaged_tiles.has(tile_position):
		damaged_tiles[tile_position] = tile_health

	# Reduce health
	damaged_tiles[tile_position] -= amount

	print("Tile Health: ", damaged_tiles[tile_position])

	# Destroy tile(s)
	if damaged_tiles[tile_position] <= 0:
		match destroy_mode:
			DestroyMode.SINGLE:
				destroy_tile(tile_position)
			DestroyMode.CONNECTED:
				destroy_tiles(get_connected_tiles(tile_position))
			DestroyMode.RADIUS:
				destroy_tiles(get_tiles_in_radius(tile_position, blast_radius))


func destroy_tiles(cells: Array[Vector2i]):
	for cell in cells:
		destroy_tile(cell)
		if chain_delay > 0.0:
			await get_tree().create_timer(chain_delay).timeout
			if not is_inside_tree():   # level was changed while the ripple was running
				return


func destroy_tile(tile_position: Vector2i):
	erase_cell(tile_position)
	Main.mark_cell_removed(self, tile_position)
	damaged_tiles.erase(tile_position)

	print("Tile destroyed!")


# Every tile that touches the start tile, directly or through other tiles.
# This is a flood fill: it spreads outward one step at a time, so the result
# is already ordered by distance from the hit (nice for the chain_delay ripple).
func get_connected_tiles(start: Vector2i) -> Array[Vector2i]:
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	if diagonal_connections:
		dirs.append(Vector2i(1, 1))
		dirs.append(Vector2i(1, -1))
		dirs.append(Vector2i(-1, 1))
		dirs.append(Vector2i(-1, -1))

	var found: Array[Vector2i] = [start]
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d in dirs:
			var next: Vector2i = current + d
			if not visited.has(next) and get_cell_source_id(next) != -1:
				visited[next] = true
				found.append(next)
				queue.append(next)

	return found


# Every tile inside a square of +/- radius cells around the center
func get_tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			if get_cell_source_id(cell) != -1:
				result.append(cell)
	return result
