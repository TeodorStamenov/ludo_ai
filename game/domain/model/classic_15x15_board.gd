class_name Classic15x15Board
extends RefCounted
## Класическа 15×15 изометрична дъска като domain данни (Tasks #37–#40).
##
## Премества геометрията от scripts/ludo_board.gd в BoardDefinition.cells:
## всяка заета клетка носи стабилен cell_id (CellId формат "c_{col}_{row}"),
## изометрични grid координати (grid_col/grid_row) и логически CellType.
## Темата/текстурите остават в presentation.
##
## Task #38: all_cell_ids() е авторитетният каталог от стабилни cell ID стойности
## за всички заети клетки — без NodePath / editor-generated имена.
##
## Task #39: base_cells_for(player_id) дефинира 2×2 BASE клетките за всеки seat
## (PlayerId → Array[cell_id]). Същите стойности влизат в
## PlayerBoardDefinition.base_cells при Tasks #41–#42.
##
## Task #40: spawn_cell_for(player_id) дефинира SPAWN клетката за всеки seat
## (PlayerId → cell_id). Същата стойност влиза в
## PlayerBoardDefinition.spawn_cell при Tasks #41–#42.
##
## main_loop / home_stretch / player_definitions — Tasks #41–#42;
## маршрутите — в Task #43. create() връща BoardDefinition с попълнени cells.
##
## Layout (docs/V1_GAME_DESIGN.md §3.3, ludo_board.gd):
##   4× бази 2×2, кръстовидни рамене 3×5, 4 home колони по 4, център (7,7).

## Съвпада с BoardDefinition.DEFAULT_BOARD_ID / MatchConfig.board_id.
const BOARD_ID: StringName = &"classic_15x15"

## Брой логически клетки: 36 PATH + 16 BASE + 16 HOME + 4 SPAWN + 1 CENTER.
const CELL_COUNT: int = 73

## Брой BASE клетки на seat — съвпада с PlayerBoardDefinition.BASE_CELL_COUNT.
const BASE_CELLS_PER_PLAYER: int = 4

## Общ брой BASE клетки (4 seats × 4) — съвпада с CellType.BASE count в cells.
const BASE_CELL_COUNT: int = 16

## Брой SPAWN клетки на seat (вход на трасето при зар 6).
const SPAWN_CELLS_PER_PLAYER: int = 1

## Общ брой SPAWN клетки (4 seats × 1) — съвпада с CellType.SPAWN count в cells.
const SPAWN_CELL_COUNT: int = 4


## BoardDefinition с board_id classic_15x15 и пълна cells карта (без loop/seats).
static func create() -> BoardDefinition:
	return BoardDefinition.create(BOARD_ID, build_cells())


## Dictionary[cell_id: StringName, CellDefinition] за всички заети клетки.
## Ключът на всяка клетка е нейният стабилен CellId (съвпада с cell.cell_id).
static func build_cells() -> Dictionary:
	var cells: Dictionary = {}
	_add_base_cells(cells)
	_add_center_cell(cells)
	_add_arm_cells(cells)
	return cells


## Всички стабилни cell_id за заетите клетки в детерминиран ред (row-major).
## Авторитетен каталог за classic_15x15 (Task #38); размерът е CELL_COUNT.
static func all_cell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row in CellId.BOARD_SIZE:
		for col in CellId.BOARD_SIZE:
			if has_grid_cell(col, row):
				ids.append(CellId.from_grid(col, row))
	return ids


## Стабилен cell_id за заета позиция, или &"" ако клетката не съществува.
static func cell_id_at(col: int, row: int) -> StringName:
	if not has_grid_cell(col, row):
		return &""
	return CellId.from_grid(col, row)


## Grid позиции (col, row) на 2×2 базата за seat — редът е row-major в блока.
## Съвпада с ludo_board.gd base_positions и PlayerId seat картата (NW/NE/SE/SW).
## При невалиден player_id → празен масив.
static func base_grid_positions_for(player_id: StringName) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	match player_id:
		PlayerId.GREEN:
			# NW
			positions = [
				Vector2i(2, 2), Vector2i(3, 2),
				Vector2i(2, 3), Vector2i(3, 3),
			]
		PlayerId.ORANGE:
			# NE
			positions = [
				Vector2i(11, 2), Vector2i(12, 2),
				Vector2i(11, 3), Vector2i(12, 3),
			]
		PlayerId.YELLOW:
			# SE — CURRENT_YELLOW_BEHAVIOR YEL-001
			positions = [
				Vector2i(11, 11), Vector2i(12, 11),
				Vector2i(11, 12), Vector2i(12, 12),
			]
		PlayerId.CYAN:
			# SW
			positions = [
				Vector2i(2, 11), Vector2i(3, 11),
				Vector2i(2, 12), Vector2i(3, 12),
			]
		_:
			pass
	return positions


## Стабилни cell_id за BASE клетките на seat (Task #39).
## Редът съвпада с base_grid_positions_for; размерът е BASE_CELLS_PER_PLAYER.
## При невалиден player_id → празен масив.
static func base_cells_for(player_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for pos in base_grid_positions_for(player_id):
		ids.append(CellId.from_grid(pos.x, pos.y))
	return ids


## Всички 16 BASE cell_id в seat ред PlayerId.ALL (GREEN → ORANGE → YELLOW → CYAN).
static func all_base_cell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for player_id in PlayerId.ALL:
		ids.append_array(base_cells_for(player_id))
	return ids


## PlayerId на собственика на BASE клетката, или &"" ако cell_id не е base.
static func base_owner(cell_id: StringName) -> StringName:
	for player_id in PlayerId.ALL:
		for base_id in base_cells_for(player_id):
			if base_id == cell_id:
				return player_id
	return &""


## True ако cell_id е една от BASE клетките на дадения seat.
static func is_base_cell_of(player_id: StringName, cell_id: StringName) -> bool:
	for base_id in base_cells_for(player_id):
		if base_id == cell_id:
			return true
	return false


## Grid позиция на SPAWN клетката за seat — съвпада с ludo_board.gd spawn_cells.
## GREEN (8,2) NW, ORANGE (12,8) NE, YELLOW (6,12) SE, CYAN (2,6) SW.
## При невалиден player_id → Vector2i(-1, -1).
static func spawn_grid_position_for(player_id: StringName) -> Vector2i:
	match player_id:
		PlayerId.GREEN:
			return Vector2i(8, 2)
		PlayerId.ORANGE:
			return Vector2i(12, 8)
		PlayerId.YELLOW:
			# CURRENT_YELLOW_BEHAVIOR YEL-020 / YEL-041
			return Vector2i(6, 12)
		PlayerId.CYAN:
			return Vector2i(2, 6)
		_:
			return Vector2i(-1, -1)


## Стабилен cell_id за SPAWN клетката на seat (Task #40).
## При невалиден player_id → &"".
static func spawn_cell_for(player_id: StringName) -> StringName:
	var pos := spawn_grid_position_for(player_id)
	if pos.x < 0:
		return &""
	return CellId.from_grid(pos.x, pos.y)


## Всички 4 SPAWN cell_id в seat ред PlayerId.ALL (GREEN → ORANGE → YELLOW → CYAN).
static func all_spawn_cell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for player_id in PlayerId.ALL:
		ids.append(spawn_cell_for(player_id))
	return ids


## PlayerId на собственика на SPAWN клетката, или &"" ако cell_id не е spawn.
static func spawn_owner(cell_id: StringName) -> StringName:
	for player_id in PlayerId.ALL:
		if spawn_cell_for(player_id) == cell_id:
			return player_id
	return &""


## True ако cell_id е SPAWN клетката на дадения seat.
static func is_spawn_cell_of(player_id: StringName, cell_id: StringName) -> bool:
	return spawn_cell_for(player_id) == cell_id and cell_id != &""


## Логически тип на клетката в (col, row), или -1 ако позицията е празна.
static func cell_type_at(col: int, row: int) -> int:
	if col < 0 or col >= CellId.BOARD_SIZE or row < 0 or row >= CellId.BOARD_SIZE:
		return -1
	if _is_base_cell(col, row):
		return CellType.BASE
	if col == 7 and row == 7:
		return CellType.CENTER
	return _arm_cell_type(col, row)


## True ако (col, row) е заета клетка от classic_15x15 геометрията.
static func has_grid_cell(col: int, row: int) -> bool:
	return cell_type_at(col, row) >= 0


static func _add_base_cells(cells: Dictionary) -> void:
	# Единствен source of truth: base_grid_positions_for (Task #39).
	for player_id in PlayerId.ALL:
		for pos in base_grid_positions_for(player_id):
			_put(cells, pos.x, pos.y, CellType.BASE)


static func _add_center_cell(cells: Dictionary) -> void:
	_put(cells, 7, 7, CellType.CENTER)


## Рамене на кръста (5×3) — PATH / SPAWN / HOME според ludo_board._build_board.
static func _add_arm_cells(cells: Dictionary) -> void:
	for row in CellId.BOARD_SIZE:
		for col in CellId.BOARD_SIZE:
			var cell_type := _arm_cell_type(col, row)
			if cell_type >= 0:
				_put(cells, col, row, cell_type)


static func _arm_cell_type(col: int, row: int) -> int:
	var is_north := row >= 2 and row <= 6 and col >= 6 and col <= 8
	var is_east := col >= 8 and col <= 12 and row >= 6 and row <= 8
	var is_south := row >= 8 and row <= 12 and col >= 6 and col <= 8
	var is_west := col >= 2 and col <= 6 and row >= 6 and row <= 8

	if is_north:
		if col == 7 and row >= 3 and row <= 6:
			return CellType.HOME
		if _is_spawn_at(col, row):
			return CellType.SPAWN
		return CellType.PATH
	if is_east:
		if row == 7 and col >= 8 and col <= 11:
			return CellType.HOME
		if _is_spawn_at(col, row):
			return CellType.SPAWN
		return CellType.PATH
	if is_south:
		if col == 7 and row >= 8 and row <= 11:
			return CellType.HOME
		if _is_spawn_at(col, row):
			return CellType.SPAWN
		return CellType.PATH
	if is_west:
		if row == 7 and col >= 3 and col <= 6:
			return CellType.HOME
		if _is_spawn_at(col, row):
			return CellType.SPAWN
		return CellType.PATH
	return -1


static func _is_base_cell(col: int, row: int) -> bool:
	for player_id in PlayerId.ALL:
		for pos in base_grid_positions_for(player_id):
			if pos.x == col and pos.y == row:
				return true
	return false


## Единствен source of truth за SPAWN координати: spawn_grid_position_for (Task #40).
static func _is_spawn_at(col: int, row: int) -> bool:
	for player_id in PlayerId.ALL:
		var pos := spawn_grid_position_for(player_id)
		if pos.x == col and pos.y == row:
			return true
	return false


static func _put(cells: Dictionary, col: int, row: int, cell_type: int) -> void:
	var cell := CellDefinition.create_from_grid(col, row, cell_type)
	cells[cell.cell_id] = cell
