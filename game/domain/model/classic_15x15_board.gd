class_name Classic15x15Board
extends RefCounted
## Класическа 15×15 изометрична дъска като domain данни (Tasks #37–#43).
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
## PlayerBoardDefinition.base_cells.
##
## Task #40: spawn_cell_for(player_id) дефинира SPAWN клетката за всеки seat
## (PlayerId → cell_id). Същата стойност влиза в
## PlayerBoardDefinition.spawn_cell.
##
## Task #41: main_loop_cell_ids() е затвореното общо трасе като наредени
## cell_id (PATH + SPAWN). Редът следва ludo_board.gd / CURRENT_YELLOW_BEHAVIOR
## жълтия маршрут без home stretch; индекс 0 = yellow spawn (6,12).
## create() попълва BoardDefinition.main_loop.
##
## Task #42: home_stretch_cells_for(player_id) дефинира 4 HOME клетките към
## центъра за всеки seat; build_player_definitions() събира пълните seats
## (spawn + loop индекси + home_stretch + base). create() ги попълва.
##
## Task #43: player_route_cell_ids_for(player_id) генерира пълния маршрут на seat
## = main_loop (циклично от spawn до home_entry) + home_stretch. Същата логика
## като BoardDefinition.build_player_route(); не включва CENTER.
##
## Task #44: при 2 играчи активните seats са срещуположни бази (NW↔SE или NE↔SW).
## Конфигурацията е в MatchConfig (DEFAULT/ALTERNATE_SEATS_2P); дъската филтрира
## чрез BoardDefinition.get_active_player_definitions() / default_two_player_seats().
##
## Task #45: при 3 играчи активните seats са кои да е три от четирите.
## Конфигурацията е в MatchConfig (DEFAULT_SEATS_3P / three_player_seat_trios());
## дъската филтрира чрез get_active_player_definitions() / default_three_player_seats().
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

## Дължина на общото трасе (36 PATH + 4 SPAWN) — BoardDefinition.main_loop.
const MAIN_LOOP_LENGTH: int = 40

## Брой HOME клетки на seat — съвпада с PlayerBoardDefinition.HOME_STRETCH_LENGTH.
const HOME_STRETCH_CELLS_PER_PLAYER: int = 4

## Общ брой HOME клетки (4 seats × 4) — съвпада с CellType.HOME count в cells.
const HOME_STRETCH_CELL_COUNT: int = 16

## Дължина на пълния маршрут на seat: цялото main_loop + home stretch (без CENTER).
## path_index 0 = spawn; последният индекс = последната HOME клетка преди финал.
const PLAYER_ROUTE_LENGTH: int = MAIN_LOOP_LENGTH + HOME_STRETCH_CELLS_PER_PLAYER


## BoardDefinition с board_id classic_15x15, cells, main_loop и 4 seats.
static func create() -> BoardDefinition:
	return BoardDefinition.create(
			BOARD_ID, build_cells(), main_loop_cell_ids(), build_player_definitions())


## Подразбиращи се активни seats за 2P — GREEN↔YELLOW (съвпада с MatchConfig.DEFAULT_SEATS_2P).
static func default_two_player_seats() -> Array[StringName]:
	return MatchConfig.DEFAULT_SEATS_2P.duplicate()


## Алтернативната срещуположна двойка за 2P — ORANGE↔CYAN (MatchConfig.ALTERNATE_SEATS_2P).
static func alternate_two_player_seats() -> Array[StringName]:
	return MatchConfig.ALTERNATE_SEATS_2P.duplicate()


## Двете валидни срещуположни двойки за 2P на тази дъска (Task #44 / §3.3).
static func two_player_opposite_seat_pairs() -> Array:
	return MatchConfig.opposite_seat_pairs()


## PlayerBoardDefinition само за активните 2P seats (редът следва player_ids).
## При невалидна двойка → празен масив. Пълната дъска (create()) остава с 4 seats.
static func build_active_player_definitions_for_two_players(
		player_ids: Array = []
) -> Array[PlayerBoardDefinition]:
	var seats: Array = player_ids
	if seats.is_empty():
		seats = default_two_player_seats()
	if not MatchConfig.is_valid_two_player_seats(seats):
		return []
	var result: Array[PlayerBoardDefinition] = []
	for pid in seats:
		var player_id := StringName(pid)
		result.append(PlayerBoardDefinition.create(
				player_id,
				spawn_cell_for(player_id),
				start_loop_index_for(player_id),
				home_entry_loop_index_for(player_id),
				home_stretch_cells_for(player_id),
				base_cells_for(player_id)))
	return result


## Подразбиращи се активни seats за 3P — без CYAN (съвпада с MatchConfig.DEFAULT_SEATS_3P).
static func default_three_player_seats() -> Array[StringName]:
	return MatchConfig.DEFAULT_SEATS_3P.duplicate()


## Четирите валидни 3P тройки на тази дъска (Task #45 / §3.3).
static func three_player_seat_trios() -> Array:
	return MatchConfig.three_player_seat_trios()


## PlayerBoardDefinition само за активните 3P seats (редът следва player_ids).
## При невалидна тройка → празен масив. Пълната дъска (create()) остава с 4 seats.
static func build_active_player_definitions_for_three_players(
		player_ids: Array = []
) -> Array[PlayerBoardDefinition]:
	var seats: Array = player_ids
	if seats.is_empty():
		seats = default_three_player_seats()
	if not MatchConfig.is_valid_three_player_seats(seats):
		return []
	var result: Array[PlayerBoardDefinition] = []
	for pid in seats:
		var player_id := StringName(pid)
		result.append(PlayerBoardDefinition.create(
				player_id,
				spawn_cell_for(player_id),
				start_loop_index_for(player_id),
				home_entry_loop_index_for(player_id),
				home_stretch_cells_for(player_id),
				base_cells_for(player_id)))
	return result


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


## Grid позиции на затвореното общо трасе в ред на движение (Task #41).
## Индекс 0 = yellow spawn (6,12); последната клетка (7,12) граничи с индекс 0.
## Съвпада с ludo_board.gd player_paths[&"yellow"] без home stretch.
## Не включва BASE, HOME или CENTER.
static func main_loop_grid_positions() -> Array[Vector2i]:
	return [
		# South arm, west column (north) — YELLOW spawn
		Vector2i(6, 12), Vector2i(6, 11), Vector2i(6, 10), Vector2i(6, 9), Vector2i(6, 8),
		# West arm, south row (west)
		Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8),
		# West arm, west column (north) — CYAN spawn at (2,6)
		Vector2i(2, 7), Vector2i(2, 6),
		# West arm, north row (east)
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6),
		# North arm, west column (north)
		Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2),
		# North arm, north row (east) — GREEN spawn at (8,2)
		Vector2i(7, 2), Vector2i(8, 2),
		# North arm, east column (south)
		Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
		# East arm, north row (east)
		Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6),
		# East arm, east column (south) — ORANGE spawn at (12,8)
		Vector2i(12, 7), Vector2i(12, 8),
		# East arm, south row (west)
		Vector2i(11, 8), Vector2i(10, 8), Vector2i(9, 8), Vector2i(8, 8),
		# South arm, east column (south)
		Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12),
		# Approach yellow home — YELLOW home_entry
		Vector2i(7, 12),
	]


## Стабилни cell_id на общото трасе в ред на движение (Task #41).
## Авторитетна стойност за BoardDefinition.main_loop; размерът е MAIN_LOOP_LENGTH.
static func main_loop_cell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for pos in main_loop_grid_positions():
		ids.append(CellId.from_grid(pos.x, pos.y))
	return ids


## Индекс в main_loop за cell_id, или -1 ако клетката не е на общото трасе.
static func main_loop_index_of(cell_id: StringName) -> int:
	var ids := main_loop_cell_ids()
	for i in ids.size():
		if ids[i] == cell_id:
			return i
	return -1


## True ако cell_id е част от общото трасе (PATH или SPAWN в main_loop).
static func is_main_loop_cell(cell_id: StringName) -> bool:
	return main_loop_index_of(cell_id) >= 0


## Grid позиции на HOME колоната за seat — редът е от входа към центъра.
## Съвпада с ludo_board.gd home_stretch_positions / HOME клетките в рамената.
## YELLOW: (7,11)→(7,8); GREEN: (7,3)→(7,6); ORANGE: (11,7)→(8,7); CYAN: (3,7)→(6,7).
## При невалиден player_id → празен масив.
static func home_stretch_grid_positions_for(player_id: StringName) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	match player_id:
		PlayerId.GREEN:
			# NW — от (7,2) home_entry на юг към центъра
			positions = [
				Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6),
			]
		PlayerId.ORANGE:
			# NE — от (12,7) home_entry на запад към центъра
			positions = [
				Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 7), Vector2i(8, 7),
			]
		PlayerId.YELLOW:
			# SE — CURRENT_YELLOW_BEHAVIOR §7 / ludo_board.gd
			positions = [
				Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
			]
		PlayerId.CYAN:
			# SW — от (2,7) home_entry на изток към центъра
			positions = [
				Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7),
			]
		_:
			pass
	return positions


## Стабилни cell_id за HOME клетките на seat (Task #42).
## Редът съвпада с home_stretch_grid_positions_for; размерът е HOME_STRETCH_CELLS_PER_PLAYER.
## При невалиден player_id → празен масив.
static func home_stretch_cells_for(player_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for pos in home_stretch_grid_positions_for(player_id):
		ids.append(CellId.from_grid(pos.x, pos.y))
	return ids


## Всички 16 HOME cell_id в seat ред PlayerId.ALL (GREEN → ORANGE → YELLOW → CYAN).
static func all_home_stretch_cell_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for player_id in PlayerId.ALL:
		ids.append_array(home_stretch_cells_for(player_id))
	return ids


## PlayerId на собственика на HOME клетката, или &"" ако cell_id не е home stretch.
static func home_stretch_owner(cell_id: StringName) -> StringName:
	for player_id in PlayerId.ALL:
		for home_id in home_stretch_cells_for(player_id):
			if home_id == cell_id:
				return player_id
	return &""


## True ако cell_id е една от HOME клетките на дадения seat.
static func is_home_stretch_cell_of(player_id: StringName, cell_id: StringName) -> bool:
	for home_id in home_stretch_cells_for(player_id):
		if home_id == cell_id:
			return true
	return false


## Grid позиция на последната main_loop клетка преди home stretch (home entry).
## GREEN (7,2), ORANGE (12,7), YELLOW (7,12), CYAN (2,7).
## При невалиден player_id → Vector2i(-1, -1).
static func home_entry_grid_position_for(player_id: StringName) -> Vector2i:
	match player_id:
		PlayerId.GREEN:
			return Vector2i(7, 2)
		PlayerId.ORANGE:
			return Vector2i(12, 7)
		PlayerId.YELLOW:
			return Vector2i(7, 12)
		PlayerId.CYAN:
			return Vector2i(2, 7)
		_:
			return Vector2i(-1, -1)


## Стабилен cell_id за home entry клетката на seat (част от main_loop, не HOME).
## При невалиден player_id → &"".
static func home_entry_cell_for(player_id: StringName) -> StringName:
	var pos := home_entry_grid_position_for(player_id)
	if pos.x < 0:
		return &""
	return CellId.from_grid(pos.x, pos.y)


## Индекс в main_loop на spawn клетката (= PlayerBoardDefinition.start_loop_index).
## При невалиден player_id → -1.
static func start_loop_index_for(player_id: StringName) -> int:
	return main_loop_index_of(spawn_cell_for(player_id))


## Индекс в main_loop на home entry (= PlayerBoardDefinition.home_entry_loop_index).
## При невалиден player_id → -1.
static func home_entry_loop_index_for(player_id: StringName) -> int:
	return main_loop_index_of(home_entry_cell_for(player_id))


## Пълни PlayerBoardDefinition за четирите seats в ред PlayerId.ALL (Task #42).
static func build_player_definitions() -> Array:
	var defs: Array = []
	for player_id in PlayerId.ALL:
		defs.append(PlayerBoardDefinition.create(
				player_id,
				spawn_cell_for(player_id),
				start_loop_index_for(player_id),
				home_entry_loop_index_for(player_id),
				home_stretch_cells_for(player_id),
				base_cells_for(player_id)))
	return defs


## Grid позиции на пълния маршрут на seat (Task #43):
## main_loop от spawn до home_entry (циклично, включително) + home_stretch.
## Редът съвпада с BoardDefinition.build_player_route / path_index семантиката.
## При невалиден player_id → празен масив.
static func player_route_grid_positions_for(player_id: StringName) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var start := start_loop_index_for(player_id)
	var home_entry := home_entry_loop_index_for(player_id)
	if start < 0 or home_entry < 0:
		return positions
	var loop := main_loop_grid_positions()
	var loop_len := loop.size()
	if loop_len == 0:
		return positions
	var i: int = start
	while true:
		positions.append(loop[i])
		if i == home_entry:
			break
		i = (i + 1) % loop_len
		if i == start:
			break
	positions.append_array(home_stretch_grid_positions_for(player_id))
	return positions


## Стабилни cell_id на пълния маршрут на seat (Task #43).
## Размерът е PLAYER_ROUTE_LENGTH за валиден PlayerId.
## При невалиден player_id → празен масив.
static func player_route_cell_ids_for(player_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for pos in player_route_grid_positions_for(player_id):
		ids.append(CellId.from_grid(pos.x, pos.y))
	return ids


## Индекс в маршрута на играча за cell_id, или -1 ако клетката не е на маршрута.
static func player_route_index_of(player_id: StringName, cell_id: StringName) -> int:
	var ids := player_route_cell_ids_for(player_id)
	for i in ids.size():
		if ids[i] == cell_id:
			return i
	return -1


## True ако cell_id е част от пълния маршрут на дадения seat (main_loop отрязък или HOME).
static func is_player_route_cell_of(player_id: StringName, cell_id: StringName) -> bool:
	return player_route_index_of(player_id, cell_id) >= 0


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

	if not (is_north or is_east or is_south or is_west):
		return -1
	# Единствен source of truth за HOME: home_stretch_grid_positions_for (Task #42).
	if _is_home_at(col, row):
		return CellType.HOME
	if _is_spawn_at(col, row):
		return CellType.SPAWN
	return CellType.PATH


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


## Единствен source of truth за HOME координати: home_stretch_grid_positions_for (Task #42).
static func _is_home_at(col: int, row: int) -> bool:
	for player_id in PlayerId.ALL:
		for pos in home_stretch_grid_positions_for(player_id):
			if pos.x == col and pos.y == row:
				return true
	return false


static func _put(cells: Dictionary, col: int, row: int, cell_type: int) -> void:
	var cell := CellDefinition.create_from_grid(col, row, cell_type)
	cells[cell.cell_id] = cell
