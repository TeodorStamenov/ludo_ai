class_name BoardDefinitionValidatorTest
extends TestCase
## Unit тестове за BoardDefinitionValidator (Task #47 /
## docs/V1_ARCHITECTURE.md §4.6 / docs/V1_GAME_DESIGN.md §3.2 / §3.3).
##
## Покрива:
##   - Domain архитектура (RefCounted, път game/domain/).
##   - Валиден mini board и Classic15x15Board → Result.ok.
##   - Стабилни error codes за структурни и съгласувателни нарушения.
##   - BoardDefinition.is_valid() делегира към валидатора.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_validator_extends_ref_counted() -> void:
	var v := BoardDefinitionValidator.new()
	assert_true(v is RefCounted,
			"BoardDefinitionValidator трябва да extends RefCounted")


func test_validator_is_not_node() -> void:
	var v: Object = BoardDefinitionValidator.new()
	assert_false(v is Node,
			"BoardDefinitionValidator не трябва да extends Node")


func test_validator_script_path_is_in_domain() -> void:
	var v := BoardDefinitionValidator.new()
	var path: String = v.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"BoardDefinitionValidator трябва да е в game/domain/")


func test_result_extends_ref_counted() -> void:
	var result := BoardDefinitionValidator.Result.new()
	assert_true(result is RefCounted,
			"BoardDefinitionValidator.Result трябва да extends RefCounted")


# ── Валидни дъски ─────────────────────────────────────────────────────────────

func test_valid_mini_board() -> void:
	var board := _mini_board()
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.is_ok(), "mini board трябва да е валиден: %s" % str(result.error_codes))
	assert_eq(result.error_codes.size(), 0)
	assert_true(BoardDefinitionValidator.is_valid(board))


func test_valid_classic_15x15_board() -> void:
	var board := Classic15x15Board.create()
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.is_ok(),
			"Classic15x15Board.create() трябва да минава пълна валидация: %s" % [
				str(result.error_codes)])
	assert_true(board.is_valid())


# ── Делегиране от BoardDefinition ─────────────────────────────────────────────

func test_board_definition_is_valid_delegates_to_validator() -> void:
	var board := _mini_board()
	assert_eq(board.is_valid(), BoardDefinitionValidator.is_valid(board),
			"BoardDefinition.is_valid трябва да съвпада с валидатора")
	board.board_id = &""
	assert_eq(board.is_valid(), BoardDefinitionValidator.is_valid(board))
	assert_false(board.is_valid())


# ── Error codes — структура ───────────────────────────────────────────────────

func test_null_board_error() -> void:
	var result := BoardDefinitionValidator.validate(null)
	assert_true(result.is_invalid())
	assert_true(result.has_error(BoardDefinitionValidator.ERR_NULL_BOARD))
	assert_eq(result.first_error_code(), BoardDefinitionValidator.ERR_NULL_BOARD)
	assert_false(BoardDefinitionValidator.is_valid(null))


func test_empty_board_id_error() -> void:
	var board := _mini_board()
	board.board_id = &""
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_EMPTY_BOARD_ID))


func test_empty_cells_error() -> void:
	var board := _mini_board()
	board.cells.clear()
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_EMPTY_CELLS))


func test_empty_main_loop_error() -> void:
	var board := _mini_board()
	board.main_loop.clear()
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_EMPTY_MAIN_LOOP))


func test_invalid_seat_count_error() -> void:
	var board := _mini_board()
	board.player_definitions.pop_back()
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_INVALID_SEAT_COUNT))


func test_invalid_cell_error() -> void:
	var board := _mini_board()
	var bad := CellDefinition.new()
	bad.cell_id = &"not_a_cell"
	bad.cell_type = CellType.PATH
	board.cells[&"not_a_cell"] = bad
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_INVALID_CELL))


func test_cell_key_mismatch_error() -> void:
	var board := _mini_board()
	var cell := CellDefinition.create_from_grid(1, 1, CellType.PATH)
	board.cells[&"c_2_2"] = cell
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_CELL_KEY_MISMATCH))


func test_duplicate_main_loop_cell_error() -> void:
	var board := _mini_board()
	board.set_main_loop([&"c_6_12", &"c_6_11", &"c_6_10", &"c_6_12"])
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_DUPLICATE_MAIN_LOOP_CELL))


func test_invalid_main_loop_cell_id_error() -> void:
	var board := _mini_board()
	board.set_main_loop([&"c_6_12", &"bad", &"c_6_10", &"c_7_12"])
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_INVALID_MAIN_LOOP_CELL))


func test_duplicate_player_id_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	board.player_definitions[1] = yellow.duplicate_definition()
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_DUPLICATE_PLAYER_ID))


func test_invalid_player_definition_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	yellow.spawn_cell = &"not_a_cell"
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_INVALID_PLAYER_DEFINITION))


# ── Error codes — съгласуваност ───────────────────────────────────────────────

func test_main_loop_cell_missing_error() -> void:
	var board := _mini_board()
	board.cells.erase(&"c_6_11")
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_MAIN_LOOP_CELL_MISSING))


func test_main_loop_cell_wrong_type_error() -> void:
	var board := _mini_board()
	board.cells[&"c_6_11"] = CellDefinition.create_from_grid(6, 11, CellType.HOME)
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_MAIN_LOOP_CELL_TYPE))


func test_track_cell_not_in_loop_error() -> void:
	var board := _mini_board()
	board.put_cell(CellDefinition.create_from_grid(5, 5, CellType.PATH))
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_TRACK_CELL_NOT_IN_LOOP))


func test_spawn_not_in_loop_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	# Валиден CellId извън loop — PlayerBoardDefinition.is_valid остава true.
	yellow.spawn_cell = &"c_0_0"
	yellow.start_loop_index = 0
	board.put_cell(CellDefinition.create_from_grid(0, 0, CellType.SPAWN))
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_SPAWN_NOT_IN_LOOP))


func test_spawn_index_mismatch_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	yellow.start_loop_index = 1  # сочи към green spawn, не yellow
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_SPAWN_INDEX_MISMATCH))


func test_loop_index_out_of_range_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	yellow.home_entry_loop_index = 99
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_LOOP_INDEX_OUT_OF_RANGE))


func test_spawn_cell_type_error() -> void:
	var board := _mini_board()
	board.cells[&"c_6_12"] = CellDefinition.create_from_grid(6, 12, CellType.PATH)
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_SPAWN_CELL_TYPE))


func test_home_cell_missing_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	board.cells.erase(StringName(yellow.home_stretch[0]))
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_HOME_CELL_MISSING))


func test_home_cell_type_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	var home_id := StringName(yellow.home_stretch[0])
	var grid := CellId.to_vec(home_id)
	board.cells[home_id] = CellDefinition.create_from_grid(
			grid.x, grid.y, CellType.PATH)
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_HOME_CELL_TYPE))


func test_home_cell_in_loop_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	yellow.set_home_stretch([&"c_6_11", &"c_7_10", &"c_7_9", &"c_7_8"])
	# c_6_11 е в main_loop; коригираме cells за HOME тип на останалите.
	board.cells[&"c_6_11"] = CellDefinition.create_from_grid(6, 11, CellType.HOME)
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_HOME_CELL_IN_LOOP))


func test_base_cell_missing_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	board.cells.erase(StringName(yellow.base_cells[0]))
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_BASE_CELL_MISSING))


func test_base_cell_type_error() -> void:
	var board := _mini_board()
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	var base_id := StringName(yellow.base_cells[0])
	var grid := CellId.to_vec(base_id)
	board.cells[base_id] = CellDefinition.create_from_grid(
			grid.x, grid.y, CellType.HOME)
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_BASE_CELL_TYPE))


func test_shared_spawn_cell_error() -> void:
	var board := _mini_board()
	var green := board.get_player_definition(PlayerId.GREEN)
	green.spawn_cell = &"c_6_12"
	green.start_loop_index = 0
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_SHARED_SPAWN_CELL))


func test_shared_home_cell_error() -> void:
	var board := _mini_board()
	var green := board.get_player_definition(PlayerId.GREEN)
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	green.set_home_stretch(yellow.get_home_stretch())
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_SHARED_HOME_CELL))


func test_shared_base_cell_error() -> void:
	var board := _mini_board()
	var green := board.get_player_definition(PlayerId.GREEN)
	var yellow := board.get_player_definition(PlayerId.YELLOW)
	green.set_base_cells(yellow.get_base_cells())
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_SHARED_BASE_CELL))


func test_orphan_spawn_cell_error() -> void:
	var board := _mini_board()
	board.put_cell(CellDefinition.create_from_grid(5, 8, CellType.SPAWN))
	# PATH|SPAWN извън loop също ще гръмне — добавяме и в loop би дублирало.
	# Тук orphan SPAWN е извън loop → TRACK_CELL_NOT_IN_LOOP + ORPHAN_SPAWN.
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_ORPHAN_SPAWN_CELL))


func test_orphan_home_cell_error() -> void:
	var board := _mini_board()
	board.put_cell(CellDefinition.create_from_grid(8, 8, CellType.HOME))
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_ORPHAN_HOME_CELL))


func test_orphan_base_cell_error() -> void:
	var board := _mini_board()
	board.put_cell(CellDefinition.create_from_grid(9, 9, CellType.BASE))
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_ORPHAN_BASE_CELL))


func test_missing_center_error() -> void:
	var board := _mini_board()
	board.cells.erase(CellId.CENTER)
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_MISSING_CENTER))


func test_center_in_loop_error() -> void:
	var board := _mini_board()
	# Заместваме една SPAWN с CENTER в loop — нарушава и типове, и CENTER_IN_LOOP.
	board.main_loop[1] = CellId.CENTER
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.has_error(BoardDefinitionValidator.ERR_CENTER_IN_LOOP))


func test_collects_multiple_errors() -> void:
	var board := BoardDefinition.new()
	board.board_id = &""
	var result := BoardDefinitionValidator.validate(board)
	assert_true(result.is_invalid())
	assert_true(result.has_error(BoardDefinitionValidator.ERR_EMPTY_BOARD_ID))
	assert_true(result.has_error(BoardDefinitionValidator.ERR_EMPTY_CELLS))
	assert_true(result.has_error(BoardDefinitionValidator.ERR_EMPTY_MAIN_LOOP))
	assert_true(result.has_error(BoardDefinitionValidator.ERR_INVALID_SEAT_COUNT))
	assert_true(result.has_error(BoardDefinitionValidator.ERR_MISSING_CENTER))
	assert_gt(result.error_codes.size(), 1,
			"валидаторът трябва да събира множество грешки")


func test_result_first_error_helpers_on_ok() -> void:
	var result := BoardDefinitionValidator.Result.new()
	assert_true(result.is_ok())
	assert_eq(result.first_error_code(), &"")
	assert_eq(result.first_error_message(), "")
	assert_false(result.has_error(BoardDefinitionValidator.ERR_NULL_BOARD))


# ── Helpers ───────────────────────────────────────────────────────────────────

## Миниатюрна напълно съгласувана дъска (4 SPAWN в loop + homes + bases + center).
func _mini_board() -> BoardDefinition:
	var loop: Array = [&"c_6_12", &"c_6_11", &"c_6_10", &"c_7_12"]
	var cells: Dictionary = {}
	cells[&"c_6_12"] = CellDefinition.create_from_grid(6, 12, CellType.SPAWN)
	cells[&"c_6_11"] = CellDefinition.create_from_grid(6, 11, CellType.SPAWN)
	cells[&"c_6_10"] = CellDefinition.create_from_grid(6, 10, CellType.SPAWN)
	cells[&"c_7_12"] = CellDefinition.create_from_grid(7, 12, CellType.SPAWN)
	cells[CellId.CENTER] = CellDefinition.create_from_grid(7, 7, CellType.CENTER)

	var players: Array = [
		_seat(PlayerId.YELLOW, &"c_6_12", 0, 3,
				[&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8"],
				[&"c_11_11", &"c_12_11", &"c_11_12", &"c_12_12"]),
		_seat(PlayerId.GREEN, &"c_6_11", 1, 0,
				[&"c_7_3", &"c_7_4", &"c_7_5", &"c_7_6"],
				[&"c_2_2", &"c_3_2", &"c_2_3", &"c_3_3"]),
		_seat(PlayerId.ORANGE, &"c_6_10", 2, 1,
				[&"c_11_7", &"c_10_7", &"c_9_7", &"c_8_7"],
				[&"c_11_2", &"c_12_2", &"c_11_3", &"c_12_3"]),
		_seat(PlayerId.CYAN, &"c_7_12", 3, 2,
				[&"c_3_7", &"c_4_7", &"c_5_7", &"c_6_7"],
				[&"c_2_11", &"c_3_11", &"c_2_12", &"c_3_12"]),
	]

	for p in players:
		var player := p as PlayerBoardDefinition
		for home in player.home_stretch:
			var id := StringName(home)
			if not cells.has(id):
				var grid := CellId.to_vec(id)
				cells[id] = CellDefinition.create_from_grid(
						grid.x, grid.y, CellType.HOME)
		for base in player.base_cells:
			var id := StringName(base)
			if not cells.has(id):
				var grid := CellId.to_vec(id)
				cells[id] = CellDefinition.create_from_grid(
						grid.x, grid.y, CellType.BASE)

	return BoardDefinition.create(&"mini_test", cells, loop, players)


func _seat(
		player_id: StringName,
		spawn: StringName,
		start: int,
		home_entry: int,
		home_stretch: Array,
		base_cells: Array
) -> PlayerBoardDefinition:
	return PlayerBoardDefinition.create(
			player_id, spawn, start, home_entry, home_stretch, base_cells)
