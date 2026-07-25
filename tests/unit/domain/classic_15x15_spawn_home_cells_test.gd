class_name Classic15x15SpawnHomeCellsTest
extends TestCase
## Unit тестове за правилните spawn и home stretch клетки (Task #49).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 (player_definitions.spawn_cell /
## home_stretch[]) и docs/V1_GAME_DESIGN.md §3.2 / §3.3 /
## docs/CURRENT_YELLOW_BEHAVIOR.md YEL-030 / §7:
##   Всеки seat има точно една SPAWN клетка върху main_loop и точно 4 HOME
##   клетки към центъра. Стойностите съвпадат с ludo_board.gd и жълтия
##   прототип; create() / маршрутите ги ползват като source of truth.


# ── Golden tables (прототип / ludo_board.gd) ───────────────────────────────────

func _expected_spawn_grid() -> Dictionary:
	return {
		PlayerId.GREEN: Vector2i(8, 2),
		PlayerId.ORANGE: Vector2i(12, 8),
		PlayerId.YELLOW: Vector2i(6, 12),
		PlayerId.CYAN: Vector2i(2, 6),
	}


func _expected_spawn_cell_ids() -> Dictionary:
	return {
		PlayerId.GREEN: &"c_8_2",
		PlayerId.ORANGE: &"c_12_8",
		PlayerId.YELLOW: &"c_6_12",
		PlayerId.CYAN: &"c_2_6",
	}


func _expected_home_stretch_grid() -> Dictionary:
	return {
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


func _expected_home_stretch_cell_ids() -> Dictionary:
	return {
		PlayerId.GREEN: [&"c_7_3", &"c_7_4", &"c_7_5", &"c_7_6"],
		PlayerId.ORANGE: [&"c_11_7", &"c_10_7", &"c_9_7", &"c_8_7"],
		PlayerId.YELLOW: [&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8"],
		PlayerId.CYAN: [&"c_3_7", &"c_4_7", &"c_5_7", &"c_6_7"],
	}


func _assert_grid_array_eq(actual: Array[Vector2i], expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: размер" % label)
	for i in expected.size():
		assert_eq(actual[i], expected[i] as Vector2i,
				"%s[%d]: очаквано %s" % [label, i, expected[i]])


func _assert_cell_id_array_eq(actual: Array[StringName], expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: размер" % label)
	for i in expected.size():
		assert_eq(actual[i], expected[i] as StringName,
				"%s[%d]: очаквано %s" % [label, i, expected[i]])


# ── Правилни spawn клетки за четирите seats ───────────────────────────────────

func test_all_seats_have_correct_spawn_grid_positions() -> void:
	var expected := _expected_spawn_grid()
	for player_id in PlayerId.ALL:
		assert_eq(
				Classic15x15Board.spawn_grid_position_for(player_id),
				expected[player_id] as Vector2i,
				"%s spawn grid" % player_id)


func test_all_seats_have_correct_spawn_cell_ids() -> void:
	var expected := _expected_spawn_cell_ids()
	for player_id in PlayerId.ALL:
		var cell_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_eq(cell_id, expected[player_id] as StringName,
				"%s spawn cell_id" % player_id)
		assert_true(CellId.is_valid(cell_id))
		assert_eq(cell_id, CellId.from_vec(Classic15x15Board.spawn_grid_position_for(player_id)))


func test_yellow_spawn_matches_yel_030() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md YEL-030 — излизане към (6, 12).
	assert_eq(Classic15x15Board.spawn_grid_position_for(PlayerId.YELLOW), Vector2i(6, 12))
	assert_eq(Classic15x15Board.spawn_cell_for(PlayerId.YELLOW), &"c_6_12")


# ── Правилни home stretch клетки за четирите seats ────────────────────────────

func test_all_seats_have_correct_home_stretch_grid_positions() -> void:
	var expected := _expected_home_stretch_grid()
	for player_id in PlayerId.ALL:
		_assert_grid_array_eq(
				Classic15x15Board.home_stretch_grid_positions_for(player_id),
				expected[player_id] as Array,
				"home_stretch_grid(%s)" % player_id)


func test_all_seats_have_correct_home_stretch_cell_ids() -> void:
	var expected := _expected_home_stretch_cell_ids()
	for player_id in PlayerId.ALL:
		var ids := Classic15x15Board.home_stretch_cells_for(player_id)
		_assert_cell_id_array_eq(ids, expected[player_id] as Array,
				"home_stretch(%s)" % player_id)
		assert_eq(ids.size(), Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
		assert_eq(ids.size(), PlayerBoardDefinition.HOME_STRETCH_LENGTH)
		for cell_id in ids:
			assert_true(CellId.is_valid(cell_id))


func test_yellow_home_stretch_matches_current_yellow_behavior_section_7() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md §7 / YEL-051 — (7,11)→(7,8).
	_assert_cell_id_array_eq(
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW),
			[&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8"],
			"yellow home_stretch")
	assert_eq(
			Classic15x15Board.home_stretch_grid_positions_for(PlayerId.YELLOW)[0],
			Vector2i(7, 11))
	assert_eq(
			Classic15x15Board.home_stretch_grid_positions_for(PlayerId.YELLOW)[3],
			Vector2i(7, 8))


# ── Инварианти: spawn на трасето, home извън него ─────────────────────────────

func test_each_spawn_is_on_main_loop_and_not_in_home_stretch() -> void:
	for player_id in PlayerId.ALL:
		var spawn_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_true(Classic15x15Board.is_main_loop_cell(spawn_id),
				"%s spawn трябва да е в main_loop" % player_id)
		assert_eq(Classic15x15Board.home_stretch_owner(spawn_id), &"",
				"%s spawn не трябва да е HOME" % player_id)
		assert_false(
				Classic15x15Board.is_home_stretch_cell_of(player_id, spawn_id),
				"%s spawn ≠ собствена home клетка" % player_id)


func test_each_home_stretch_is_outside_main_loop_and_not_spawn() -> void:
	for player_id in PlayerId.ALL:
		for home_id in Classic15x15Board.home_stretch_cells_for(player_id):
			assert_false(Classic15x15Board.is_main_loop_cell(home_id),
					"home %s не трябва да е в main_loop" % home_id)
			assert_eq(Classic15x15Board.spawn_owner(home_id), &"",
					"home %s не трябва да е SPAWN" % home_id)


func test_spawn_and_home_stretch_cells_are_unique_across_seats() -> void:
	var seen_spawn: Dictionary = {}
	var seen_home: Dictionary = {}
	for player_id in PlayerId.ALL:
		var spawn_id := Classic15x15Board.spawn_cell_for(player_id)
		assert_false(seen_spawn.has(spawn_id),
				"дублиран spawn: %s" % spawn_id)
		seen_spawn[spawn_id] = player_id
		for home_id in Classic15x15Board.home_stretch_cells_for(player_id):
			assert_false(seen_home.has(home_id),
					"дублирана home: %s" % home_id)
			assert_false(seen_spawn.has(home_id),
					"home %s не трябва да съвпада със spawn" % home_id)
			seen_home[home_id] = player_id
	assert_eq(seen_spawn.size(), Classic15x15Board.SPAWN_CELL_COUNT)
	assert_eq(seen_home.size(), Classic15x15Board.HOME_STRETCH_CELL_COUNT)


# ── Геометрия: home към центъра, вход съседен на HOME[0] ──────────────────────

func test_home_stretch_last_cell_is_adjacent_to_center() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.home_stretch_grid_positions_for(player_id)
		var last: Vector2i = grid[grid.size() - 1]
		var dist := absi(last.x - 7) + absi(last.y - 7)
		assert_eq(dist, 1,
				"%s: последната HOME %s трябва да е съседна на CENTER" % [
					player_id, last])


func test_home_entry_is_adjacent_to_first_home_stretch_cell() -> void:
	for player_id in PlayerId.ALL:
		var entry := Classic15x15Board.home_entry_grid_position_for(player_id)
		var first := Classic15x15Board.home_stretch_grid_positions_for(player_id)[0]
		var dist := absi(entry.x - first.x) + absi(entry.y - first.y)
		assert_eq(dist, 1,
				"%s: home_entry %s ↔ HOME[0] %s" % [player_id, entry, first])


# ── Маршрутът ползва правилните spawn / home клетки ───────────────────────────

func test_each_route_starts_at_correct_spawn() -> void:
	var expected := _expected_spawn_cell_ids()
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(route[0], expected[player_id] as StringName,
				"%s route[0] трябва да е правилният spawn" % player_id)


func test_each_route_ends_with_correct_home_stretch() -> void:
	var expected := _expected_home_stretch_cell_ids()
	var main_len := Classic15x15Board.MAIN_LOOP_LENGTH
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var want: Array = expected[player_id]
		_assert_cell_id_array_eq(
				route.slice(main_len),
				want,
				"route home_stretch(%s)" % player_id)
		assert_eq(route[route.size() - 1], want[want.size() - 1] as StringName,
				"%s route край" % player_id)


# ── BoardDefinition / player_definitions ──────────────────────────────────────

func test_create_player_definitions_use_correct_spawn_and_home() -> void:
	var board := Classic15x15Board.create()
	var spawn_expected := _expected_spawn_cell_ids()
	var home_expected := _expected_home_stretch_cell_ids()
	for player_id in PlayerId.ALL:
		var def := board.get_player_definition(player_id)
		assert_true(def != null, "липсва seat %s" % player_id)
		assert_eq(def.spawn_cell, spawn_expected[player_id] as StringName)
		_assert_cell_id_array_eq(
				def.get_home_stretch(),
				home_expected[player_id] as Array,
				"def.home_stretch(%s)" % player_id)
		assert_true(def.is_valid(), "%s definition трябва да е валидна" % player_id)


func test_board_cell_types_match_correct_spawn_and_home() -> void:
	var board := Classic15x15Board.create()
	for player_id in PlayerId.ALL:
		var spawn_id := Classic15x15Board.spawn_cell_for(player_id)
		var spawn_cell := board.get_cell(spawn_id)
		assert_true(spawn_cell != null)
		assert_true(spawn_cell.is_spawn(),
				"%s трябва да е CellType.SPAWN" % spawn_id)
		for home_id in Classic15x15Board.home_stretch_cells_for(player_id):
			var home_cell := board.get_cell(home_id)
			assert_true(home_cell != null)
			assert_true(home_cell.is_home(),
					"%s трябва да е CellType.HOME" % home_id)


func test_validator_accepts_classic_board_spawn_and_home() -> void:
	var result := BoardDefinitionValidator.validate(Classic15x15Board.create())
	assert_true(result.is_ok(),
			"classic_15x15 трябва да минава валидация за spawn/home: %s" % str(
				result.error_codes))


func test_restored_board_preserves_correct_spawn_and_home() -> void:
	var original := Classic15x15Board.create()
	var restored := BoardDefinition.from_dict(original.to_dict())
	var spawn_expected := _expected_spawn_cell_ids()
	var home_expected := _expected_home_stretch_cell_ids()
	for player_id in PlayerId.ALL:
		var def := restored.get_player_definition(player_id)
		assert_eq(def.spawn_cell, spawn_expected[player_id] as StringName)
		_assert_cell_id_array_eq(
				def.get_home_stretch(),
				home_expected[player_id] as Array,
				"restored home_stretch(%s)" % player_id)
		assert_eq(
				restored.build_player_route(player_id)[0],
				spawn_expected[player_id] as StringName)
