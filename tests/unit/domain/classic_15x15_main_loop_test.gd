class_name Classic15x15MainLoopTest
extends TestCase
## Unit тестове за общото трасе (main_loop) на classic_15x15 (Task #41).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 (BoardDefinition.main_loop) и
## docs/V1_GAME_DESIGN.md §3.3 / CURRENT_YELLOW_BEHAVIOR §6:
##   - Затворена последователност от PATH + SPAWN cell_id.
##   - Редът съвпада с жълтия прототипен маршрут без home stretch.
##   - create() попълва BoardDefinition.main_loop.
## home_stretch / player_definitions — Task #42; маршрути — Task #43 (покрити отделно).


# ── Константи ─────────────────────────────────────────────────────────────────

func test_main_loop_length_constant() -> void:
	assert_eq(Classic15x15Board.MAIN_LOOP_LENGTH, 40)
	assert_eq(
			Classic15x15Board.MAIN_LOOP_LENGTH,
			36 + Classic15x15Board.SPAWN_CELL_COUNT,
			"main_loop = всички PATH + SPAWN клетки")


# ── main_loop_grid_positions / main_loop_cell_ids ─────────────────────────────

func test_main_loop_grid_positions_count() -> void:
	var positions := Classic15x15Board.main_loop_grid_positions()
	assert_eq(positions.size(), Classic15x15Board.MAIN_LOOP_LENGTH)


func test_main_loop_cell_ids_count_and_format() -> void:
	var ids := Classic15x15Board.main_loop_cell_ids()
	assert_eq(ids.size(), Classic15x15Board.MAIN_LOOP_LENGTH)
	for i in ids.size():
		var pos := Classic15x15Board.main_loop_grid_positions()[i]
		assert_eq(ids[i], CellId.from_grid(pos.x, pos.y),
				"cell_id[%d] трябва да следва grid" % i)
		assert_true(CellId.is_valid(ids[i]))


func test_main_loop_cell_ids_are_unique() -> void:
	var ids := Classic15x15Board.main_loop_cell_ids()
	var seen: Dictionary = {}
	for cell_id in ids:
		assert_false(seen.has(cell_id), "дублирана main_loop клетка: %s" % cell_id)
		seen[cell_id] = true
	assert_eq(seen.size(), Classic15x15Board.MAIN_LOOP_LENGTH)


func test_main_loop_starts_at_yellow_spawn() -> void:
	# Индекс 0 = yellow spawn — path_index=0 в CURRENT_YELLOW_BEHAVIOR YEL-020/YEL-041.
	assert_eq(Classic15x15Board.main_loop_grid_positions()[0], Vector2i(6, 12))
	assert_eq(Classic15x15Board.main_loop_cell_ids()[0], &"c_6_12")
	assert_eq(Classic15x15Board.main_loop_cell_ids()[0],
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))


func test_main_loop_ends_at_yellow_home_entry() -> void:
	# Последната клетка преди home stretch в жълтия маршрут.
	var last := Classic15x15Board.MAIN_LOOP_LENGTH - 1
	assert_eq(Classic15x15Board.main_loop_grid_positions()[last], Vector2i(7, 12))
	assert_eq(Classic15x15Board.main_loop_cell_ids()[last], &"c_7_12")


func test_main_loop_matches_yellow_prototype_without_home() -> void:
	# Референция: scripts/ludo_board.gd player_paths[&"yellow"] и
	# docs/CURRENT_YELLOW_BEHAVIOR.md §6 — без последните 4 home клетки.
	var expected: Array[Vector2i] = [
		Vector2i(6, 12), Vector2i(6, 11), Vector2i(6, 10), Vector2i(6, 9), Vector2i(6, 8),
		Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8),
		Vector2i(2, 7), Vector2i(2, 6),
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6),
		Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2),
		Vector2i(7, 2), Vector2i(8, 2),
		Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
		Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6),
		Vector2i(12, 7), Vector2i(12, 8),
		Vector2i(11, 8), Vector2i(10, 8), Vector2i(9, 8), Vector2i(8, 8),
		Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12),
		Vector2i(7, 12),
	]
	assert_eq(expected.size(), Classic15x15Board.MAIN_LOOP_LENGTH)
	assert_eq(Classic15x15Board.main_loop_grid_positions(), expected)


func test_yel_041_steps_from_spawn_match_main_loop() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md YEL-041: от (6,12) с 4 → (6,8).
	var loop := Classic15x15Board.main_loop_grid_positions()
	assert_eq(loop[0], Vector2i(6, 12))
	assert_eq(loop[1], Vector2i(6, 11))
	assert_eq(loop[2], Vector2i(6, 10))
	assert_eq(loop[3], Vector2i(6, 9))
	assert_eq(loop[4], Vector2i(6, 8))


# ── Всички spawn клетки ∈ main_loop ───────────────────────────────────────────

func test_all_spawn_cells_appear_in_main_loop() -> void:
	for player_id in PlayerId.ALL:
		var spawn_id := Classic15x15Board.spawn_cell_for(player_id)
		var index := Classic15x15Board.main_loop_index_of(spawn_id)
		assert_true(index >= 0,
				"spawn на %s (%s) трябва да е в main_loop" % [player_id, spawn_id])
		assert_eq(Classic15x15Board.main_loop_cell_ids()[index], spawn_id)


func test_spawn_loop_indices_match_prototype_order() -> void:
	# При старт от yellow spawn: Y→C→G→O по часовниковата стрелка.
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_6_12"), 0)   # YELLOW
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_2_6"), 10)   # CYAN
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_8_2"), 20)   # GREEN
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_12_8"), 30)  # ORANGE


# ── Покритие спрямо cells / типове ────────────────────────────────────────────

func test_main_loop_covers_exactly_path_and_spawn_cells() -> void:
	var board := Classic15x15Board.create()
	var loop_ids := Classic15x15Board.main_loop_cell_ids()
	var track_count: int = 0
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell == null:
			continue
		if cell.is_on_main_track():
			track_count += 1
			assert_true(Classic15x15Board.is_main_loop_cell(cell.cell_id),
					"%s е PATH|SPAWN, но липсва в main_loop" % cell.cell_id)
		else:
			assert_false(Classic15x15Board.is_main_loop_cell(cell.cell_id),
					"%s не е на трасето, но е в main_loop" % cell.cell_id)
	assert_eq(track_count, Classic15x15Board.MAIN_LOOP_LENGTH)
	assert_eq(loop_ids.size(), track_count)


func test_main_loop_excludes_base_home_center() -> void:
	assert_false(Classic15x15Board.is_main_loop_cell(&"c_11_11"))  # yellow base
	assert_false(Classic15x15Board.is_main_loop_cell(&"c_7_11"))   # yellow home
	assert_false(Classic15x15Board.is_main_loop_cell(CellId.CENTER))
	assert_false(Classic15x15Board.is_main_loop_cell(&"c_0_0"))
	assert_eq(Classic15x15Board.main_loop_index_of(&""), -1)


func test_every_main_loop_cell_is_path_or_spawn_type() -> void:
	var board := Classic15x15Board.create()
	for cell_id in Classic15x15Board.main_loop_cell_ids():
		var cell := board.get_cell(cell_id)
		assert_true(cell != null, "липсва main_loop клетка %s" % cell_id)
		assert_true(cell.is_on_main_track(),
				"%s трябва да е PATH или SPAWN" % cell_id)
		assert_false(cell.is_base())
		assert_false(cell.is_home())
		assert_false(cell.is_center())


func test_main_loop_subset_of_catalog() -> void:
	var catalog := Classic15x15Board.all_cell_ids()
	for cell_id in Classic15x15Board.main_loop_cell_ids():
		assert_true(catalog.has(cell_id),
				"main_loop %s трябва да е в all_cell_ids" % cell_id)


# ── Helpers ───────────────────────────────────────────────────────────────────

func test_main_loop_index_of_and_is_main_loop_cell() -> void:
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_6_12"), 0)
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_6_8"), 4)
	assert_eq(Classic15x15Board.main_loop_index_of(&"c_7_12"), 39)
	assert_true(Classic15x15Board.is_main_loop_cell(&"c_6_12"))
	assert_false(Classic15x15Board.is_main_loop_cell(&"c_7_11"))


# ── BoardDefinition.create интеграция ─────────────────────────────────────────

func test_create_populates_board_definition_main_loop() -> void:
	var board := Classic15x15Board.create()
	assert_eq(board.main_loop_length(), Classic15x15Board.MAIN_LOOP_LENGTH)
	assert_eq(board.get_main_loop(), Classic15x15Board.main_loop_cell_ids())
	assert_eq(board.main_loop[0], &"c_6_12")
	assert_eq(board.main_loop[39], &"c_7_12")


func test_to_dict_preserves_main_loop() -> void:
	var board := Classic15x15Board.create()
	var restored := BoardDefinition.from_dict(board.to_dict())
	assert_eq(restored.main_loop_length(), Classic15x15Board.MAIN_LOOP_LENGTH)
	assert_eq(restored.get_main_loop(), Classic15x15Board.main_loop_cell_ids())
	assert_true(board.equals(restored),
			"cells + main_loop трябва да се възстановяват идентично")


func test_create_includes_main_loop_with_player_definitions() -> void:
	# Task #42 попълва seats; main_loop остава независим каталог.
	var board := Classic15x15Board.create()
	assert_false(board.main_loop.is_empty())
	assert_eq(board.get_main_loop(), Classic15x15Board.main_loop_cell_ids())
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)
	assert_true(board.is_valid())
