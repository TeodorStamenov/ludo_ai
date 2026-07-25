class_name Classic15x15BaseCellsTest
extends TestCase
## Unit тестове за BASE клетките на classic_15x15 по seat (Task #39).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 (player_definitions.base_cells[]) и
## docs/V1_GAME_DESIGN.md §3.1 / §3.3:
##   - Всеки от четирите PlayerId има точно 4 BASE клетки (2×2).
##   - Стабилни cell_id от Classic15x15Board.base_cells_for().
##   - Съвпадение с ludo_board.gd base_positions и CURRENT_YELLOW_BEHAVIOR YEL-001.
## spawn — Task #40; main_loop / home — Tasks #41–#42.


# ── Константи ─────────────────────────────────────────────────────────────────

func test_base_cell_count_constants() -> void:
	assert_eq(Classic15x15Board.BASE_CELLS_PER_PLAYER,
			PlayerBoardDefinition.BASE_CELL_COUNT)
	assert_eq(Classic15x15Board.BASE_CELL_COUNT, 16)
	assert_eq(
			Classic15x15Board.BASE_CELLS_PER_PLAYER * PlayerId.COUNT,
			Classic15x15Board.BASE_CELL_COUNT)


# ── base_cells_for / base_grid_positions_for ──────────────────────────────────

func test_each_seat_has_exactly_four_base_cells() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.base_grid_positions_for(player_id)
		var ids := Classic15x15Board.base_cells_for(player_id)
		assert_eq(grid.size(), Classic15x15Board.BASE_CELLS_PER_PLAYER,
				"%s трябва да има 4 grid позиции" % player_id)
		assert_eq(ids.size(), Classic15x15Board.BASE_CELLS_PER_PLAYER,
				"%s трябва да има 4 base cell_id" % player_id)


func test_base_cells_for_matches_grid_positions() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.base_grid_positions_for(player_id)
		var ids := Classic15x15Board.base_cells_for(player_id)
		for i in grid.size():
			assert_eq(ids[i], CellId.from_grid(grid[i].x, grid[i].y),
					"%s[%d]: cell_id трябва да следва grid" % [player_id, i])


func test_invalid_player_id_returns_empty_base_cells() -> void:
	assert_eq(Classic15x15Board.base_grid_positions_for(&"purple").size(), 0)
	assert_eq(Classic15x15Board.base_cells_for(&"").size(), 0)
	assert_eq(Classic15x15Board.base_cells_for(&"red").size(), 0)


func test_prototype_base_cells_match_ludo_board() -> void:
	# Референция: scripts/ludo_board.gd base_positions.
	var expected: Dictionary = {
		PlayerId.GREEN: [
			Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3),
		],
		PlayerId.ORANGE: [
			Vector2i(11, 2), Vector2i(12, 2), Vector2i(11, 3), Vector2i(12, 3),
		],
		PlayerId.YELLOW: [
			Vector2i(11, 11), Vector2i(12, 11), Vector2i(11, 12), Vector2i(12, 12),
		],
		PlayerId.CYAN: [
			Vector2i(2, 11), Vector2i(3, 11), Vector2i(2, 12), Vector2i(3, 12),
		],
	}
	for player_id in PlayerId.ALL:
		var actual := Classic15x15Board.base_grid_positions_for(player_id)
		var want: Array = expected[player_id]
		assert_eq(actual.size(), want.size(), "размер за %s" % player_id)
		for i in want.size():
			assert_eq(actual[i], want[i] as Vector2i,
					"%s[%d]: очаквано %s" % [player_id, i, want[i]])


func test_yellow_base_cells_match_yel_001() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md YEL-001.
	var yellow := Classic15x15Board.base_cells_for(PlayerId.YELLOW)
	var expected: Array[StringName] = [
		&"c_11_11", &"c_12_11", &"c_11_12", &"c_12_12",
	]
	assert_eq(yellow.size(), expected.size())
	for i in expected.size():
		assert_eq(yellow[i], expected[i])


func test_base_cell_ids_are_stable_string_names() -> void:
	var expected_ids: Dictionary = {
		PlayerId.GREEN: [&"c_2_2", &"c_3_2", &"c_2_3", &"c_3_3"],
		PlayerId.ORANGE: [&"c_11_2", &"c_12_2", &"c_11_3", &"c_12_3"],
		PlayerId.YELLOW: [&"c_11_11", &"c_12_11", &"c_11_12", &"c_12_12"],
		PlayerId.CYAN: [&"c_2_11", &"c_3_11", &"c_2_12", &"c_3_12"],
	}
	for player_id in expected_ids.keys():
		var ids := Classic15x15Board.base_cells_for(player_id)
		var want: Array = expected_ids[player_id]
		for i in want.size():
			assert_eq(ids[i], want[i] as StringName)
			assert_true(CellId.is_valid(ids[i]))


# ── all_base_cell_ids ─────────────────────────────────────────────────────────

func test_all_base_cell_ids_count_and_order() -> void:
	var ids := Classic15x15Board.all_base_cell_ids()
	assert_eq(ids.size(), Classic15x15Board.BASE_CELL_COUNT)
	var offset: int = 0
	for player_id in PlayerId.ALL:
		var seat := Classic15x15Board.base_cells_for(player_id)
		for i in seat.size():
			assert_eq(ids[offset + i], seat[i],
					"all_base_cell_ids ред трябва да следва PlayerId.ALL")
		offset += seat.size()


func test_all_base_cell_ids_are_unique() -> void:
	var ids := Classic15x15Board.all_base_cell_ids()
	var seen: Dictionary = {}
	for cell_id in ids:
		assert_false(seen.has(cell_id), "дублирана base клетка: %s" % cell_id)
		seen[cell_id] = true
	assert_eq(seen.size(), Classic15x15Board.BASE_CELL_COUNT)


func test_all_base_cell_ids_subset_of_catalog() -> void:
	var catalog := Classic15x15Board.all_cell_ids()
	for cell_id in Classic15x15Board.all_base_cell_ids():
		assert_true(catalog.has(cell_id),
				"base %s трябва да е в all_cell_ids" % cell_id)


# ── Ownership helpers ─────────────────────────────────────────────────────────

func test_base_owner_returns_correct_seat() -> void:
	assert_eq(Classic15x15Board.base_owner(&"c_2_2"), PlayerId.GREEN)
	assert_eq(Classic15x15Board.base_owner(&"c_12_3"), PlayerId.ORANGE)
	assert_eq(Classic15x15Board.base_owner(&"c_11_11"), PlayerId.YELLOW)
	assert_eq(Classic15x15Board.base_owner(&"c_3_12"), PlayerId.CYAN)


func test_base_owner_non_base_returns_empty() -> void:
	assert_eq(Classic15x15Board.base_owner(&"c_6_12"), &"")  # yellow spawn
	assert_eq(Classic15x15Board.base_owner(&"c_7_7"), &"")   # center
	assert_eq(Classic15x15Board.base_owner(&"c_0_0"), &"")
	assert_eq(Classic15x15Board.base_owner(&""), &"")


func test_is_base_cell_of() -> void:
	assert_true(Classic15x15Board.is_base_cell_of(PlayerId.YELLOW, &"c_12_12"))
	assert_false(Classic15x15Board.is_base_cell_of(PlayerId.YELLOW, &"c_2_2"))
	assert_false(Classic15x15Board.is_base_cell_of(PlayerId.GREEN, &"c_6_12"))


# ── Съгласуваност с BoardDefinition.cells ─────────────────────────────────────

func test_every_base_cell_is_base_type_on_board() -> void:
	var board := Classic15x15Board.create()
	for cell_id in Classic15x15Board.all_base_cell_ids():
		var cell := board.get_cell(cell_id)
		assert_true(cell != null, "липсва base клетка %s" % cell_id)
		assert_true(cell.is_base(), "%s трябва да е CellType.BASE" % cell_id)
		assert_eq(Classic15x15Board.cell_type_at(cell.grid_col, cell.grid_row),
				CellType.BASE)


func test_board_base_type_count_matches_catalog() -> void:
	var board := Classic15x15Board.create()
	var base_count: int = 0
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell != null and cell.is_base():
			base_count += 1
			assert_true(Classic15x15Board.base_owner(cell.cell_id) != &"",
					"всяка BASE клетка трябва да има seat собственик")
	assert_eq(base_count, Classic15x15Board.BASE_CELL_COUNT)


func test_base_cells_usable_in_player_board_definition() -> void:
	var def := PlayerBoardDefinition.create(
			PlayerId.YELLOW,
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW),
			Classic15x15Board.start_loop_index_for(PlayerId.YELLOW),
			Classic15x15Board.home_entry_loop_index_for(PlayerId.YELLOW),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW),
			Classic15x15Board.base_cells_for(PlayerId.YELLOW))
	assert_true(def.is_valid())
	assert_eq(def.base_cell_count(), 4)
	assert_true(def.contains_base_cell(&"c_11_11"))
	assert_true(def.contains_base_cell(&"c_12_12"))
	assert_eq(def.spawn_cell, &"c_6_12")


func test_seats_do_not_share_base_cells() -> void:
	for a in PlayerId.ALL:
		for b in PlayerId.ALL:
			if a == b:
				continue
			for cell_id in Classic15x15Board.base_cells_for(a):
				assert_false(
						Classic15x15Board.is_base_cell_of(b, cell_id),
						"%s не трябва да споделя %s с %s" % [a, cell_id, b])
