@tool
class_name BoardView
extends Node2D
## Визуална дъска от BoardDefinition (docs/V1_ARCHITECTURE.md §6.2).
##
## Строи геометрията от BoardDefinition.cells; позиции чрез CellPositionMap.
## Текстурите идват от BoardThemeRegistry (content/themes/*.tres, #234) —
## текущата дъска е съдържанието на "jungle" темата (ThemeId.DEFAULT).
## Не пази текущ играч, зар, маршрути или правила.

@export var board_scale: float = 0.5:
	set(value):
		board_scale = value
		_build_board()

@export var theme_id: StringName = ThemeId.DEFAULT:
	set(value):
		theme_id = value
		_build_board()

@export var rebuild_board: bool = false:
	set(_value):
		_build_board()

## Domain геометрия — единствен източник кои клетки съществуват.
var _board_definition: BoardDefinition = null
## cell_id → PlayerId за BASE / SPAWN / HOME (от player_definitions).
var _cell_owners: Dictionary = {}
## cell_id (CellId) → Sprite2D на тайла. Празен до _build_board.
var _cell_nodes: Dictionary = {}
## Пълен cell_id → локална изометрична позиция (15×15).
var _cell_positions: CellPositionMap = CellPositionMap.new(0.5)
## theme_id → BoardThemeDefinition (content/themes/*.tres).
var _themes := BoardThemeRegistry.new()


func _ready() -> void:
	_build_board()
	var viewport_size: Vector2 = get_viewport_rect().size
	position = viewport_size / 2.0


## Задава BoardDefinition и престроява тайловете. null → classic_15x15 default.
func set_board_definition(definition: BoardDefinition) -> void:
	_board_definition = definition
	_rebuild_cell_owners()
	_build_board()


func get_board_definition() -> BoardDefinition:
	_ensure_board_definition()
	return _board_definition


func get_cell_local_position(grid_pos: Vector2i) -> Vector2:
	return IsometricMath.grid_to_local(grid_pos, board_scale)


func get_tile_display_width() -> float:
	return IsometricMath.tile_display_width(board_scale)


## Локална позиция по стабилен cell_id, или Vector2.ZERO при невалиден id.
func get_cell_position_by_id(cell_id: StringName) -> Vector2:
	return _cell_positions.position_of(cell_id)


## Sprite2D на клетката по cell_id, или null ако липсва.
## Никога не търси по editor-generated @Sprite2D@ имена.
func get_cell_node(cell_id: StringName) -> Node2D:
	return _cell_nodes.get(cell_id) as Node2D


## Най-близкият cell_id до локална позиция, или &"" ако няма клетка в радиус
## max_distance. Обратното на get_cell_position_by_id() — нужно е за
## debug подредбата, където клик по дъската трябва да стане клетка.
##
## Търсене по най-близък център вместо Area2D на всяка плочка: плочките са
## стотици и нямат collision (виж _add_tile), а изометричните ромбове биха
## изисквали полигони. За единичен клик обхождането е пренебрежимо.
func cell_id_at_local_position(
		local_pos: Vector2,
		max_distance: float = 0.0
) -> StringName:
	var limit: float = max_distance if max_distance > 0.0 else get_tile_display_width() * 0.5
	var best_id: StringName = &""
	var best_distance_sq: float = limit * limit
	for key in _cell_nodes.keys():
		var cell_id := StringName(str(key))
		var distance_sq: float = (
				_cell_positions.position_of(cell_id).distance_squared_to(local_pos))
		if distance_sq <= best_distance_sq:
			best_distance_sq = distance_sq
			best_id = cell_id
	return best_id


func _ensure_board_definition() -> void:
	if _board_definition != null:
		return
	_board_definition = Classic15x15Board.create()
	_rebuild_cell_owners()


func _rebuild_cell_owners() -> void:
	_cell_owners.clear()
	if _board_definition == null:
		return
	for item in _board_definition.player_definitions:
		var player := item as PlayerBoardDefinition
		if player == null:
			continue
		var player_id: StringName = player.player_id
		if player.spawn_cell != &"":
			_cell_owners[player.spawn_cell] = player_id
		for cell in player.base_cells:
			_cell_owners[StringName(cell)] = player_id
		for cell in player.home_stretch:
			_cell_owners[StringName(cell)] = player_id


func _texture_for_cell(cell: CellDefinition, theme: BoardThemeDefinition) -> Texture2D:
	if theme == null:
		return null
	match cell.cell_type:
		CellType.CENTER:
			return theme.center_texture
		CellType.BASE, CellType.SPAWN, CellType.HOME:
			var owner_texture := theme.texture_for_player(
					_cell_owners.get(cell.cell_id, &"") as StringName)
			return owner_texture if owner_texture != null else theme.path_texture
		_:
			return theme.path_texture


func _add_tile(texture: Texture2D, cell: CellDefinition, parent_node: Node) -> Sprite2D:
	var cell_id: StringName = cell.cell_id
	var sprite := Sprite2D.new()
	sprite.name = String(cell_id)
	sprite.set_meta(&"cell_id", cell_id)
	sprite.texture = texture
	sprite.position = _cell_positions.position_of(cell_id)
	sprite.scale = Vector2(board_scale, board_scale)
	sprite.centered = true
	sprite.z_index = _cell_positions.z_index_of(cell_id)
	parent_node.add_child(sprite)
	# Без owner — тайловете не се bake-ват в .tscn (#151).

	_cell_nodes[cell_id] = sprite
	return sprite


func _clear_tiles(tiles_node: Node) -> void:
	# free() веднага — queue_free би оставил старите cell_id имена в дървото
	# и новите sprite-и щяха да получат uniquified имена (c_8_2@2).
	for child in tiles_node.get_children():
		tiles_node.remove_child(child)
		child.free()
	_cell_nodes.clear()


func _sorted_cells() -> Array[CellDefinition]:
	var result: Array[CellDefinition] = []
	for key in _board_definition.cells.keys():
		var cell := _board_definition.cells[key] as CellDefinition
		if cell != null:
			result.append(cell)
	result.sort_custom(func(a: CellDefinition, b: CellDefinition) -> bool:
		var za: int = a.grid_col + a.grid_row
		var zb: int = b.grid_col + b.grid_row
		if za != zb:
			return za < zb
		if a.grid_row != b.grid_row:
			return a.grid_row < b.grid_row
		return a.grid_col < b.grid_col
	)
	return result


func _build_board() -> void:
	var tiles_node: Node = get_node_or_null("Tiles")
	if not tiles_node:
		tiles_node = Node2D.new()
		tiles_node.name = "Tiles"
		add_child(tiles_node)
		if Engine.is_editor_hint():
			tiles_node.owner = get_tree().edited_scene_root

	_clear_tiles(tiles_node)
	_ensure_board_definition()
	_cell_positions.rebuild(board_scale)

	var theme: BoardThemeDefinition = _themes.definition_for_or_default(theme_id)
	if theme == null:
		push_error("BoardView: няма нито една заредена тема (theme_id='%s')" % theme_id)
		return
	for cell in _sorted_cells():
		_add_tile(_texture_for_cell(cell, theme), cell, tiles_node)
