@tool
class_name BoardView
extends Node2D
## Временен BoardView — пренесен от scripts/ludo_board.gd
## (docs/V1_ARCHITECTURE.md §6.2, Етап C).
##
## Отговорности:
##   - строи 15×15 геометрията (изометрични CHIP тайлове);
##   - пази cell_id → Node2D / локална позиция;
##   - НЕ пази текущ играч, зар, маршрути или правила.
##
## Изометричната математика е в IsometricMath (#147).
## Gameplay topology (бази/spawn/маршрути/home stretch) е само в Domain
## (Classic15x15Board) — премахната оттук (#148).
## Хардкоднатият visual layout остава до #152 (BoardDefinition).

const CHIP_RED := "res://rss/CHIP/07.png"
const CHIP_GREEN := "res://rss/CHIP/03.png"
const CHIP_YELLOW := "res://rss/CHIP/02.png"
const CHIP_CYAN := "res://rss/CHIP/04.png"
const CHIP_ORANGE := "res://rss/CHIP/01.png"
const CHIP_PURPLE := "res://rss/CHIP/05.png"

@export var board_scale: float = 0.5:
	set(value):
		board_scale = value
		_build_board()

@export var rebuild_board: bool = false:
	set(_value):
		_build_board()

## cell_id (CellId) → Sprite2D на тайла. Празен до първо _build_board().
var _cell_nodes: Dictionary = {}
## cell_id → локална изометрична позиция спрямо BoardView.
var _cell_positions: Dictionary = {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_board()
	var viewport_size: Vector2 = get_viewport_rect().size
	position = viewport_size / 2.0


func get_cell_local_position(grid_pos: Vector2i) -> Vector2:
	return IsometricMath.grid_to_local(grid_pos, board_scale)


func get_tile_display_width() -> float:
	return IsometricMath.tile_display_width(board_scale)


## Локална позиция по стабилен cell_id, или Vector2.ZERO ако липсва.
func get_cell_position_by_id(cell_id: StringName) -> Vector2:
	return _cell_positions.get(cell_id, Vector2.ZERO) as Vector2


## Sprite2D на клетката, или null ако липсва.
func get_cell_node(cell_id: StringName) -> Node2D:
	return _cell_nodes.get(cell_id) as Node2D


func _add_tile(texture_path: String, grid_pos: Vector2i, parent_node: Node) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.position = IsometricMath.grid_to_local(grid_pos, board_scale)
	sprite.scale = Vector2(board_scale, board_scale)
	sprite.centered = true
	sprite.z_index = IsometricMath.z_index_for(grid_pos)
	parent_node.add_child(sprite)
	if Engine.is_editor_hint():
		sprite.owner = get_tree().edited_scene_root

	var cell_id: StringName = CellId.from_vec(grid_pos)
	_cell_nodes[cell_id] = sprite
	_cell_positions[cell_id] = sprite.position
	return sprite


func _build_board() -> void:
	var tiles_node: Node = get_node_or_null("Tiles")
	if not tiles_node:
		tiles_node = Node2D.new()
		tiles_node.name = "Tiles"
		add_child(tiles_node)
		if Engine.is_editor_hint():
			tiles_node.owner = get_tree().edited_scene_root

	for child in tiles_node.get_children():
		child.queue_free()

	_cell_nodes.clear()
	_cell_positions.clear()

	# Layout: 11x11 area within 15x15 grid. Center is (7,7).
	# NW: Green, NE: Orange, SE: Yellow, SW: Cyan
	for y in range(15):
		for x in range(15):
			var tex: String = ""

			if x >= 2 and x <= 3 and y >= 2 and y <= 3:
				tex = CHIP_GREEN
			elif x >= 11 and x <= 12 and y >= 2 and y <= 3:
				tex = CHIP_ORANGE
			elif x >= 11 and x <= 12 and y >= 11 and y <= 12:
				tex = CHIP_YELLOW
			elif x >= 2 and x <= 3 and y >= 11 and y <= 12:
				tex = CHIP_CYAN
			elif x == 7 and y == 7:
				tex = CHIP_RED

			var is_north := y >= 2 and y <= 6 and x >= 6 and x <= 8
			var is_east := x >= 8 and x <= 12 and y >= 6 and y <= 8
			var is_south := y >= 8 and y <= 12 and x >= 6 and x <= 8
			var is_west := x >= 2 and x <= 6 and y >= 6 and y <= 8

			if is_north:
				if x == 7 and y >= 3 and y <= 6:
					tex = CHIP_GREEN
				elif x == 8 and y == 2:
					tex = CHIP_GREEN
				else:
					tex = CHIP_PURPLE
			elif is_east:
				if y == 7 and x >= 8 and x <= 11:
					tex = CHIP_ORANGE
				elif x == 12 and y == 8:
					tex = CHIP_ORANGE
				else:
					tex = CHIP_PURPLE
			elif is_south:
				if x == 7 and y >= 8 and y <= 11:
					tex = CHIP_YELLOW
				elif x == 6 and y == 12:
					tex = CHIP_YELLOW
				else:
					tex = CHIP_PURPLE
			elif is_west:
				if y == 7 and x >= 3 and x <= 6:
					tex = CHIP_CYAN
				elif x == 2 and y == 6:
					tex = CHIP_CYAN
				else:
					tex = CHIP_PURPLE

			if tex != "":
				_add_tile(tex, Vector2i(x, y), tiles_node)
