class_name Classic15x15HomeStretchTest
extends TestCase
## Unit тестове за HOME stretch клетките на classic_15x15 по seat (Task #42).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 (player_definitions.home_stretch[]) и
## docs/V1_GAME_DESIGN.md §3.2 / §3.3:
##   - Всеки от четирите PlayerId има точно 4 HOME клетки (колона към центъра).
##   - Стабилни cell_id от Classic15x15Board.home_stretch_cells_for().
##   - Съвпадение с ludo_board.gd / CURRENT_YELLOW_BEHAVIOR §7 за жълтия.
##   - create() попълва валидни player_definitions за всички seats.
## Маршрути (build_player_route / player_route_*_for) — Task #43 (отделни тестове).


# ── Константи ─────────────────────────────────────────────────────────────────

func test_home_stretch_cell_count_constants() -> void:
	assert_eq(Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER,
			PlayerBoardDefinition.HOME_STRETCH_LENGTH)
	assert_eq(Classic15x15Board.HOME_STRETCH_CELL_COUNT, 16)
	assert_eq(
			Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER * PlayerId.COUNT,
			Classic15x15Board.HOME_STRETCH_CELL_COUNT)


# ── home_stretch_cells_for / home_stretch_grid_positions_for ──────────────────

func test_each_seat_has_exactly_four_home_stretch_cells() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.home_stretch_grid_positions_for(player_id)
		var ids := Classic15x15Board.home_stretch_cells_for(player_id)
		assert_eq(grid.size(), Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER,
				"%s трябва да има 4 grid позиции" % player_id)
		assert_eq(ids.size(), Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER,
				"%s трябва да има 4 home cell_id" % player_id)


func test_home_stretch_cells_for_matches_grid_positions() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.home_stretch_grid_positions_for(player_id)
		var ids := Classic15x15Board.home_stretch_cells_for(player_id)
		for i in grid.size():
			assert_eq(ids[i], CellId.from_grid(grid[i].x, grid[i].y),
					"%s[%d]: cell_id трябва да следва grid" % [player_id, i])


func test_invalid_player_id_returns_empty_home_stretch() -> void:
	assert_eq(Classic15x15Board.home_stretch_grid_positions_for(&"purple").size(), 0)
	assert_eq(Classic15x15Board.home_stretch_cells_for(&"").size(), 0)
	assert_eq(Classic15x15Board.home_stretch_cells_for(&"red").size(), 0)


func test_prototype_home_stretch_match_board_geometry() -> void:
	# Референция: scripts/ludo_board.gd HOME клетки + yellow home_stretch_positions.
	var expected: Dictionary = {
		PlayerId.GREEN: [
			Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6),
		],
		PlayerId.ORANGE: [
			Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 7), Vector2i(8, 7),
		],
		PlayerId.YELLOW: [
			Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
		],
		PlayerId.CYAN: [
			Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7),
		],
	}
	for player_id in PlayerId.ALL:
		var actual := Classic15x15Board.home_stretch_grid_positions_for(player_id)
		var want: Array = expected[player_id]
		assert_eq(actual.size(), want.size(), "размер за %s" % player_id)
		for i in want.size():
			assert_eq(actual[i], want[i] as Vector2i,
					"%s[%d]: очаквано %s" % [player_id, i, want[i]])


func test_yellow_home_stretch_matches_current_yellow_behavior() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md §7 — (7,11) → (7,8).
	var yellow := Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)
	var expected: Array[StringName] = [
		&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8",
	]
	assert_eq(yellow.size(), expected.size())
	for i in expected.size():
		assert_eq(yellow[i], expected[i])


func test_home_stretch_cell_ids_are_stable_string_names() -> void:
	var expected_ids: Dictionary = {
		PlayerId.GREEN: [&"c_7_3", &"c_7_4", &"c_7_5", &"c_7_6"],
		PlayerId.ORANGE: [&"c_11_7", &"c_10_7", &"c_9_7", &"c_8_7"],
		PlayerId.YELLOW: [&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8"],
		PlayerId.CYAN: [&"c_3_7", &"c_4_7", &"c_5_7", &"c_6_7"],
	}
	for player_id in expected_ids.keys():
		var ids := Classic15x15Board.home_stretch_cells_for(player_id)
		var want: Array = expected_ids[player_id]
		for i in want.size():
			assert_eq(ids[i], want[i] as StringName)
			assert_true(CellId.is_valid(ids[i]))


func test_home_stretch_progresses_toward_center() -> void:
	# Последната HOME клетка е съседна на CENTER (7,7).
	var last_cells: Dictionary = {
		PlayerId.GREEN: Vector2i(7, 6),
		PlayerId.ORANGE: Vector2i(8, 7),
		PlayerId.YELLOW: Vector2i(7, 8),
		PlayerId.CYAN: Vector2i(6, 7),
	}
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.home_stretch_grid_positions_for(player_id)
		var last: Vector2i = grid[grid.size() - 1]
		assert_eq(last, last_cells[player_id] as Vector2i,
				"%s: последната home клетка трябва да сочи към центъра" % player_id)
		var dist := absi(last.x - 7) + absi(last.y - 7)
		assert_eq(dist, 1, "%s: последната home трябва да е съседна на CENTER" % player_id)


# ── all_home_stretch_cell_ids ─────────────────────────────────────────────────

func test_all_home_stretch_cell_ids_count_and_order() -> void:
	var ids := Classic15x15Board.all_home_stretch_cell_ids()
	assert_eq(ids.size(), Classic15x15Board.HOME_STRETCH_CELL_COUNT)
	var offset: int = 0
	for player_id in PlayerId.ALL:
		var seat := Classic15x15Board.home_stretch_cells_for(player_id)
		for i in seat.size():
			assert_eq(ids[offset + i], seat[i],
					"all_home_stretch_cell_ids ред трябва да следва PlayerId.ALL")
		offset += seat.size()


func test_all_home_stretch_cell_ids_are_unique() -> void:
	var ids := Classic15x15Board.all_home_stretch_cell_ids()
	var seen: Dictionary = {}
	for cell_id in ids:
		assert_false(seen.has(cell_id), "дублирана home клетка: %s" % cell_id)
		seen[cell_id] = true
	assert_eq(seen.size(), Classic15x15Board.HOME_STRETCH_CELL_COUNT)


func test_all_home_stretch_cell_ids_subset_of_catalog() -> void:
	var catalog := Classic15x15Board.all_cell_ids()
	for cell_id in Classic15x15Board.all_home_stretch_cell_ids():
		assert_true(catalog.has(cell_id),
				"home %s трябва да е в all_cell_ids" % cell_id)


# ── Ownership helpers ─────────────────────────────────────────────────────────

func test_home_stretch_owner_returns_correct_seat() -> void:
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_7_3"), PlayerId.GREEN)
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_11_7"), PlayerId.ORANGE)
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_7_11"), PlayerId.YELLOW)
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_6_7"), PlayerId.CYAN)


func test_home_stretch_owner_non_home_returns_empty() -> void:
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_11_11"), &"")  # yellow base
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_6_12"), &"")   # yellow spawn
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_7_12"), &"")   # yellow home entry
	assert_eq(Classic15x15Board.home_stretch_owner(&"c_7_7"), &"")    # center
	assert_eq(Classic15x15Board.home_stretch_owner(&""), &"")


func test_is_home_stretch_cell_of() -> void:
	assert_true(Classic15x15Board.is_home_stretch_cell_of(PlayerId.YELLOW, &"c_7_8"))
	assert_false(Classic15x15Board.is_home_stretch_cell_of(PlayerId.YELLOW, &"c_7_3"))
	assert_false(Classic15x15Board.is_home_stretch_cell_of(PlayerId.GREEN, &"c_7_11"))
	assert_false(Classic15x15Board.is_home_stretch_cell_of(PlayerId.GREEN, &""))


func test_seats_do_not_share_home_stretch_cells() -> void:
	for a in PlayerId.ALL:
		for b in PlayerId.ALL:
			if a == b:
				continue
			for cell_id in Classic15x15Board.home_stretch_cells_for(a):
				assert_false(
						Classic15x15Board.is_home_stretch_cell_of(b, cell_id),
						"%s не трябва да споделя %s с %s" % [a, cell_id, b])


func test_home_stretch_cells_are_not_base_or_spawn() -> void:
	for player_id in PlayerId.ALL:
		for home_id in Classic15x15Board.home_stretch_cells_for(player_id):
			assert_eq(Classic15x15Board.base_owner(home_id), &"",
					"home %s не трябва да е BASE" % home_id)
			assert_eq(Classic15x15Board.spawn_owner(home_id), &"",
					"home %s не трябва да е SPAWN" % home_id)
			assert_false(Classic15x15Board.is_main_loop_cell(home_id),
					"home %s не трябва да е в main_loop" % home_id)


# ── Home entry + loop индекси ─────────────────────────────────────────────────

func test_home_entry_positions_match_prototype() -> void:
	var expected: Dictionary = {
		PlayerId.GREEN: Vector2i(7, 2),
		PlayerId.ORANGE: Vector2i(12, 7),
		PlayerId.YELLOW: Vector2i(7, 12),
		PlayerId.CYAN: Vector2i(2, 7),
	}
	for player_id in PlayerId.ALL:
		var pos := Classic15x15Board.home_entry_grid_position_for(player_id)
		assert_eq(pos, expected[player_id] as Vector2i)
		assert_eq(Classic15x15Board.home_entry_cell_for(player_id),
				CellId.from_grid(pos.x, pos.y))
		assert_true(Classic15x15Board.is_main_loop_cell(
				Classic15x15Board.home_entry_cell_for(player_id)),
				"home entry на %s трябва да е в main_loop" % player_id)


func test_invalid_player_id_returns_empty_home_entry() -> void:
	assert_eq(Classic15x15Board.home_entry_grid_position_for(&"purple"), Vector2i(-1, -1))
	assert_eq(Classic15x15Board.home_entry_cell_for(&""), &"")
	assert_eq(Classic15x15Board.start_loop_index_for(&"red"), -1)
	assert_eq(Classic15x15Board.home_entry_loop_index_for(&"red"), -1)


func test_start_and_home_entry_loop_indices() -> void:
	assert_eq(Classic15x15Board.start_loop_index_for(PlayerId.YELLOW), 0)
	assert_eq(Classic15x15Board.home_entry_loop_index_for(PlayerId.YELLOW), 39)
	assert_eq(Classic15x15Board.start_loop_index_for(PlayerId.CYAN), 10)
	assert_eq(Classic15x15Board.home_entry_loop_index_for(PlayerId.CYAN), 9)
	assert_eq(Classic15x15Board.start_loop_index_for(PlayerId.GREEN), 20)
	assert_eq(Classic15x15Board.home_entry_loop_index_for(PlayerId.GREEN), 19)
	assert_eq(Classic15x15Board.start_loop_index_for(PlayerId.ORANGE), 30)
	assert_eq(Classic15x15Board.home_entry_loop_index_for(PlayerId.ORANGE), 29)


func test_home_entry_is_adjacent_to_first_home_stretch_cell() -> void:
	for player_id in PlayerId.ALL:
		var entry := Classic15x15Board.home_entry_grid_position_for(player_id)
		var first := Classic15x15Board.home_stretch_grid_positions_for(player_id)[0]
		var dist := absi(entry.x - first.x) + absi(entry.y - first.y)
		assert_eq(dist, 1,
				"%s: home entry %s трябва да е съседен на първата home %s" % [
					player_id, entry, first])


# ── Съгласуваност с BoardDefinition.cells ─────────────────────────────────────

func test_every_home_stretch_cell_is_home_type_on_board() -> void:
	var board := Classic15x15Board.create()
	for cell_id in Classic15x15Board.all_home_stretch_cell_ids():
		var cell := board.get_cell(cell_id)
		assert_true(cell != null, "липсва home клетка %s" % cell_id)
		assert_true(cell.is_home(), "%s трябва да е CellType.HOME" % cell_id)
		assert_eq(Classic15x15Board.cell_type_at(cell.grid_col, cell.grid_row),
				CellType.HOME)


func test_board_home_type_count_matches_catalog() -> void:
	var board := Classic15x15Board.create()
	var home_count: int = 0
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell != null and cell.is_home():
			home_count += 1
			assert_true(Classic15x15Board.home_stretch_owner(cell.cell_id) != &"",
					"всяка HOME клетка трябва да има seat собственик")
	assert_eq(home_count, Classic15x15Board.HOME_STRETCH_CELL_COUNT)


# ── player_definitions / create() ─────────────────────────────────────────────

func test_build_player_definitions_has_four_valid_seats() -> void:
	var defs := Classic15x15Board.build_player_definitions()
	assert_eq(defs.size(), BoardDefinition.SEAT_COUNT)
	assert_eq(defs.size(), PlayerId.COUNT)
	for i in PlayerId.ALL.size():
		var def := defs[i] as PlayerBoardDefinition
		assert_true(def != null)
		assert_eq(def.player_id, PlayerId.ALL[i])
		assert_true(def.is_valid(), "%s PlayerBoardDefinition трябва да е валиден" % def.player_id)


func test_player_definitions_use_home_stretch_and_base_spawn() -> void:
	for def in Classic15x15Board.build_player_definitions():
		var player := def as PlayerBoardDefinition
		assert_eq(player.spawn_cell, Classic15x15Board.spawn_cell_for(player.player_id))
		assert_eq(player.start_loop_index,
				Classic15x15Board.start_loop_index_for(player.player_id))
		assert_eq(player.home_entry_loop_index,
				Classic15x15Board.home_entry_loop_index_for(player.player_id))
		assert_eq(player.get_home_stretch(),
				Classic15x15Board.home_stretch_cells_for(player.player_id))
		assert_eq(player.get_base_cells(),
				Classic15x15Board.base_cells_for(player.player_id))


func test_create_populates_valid_board_with_player_definitions() -> void:
	var board := Classic15x15Board.create()
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)
	assert_true(board.is_valid(),
			"create() трябва да дава пълно валиден BoardDefinition след Task #42")
	for player_id in PlayerId.ALL:
		var def := board.get_player_definition(player_id)
		assert_true(def != null, "липсва seat %s" % player_id)
		assert_eq(def.home_stretch_length(),
				Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
		assert_eq(def.get_home_stretch(),
				Classic15x15Board.home_stretch_cells_for(player_id))


func test_yellow_player_definition_home_stretch_usable() -> void:
	var def := Classic15x15Board.create().get_player_definition(PlayerId.YELLOW)
	assert_true(def != null)
	assert_true(def.is_valid())
	assert_eq(def.spawn_cell, &"c_6_12")
	assert_eq(def.start_loop_index, 0)
	assert_eq(def.home_entry_loop_index, 39)
	assert_true(def.contains_home_cell(&"c_7_11"))
	assert_true(def.contains_home_cell(&"c_7_8"))
	assert_eq(def.home_stretch_index(&"c_7_11"), 0)
	assert_eq(def.home_stretch_index(&"c_7_8"), 3)
	assert_false(def.contains_home_cell(&"c_7_12"))
	assert_false(def.contains_base_cell(&"c_7_11"))


func test_to_dict_preserves_player_definitions_home_stretch() -> void:
	var board := Classic15x15Board.create()
	var restored := BoardDefinition.from_dict(board.to_dict())
	assert_true(board.equals(restored),
			"cells + main_loop + player_definitions трябва да се възстановяват идентично")
	for player_id in PlayerId.ALL:
		assert_eq(
				restored.get_player_definition(player_id).get_home_stretch(),
				Classic15x15Board.home_stretch_cells_for(player_id))
