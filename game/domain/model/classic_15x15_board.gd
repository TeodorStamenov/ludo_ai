class_name Classic15x15Board
extends RefCounted
## Класическа 15×15 изометрична дъска като domain данни (Tasks #37–#38).
##
## Премества геометрията от scripts/ludo_board.gd в BoardDefinition.cells:
## всяка заета клетка носи стабилен cell_id (CellId формат "c_{col}_{row}"),
## изометрични grid координати (grid_col/grid_row) и логически CellType.
## Темата/текстурите остават в presentation.
##
## Task #38: all_cell_ids() е авторитетният каталог от стабилни cell ID стойности
## за всички заети клетки — без NodePath / editor-generated имена.
##
## main_loop и player_definitions се допълват в Tasks #39–#42;
## маршрутите — в Task #43. create() връща BoardDefinition с попълнени cells.
##
## Layout (docs/V1_GAME_DESIGN.md §3.3, ludo_board.gd):
##   4× бази 2×2, кръстовидни рамене 3×5, 4 home колони по 4, център (7,7).

## Съвпада с BoardDefinition.DEFAULT_BOARD_ID / MatchConfig.board_id.
const BOARD_ID: StringName = &"classic_15x15"

## Брой логически клетки: 36 PATH + 16 BASE + 16 HOME + 4 SPAWN + 1 CENTER.
const CELL_COUNT: int = 73


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
	# NW green, NE orange, SE yellow, SW cyan — същите 2×2 като ludo_board.gd.
	var bases: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(11, 2), Vector2i(12, 2), Vector2i(11, 3), Vector2i(12, 3),
		Vector2i(11, 11), Vector2i(12, 11), Vector2i(11, 12), Vector2i(12, 12),
		Vector2i(2, 11), Vector2i(3, 11), Vector2i(2, 12), Vector2i(3, 12),
	]
	for pos in bases:
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
		if col == 8 and row == 2:
			return CellType.SPAWN
		return CellType.PATH
	if is_east:
		if row == 7 and col >= 8 and col <= 11:
			return CellType.HOME
		if col == 12 and row == 8:
			return CellType.SPAWN
		return CellType.PATH
	if is_south:
		if col == 7 and row >= 8 and row <= 11:
			return CellType.HOME
		if col == 6 and row == 12:
			return CellType.SPAWN
		return CellType.PATH
	if is_west:
		if row == 7 and col >= 3 and col <= 6:
			return CellType.HOME
		if col == 2 and row == 6:
			return CellType.SPAWN
		return CellType.PATH
	return -1


static func _is_base_cell(col: int, row: int) -> bool:
	var in_nw := col >= 2 and col <= 3 and row >= 2 and row <= 3
	var in_ne := col >= 11 and col <= 12 and row >= 2 and row <= 3
	var in_se := col >= 11 and col <= 12 and row >= 11 and row <= 12
	var in_sw := col >= 2 and col <= 3 and row >= 11 and row <= 12
	return in_nw or in_ne or in_se or in_sw


static func _put(cells: Dictionary, col: int, row: int, cell_type: int) -> void:
	var cell := CellDefinition.create_from_grid(col, row, cell_type)
	cells[cell.cell_id] = cell
