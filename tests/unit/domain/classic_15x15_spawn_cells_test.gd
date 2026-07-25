class_name Classic15x15SpawnCellsTest
extends TestCase
## Unit тестове за SPAWN клетките на classic_15x15 по seat (Task #40).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 (player_definitions.spawn_cell) и
## docs/V1_GAME_DESIGN.md §3.1 / §3.3:
##   - Всеки от четирите PlayerId има точно 1 SPAWN клетка.
##   - Стабилни cell_id от Classic15x15Board.spawn_cell_for().
##   - Съвпадение с ludo_board.gd spawn_cells и CURRENT_YELLOW_BEHAVIOR YEL-020.
## main_loop / home — Tasks #41–#42.


# ── Константи ─────────────────────────────────────────────────────────────────

func test_spawn_cell_count_constants() -> void:
	assert_eq(Classic15x15Board.SPAWN_CELLS_PER_PLAYER, 1)
	assert_eq(Classic15x15Board.SPAWN_CELL_COUNT, 4)
	assert_eq(
			Classic15x15Board.SPAWN_CELLS_PER_PLAYER * PlayerId.COUNT,
			Classic15x15Board.SPAWN_CELL_COUNT)


# ── spawn_cell_for / spawn_grid_position_for ──────────────────────────────────

func test_each_seat_has_exactly_one_spawn_cell() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.spawn_grid_position_for(player_id)
		var cell_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_true(grid.x >= 0 and grid.y >= 0,
				"%s трябва да има валидна spawn grid позиция" % player_id)
		assert_true(CellId.is_valid(cell_id),
				"%s трябва да има валиден spawn cell_id" % player_id)


func test_spawn_cell_for_matches_grid_position() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.spawn_grid_position_for(player_id)
		var cell_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_eq(cell_id, CellId.from_grid(grid.x, grid.y),
				"%s: cell_id трябва да следва grid" % player_id)


func test_invalid_player_id_returns_empty_spawn_cell() -> void:
	assert_eq(Classic15x15Board.spawn_grid_position_for(&"purple"), Vector2i(-1, -1))
	assert_eq(Classic15x15Board.spawn_cell_for(&""), &"")
	assert_eq(Classic15x15Board.spawn_cell_for(&"red"), &"")


func test_prototype_spawn_cells_match_ludo_board() -> void:
	# Референция: scripts/ludo_board.gd spawn_cells.
	var expected: Dictionary = {
		PlayerId.GREEN: Vector2i(8, 2),
		PlayerId.ORANGE: Vector2i(12, 8),
		PlayerId.YELLOW: Vector2i(6, 12),
		PlayerId.CYAN: Vector2i(2, 6),
	}
	for player_id in PlayerId.ALL:
		var actual := Classic15x15Board.spawn_grid_position_for(player_id)
		assert_eq(actual, expected[player_id] as Vector2i,
				"%s: очаквано %s" % [player_id, expected[player_id]])


func test_yellow_spawn_matches_yel_020() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md YEL-020 — излизане към (6, 12).
	assert_eq(Classic15x15Board.spawn_grid_position_for(PlayerId.YELLOW),
			Vector2i(6, 12))
	assert_eq(Classic15x15Board.spawn_cell_for(PlayerId.YELLOW), &"c_6_12")


func test_spawn_cell_ids_are_stable_string_names() -> void:
	var expected_ids: Dictionary = {
		PlayerId.GREEN: &"c_8_2",
		PlayerId.ORANGE: &"c_12_8",
		PlayerId.YELLOW: &"c_6_12",
		PlayerId.CYAN: &"c_2_6",
	}
	for player_id in expected_ids.keys():
		var cell_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_eq(cell_id, expected_ids[player_id] as StringName)
		assert_true(CellId.is_valid(cell_id))


# ── all_spawn_cell_ids ────────────────────────────────────────────────────────

func test_all_spawn_cell_ids_count_and_order() -> void:
	var ids := Classic15x15Board.all_spawn_cell_ids()
	assert_eq(ids.size(), Classic15x15Board.SPAWN_CELL_COUNT)
	for i in PlayerId.ALL.size():
		assert_eq(ids[i], Classic15x15Board.spawn_cell_for(PlayerId.ALL[i]),
				"all_spawn_cell_ids ред трябва да следва PlayerId.ALL")


func test_all_spawn_cell_ids_are_unique() -> void:
	var ids := Classic15x15Board.all_spawn_cell_ids()
	var seen: Dictionary = {}
	for cell_id in ids:
		assert_false(seen.has(cell_id), "дублирана spawn клетка: %s" % cell_id)
		seen[cell_id] = true
	assert_eq(seen.size(), Classic15x15Board.SPAWN_CELL_COUNT)


func test_all_spawn_cell_ids_subset_of_catalog() -> void:
	var catalog := Classic15x15Board.all_cell_ids()
	for cell_id in Classic15x15Board.all_spawn_cell_ids():
		assert_true(catalog.has(cell_id),
				"spawn %s трябва да е в all_cell_ids" % cell_id)


# ── Ownership helpers ─────────────────────────────────────────────────────────

func test_spawn_owner_returns_correct_seat() -> void:
	assert_eq(Classic15x15Board.spawn_owner(&"c_8_2"), PlayerId.GREEN)
	assert_eq(Classic15x15Board.spawn_owner(&"c_12_8"), PlayerId.ORANGE)
	assert_eq(Classic15x15Board.spawn_owner(&"c_6_12"), PlayerId.YELLOW)
	assert_eq(Classic15x15Board.spawn_owner(&"c_2_6"), PlayerId.CYAN)


func test_spawn_owner_non_spawn_returns_empty() -> void:
	assert_eq(Classic15x15Board.spawn_owner(&"c_11_11"), &"")  # yellow base
	assert_eq(Classic15x15Board.spawn_owner(&"c_7_7"), &"")    # center
	assert_eq(Classic15x15Board.spawn_owner(&"c_0_0"), &"")
	assert_eq(Classic15x15Board.spawn_owner(&""), &"")


func test_is_spawn_cell_of() -> void:
	assert_true(Classic15x15Board.is_spawn_cell_of(PlayerId.YELLOW, &"c_6_12"))
	assert_false(Classic15x15Board.is_spawn_cell_of(PlayerId.YELLOW, &"c_8_2"))
	assert_false(Classic15x15Board.is_spawn_cell_of(PlayerId.GREEN, &"c_6_12"))
	assert_false(Classic15x15Board.is_spawn_cell_of(PlayerId.GREEN, &""))


# ── Съгласуваност с BoardDefinition.cells ─────────────────────────────────────

func test_every_spawn_cell_is_spawn_type_on_board() -> void:
	var board := Classic15x15Board.create()
	for cell_id in Classic15x15Board.all_spawn_cell_ids():
		var cell := board.get_cell(cell_id)
		assert_true(cell != null, "липсва spawn клетка %s" % cell_id)
		assert_true(cell.is_spawn(), "%s трябва да е CellType.SPAWN" % cell_id)
		assert_eq(Classic15x15Board.cell_type_at(cell.grid_col, cell.grid_row),
				CellType.SPAWN)
		assert_true(cell.is_on_main_track(),
				"%s трябва да е част от общото трасе (PATH|SPAWN)" % cell_id)


func test_board_spawn_type_count_matches_catalog() -> void:
	var board := Classic15x15Board.create()
	var spawn_count: int = 0
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell != null and cell.is_spawn():
			spawn_count += 1
			assert_true(Classic15x15Board.spawn_owner(cell.cell_id) != &"",
					"всяка SPAWN клетка трябва да има seat собственик")
	assert_eq(spawn_count, Classic15x15Board.SPAWN_CELL_COUNT)


func test_spawn_cells_usable_in_player_board_definition() -> void:
	# Task #40 дава spawn_cell; home остава за #42 (placeholder тук).
	var def := PlayerBoardDefinition.create(
			PlayerId.YELLOW,
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW),
			0,
			40,
			[&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8"],
			Classic15x15Board.base_cells_for(PlayerId.YELLOW))
	assert_true(def.is_valid())
	assert_eq(def.spawn_cell, &"c_6_12")
	assert_true(def.is_spawn(&"c_6_12"))
	assert_false(def.contains_base_cell(&"c_6_12"))
	assert_false(def.contains_home_cell(&"c_6_12"))


func test_seats_do_not_share_spawn_cells() -> void:
	for a in PlayerId.ALL:
		for b in PlayerId.ALL:
			if a == b:
				continue
			var spawn_a := Classic15x15Board.spawn_cell_for(a)
			assert_false(
					Classic15x15Board.is_spawn_cell_of(b, spawn_a),
					"%s не трябва да споделя spawn %s с %s" % [a, spawn_a, b])


func test_spawn_cells_are_not_base_cells() -> void:
	for player_id in PlayerId.ALL:
		var spawn_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_eq(Classic15x15Board.base_owner(spawn_id), &"",
				"spawn %s не трябва да е BASE" % spawn_id)
		for base_id in Classic15x15Board.base_cells_for(player_id):
			assert_false(Classic15x15Board.is_spawn_cell_of(player_id, base_id))
