@tool
class_name LudoBoard
extends Node2D

## Ludo board assembled from CHIP tile images in 15x15 isometric grid.
## Assets from rss/CHIP/ are used for tiles.

# CHIP assignments
const CHIP_RED := "res://rss/CHIP/07.png"     # Center Goal (Red)
const CHIP_GREEN := "res://rss/CHIP/03.png"   # Player Green
const CHIP_YELLOW := "res://rss/CHIP/02.png"  # Player Yellow
const CHIP_CYAN := "res://rss/CHIP/04.png"    # Player Cyan (Blue/Teal)
const CHIP_ORANGE := "res://rss/CHIP/01.png"  # Player Orange
const CHIP_PURPLE := "res://rss/CHIP/05.png"  # Path

# ... (rest of the constants)

# Tile dimensions
const TILE_W: float = 136.0
const TILE_H: float = 97.0
const HALF_W: float = TILE_W / 2.0
const HALF_H: float = TILE_H / 2.0

@export var board_scale: float = 0.5:
	set(value):
		board_scale = value
		_build_board()

@export var rebuild_board: bool = false:
	set(value):
		_build_board()

var path_positions: Array[Vector2] = []
var home_stretch_positions: Dictionary = {}
var base_positions: Dictionary = {}
var spawn_cells: Dictionary = {}
## Full route per player: main loop + home stretch (safe zone).
var player_paths: Dictionary = {}
var center_position: Vector2

func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_board()
	
	# Center the board node on screen
	var viewport_size = get_viewport_rect().size
	position = viewport_size / 2.0

func _iso_to_screen(grid_pos: Vector2i) -> Vector2:
	var center_offset := Vector2i(7, 7)
	var rel_x: int = grid_pos.x - center_offset.x
	var rel_y: int = grid_pos.y - center_offset.y
	
	var sx: float = (rel_x - rel_y) * HALF_W * board_scale
	var sy: float = (rel_x + rel_y) * HALF_H * board_scale
	return Vector2(sx, sy)


func get_cell_local_position(grid_pos: Vector2i) -> Vector2:
	return _iso_to_screen(grid_pos)


func get_tile_display_width() -> float:
	return TILE_W * board_scale


func get_base_cells(player: StringName) -> Array[Vector2i]:
	var cells: Array = base_positions.get(player, [])
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell as Vector2i)
	return result


func _add_tile(texture_path: String, grid_pos: Vector2i, parent_node: Node) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.position = _iso_to_screen(grid_pos)
	sprite.scale = Vector2(board_scale, board_scale)
	sprite.centered = true
	sprite.z_index = grid_pos.x + grid_pos.y
	parent_node.add_child(sprite)
	
	if Engine.is_editor_hint():
		sprite.owner = get_tree().edited_scene_root
	return sprite

func _build_board() -> void:
	var tiles_node = get_node_or_null("Tiles")
	if not tiles_node:
		tiles_node = Node2D.new()
		tiles_node.name = "Tiles"
		add_child(tiles_node)
		if Engine.is_editor_hint():
			tiles_node.owner = get_tree().edited_scene_root
	
	for child in tiles_node.get_children():
		child.queue_free()
	
	path_positions.clear()
	home_stretch_positions.clear()
	base_positions.clear()
	
	# Layout: 11x11 area within 15x15 grid. Center is (7,7).
	# NW: Green, NE: Orange, SE: Yellow, SW: Cyan
	
	for y in range(15):
		for x in range(15):
			var tex: String = ""
			
			# 1. Bases (2x2)
			if x >= 2 and x <= 3 and y >= 2 and y <= 3:
				tex = CHIP_GREEN
			elif x >= 11 and x <= 12 and y >= 2 and y <= 3:
				tex = CHIP_ORANGE
			elif x >= 11 and x <= 12 and y >= 11 and y <= 12:
				tex = CHIP_YELLOW
			elif x >= 2 and x <= 3 and y >= 11 and y <= 12:
				tex = CHIP_CYAN
				
			# 2. Center Goal (1x1 Red)
			elif x == 7 and y == 7:
				tex = CHIP_RED
				center_position = _iso_to_screen(Vector2i(7, 7))
			
			# 3. Arms (5 tiles long, 3 tiles wide)
			var is_north := y >= 2 and y <= 6 and x >= 6 and x <= 8
			var is_east := x >= 8 and x <= 12 and y >= 6 and y <= 8
			var is_south := y >= 8 and y <= 12 and x >= 6 and x <= 8
			var is_west := x >= 2 and x <= 6 and y >= 6 and y <= 8
			
			if is_north:
				if x == 7 and y >= 3 and y <= 6: tex = CHIP_GREEN # Home Stretch (4 tiles)
				elif x == 8 and y == 2: tex = CHIP_GREEN          # Spawn
				else: tex = CHIP_PURPLE
			elif is_east:
				if y == 7 and x >= 8 and x <= 11: tex = CHIP_ORANGE # Home Stretch (4 tiles)
				elif x == 12 and y == 8: tex = CHIP_ORANGE           # Spawn
				else: tex = CHIP_PURPLE
			elif is_south:
				if x == 7 and y >= 8 and y <= 11: tex = CHIP_YELLOW # Home Stretch (4 tiles)
				elif x == 6 and y == 12: tex = CHIP_YELLOW           # Spawn
				else: tex = CHIP_PURPLE
			elif is_west:
				if y == 7 and x >= 3 and x <= 6: tex = CHIP_CYAN    # Home Stretch (4 tiles)
				elif x == 2 and y == 6: tex = CHIP_CYAN              # Spawn
				else: tex = CHIP_PURPLE
			
			if tex != "":
				_add_tile(tex, Vector2i(x, y), tiles_node)

	_calculate_positions()

func get_spawn_cell(player: StringName) -> Vector2i:
	return spawn_cells.get(player, Vector2i(-1, -1)) as Vector2i


func get_player_path(player: StringName) -> Array[Vector2i]:
	var raw: Array = player_paths.get(player, [])
	var result: Array[Vector2i] = []
	for cell in raw:
		result.append(cell as Vector2i)
	return result


func is_home_stretch_cell(player: StringName, cell: Vector2i) -> bool:
	var home: Array = home_stretch_positions.get(player, [])
	return home.has(cell)


func _calculate_positions() -> void:
	base_positions = {
		&"green": [
			Vector2i(2, 2), Vector2i(3, 2),
			Vector2i(2, 3), Vector2i(3, 3),
		],
		&"orange": [
			Vector2i(11, 2), Vector2i(12, 2),
			Vector2i(11, 3), Vector2i(12, 3),
		],
		&"yellow": [
			Vector2i(11, 11), Vector2i(12, 11),
			Vector2i(11, 12), Vector2i(12, 12),
		],
		&"cyan": [
			Vector2i(2, 11), Vector2i(3, 11),
			Vector2i(2, 12), Vector2i(3, 12),
		],
	}
	spawn_cells = {
		&"green": Vector2i(8, 2),
		&"orange": Vector2i(12, 8),
		&"yellow": Vector2i(6, 12),
		&"cyan": Vector2i(2, 6),
	}
	# Yellow: start → cyan side → green → orange → yellow safe zone.
	player_paths[&"yellow"] = [
		# South arm, west column (north)
		Vector2i(6, 12), Vector2i(6, 11), Vector2i(6, 10), Vector2i(6, 9), Vector2i(6, 8),
		# West arm, south row (west)
		Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8),
		# West arm, west column (north)
		Vector2i(2, 7), Vector2i(2, 6),
		# West arm, north row (east)
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6),
		# North arm, west column (north)
		Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2),
		# North arm, north row (east)
		Vector2i(7, 2), Vector2i(8, 2),
		# North arm, east column (south)
		Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
		# East arm, north row (east)
		Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6),
		# East arm, east column (south)
		Vector2i(12, 7), Vector2i(12, 8),
		# East arm, south row (west)
		Vector2i(11, 8), Vector2i(10, 8), Vector2i(9, 8), Vector2i(8, 8),
		# South arm, east column (south)
		Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12),
		# Approach home
		Vector2i(7, 12),
		# Yellow safe zone (home stretch)
		Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
	]
	home_stretch_positions[&"yellow"] = [
		Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
	]
