class_name Classic15x15EqualRouteLengthsTest
extends TestCase
## Unit тестове за еднаква дължина на маршрутите (Task #50).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 и docs/V1_GAME_DESIGN.md §3.1 / §3.3:
##   Всеки seat има собствен маршрут = main_loop (пълен обход) + home_stretch.
##   Четирите маршрута трябва да са с еднаква дължина (справедлива геометрия) —
##   PLAYER_ROUTE_LENGTH = MAIN_LOOP_LENGTH + HOME_STRETCH_CELLS_PER_PLAYER.


# ── Константа / формула ───────────────────────────────────────────────────────

func test_player_route_length_formula() -> void:
	assert_eq(Classic15x15Board.PLAYER_ROUTE_LENGTH, 44)
	assert_eq(
			Classic15x15Board.PLAYER_ROUTE_LENGTH,
			Classic15x15Board.MAIN_LOOP_LENGTH
					+ Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
	assert_eq(Classic15x15Board.MAIN_LOOP_LENGTH, 40)
	assert_eq(Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER, 4)
	assert_eq(
			Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER,
			PlayerBoardDefinition.HOME_STRETCH_LENGTH)


# ── Helpers: еднаква дължина между всички seats ───────────────────────────────

func test_all_helper_routes_have_identical_length() -> void:
	var lengths: Array[int] = []
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.player_route_grid_positions_for(player_id)
		var ids := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(grid.size(), ids.size(),
				"%s: grid и cell_id дължините трябва да съвпадат" % player_id)
		assert_eq(grid.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s route length" % player_id)
		lengths.append(grid.size())
	_assert_all_equal(lengths, "helper route lengths")


func test_pairwise_route_lengths_are_equal() -> void:
	# Всеки seat срещу всеки друг — не само срещу константата.
	for i in PlayerId.ALL.size():
		var a: StringName = PlayerId.ALL[i]
		var len_a := Classic15x15Board.player_route_cell_ids_for(a).size()
		for j in range(i + 1, PlayerId.ALL.size()):
			var b: StringName = PlayerId.ALL[j]
			var len_b := Classic15x15Board.player_route_cell_ids_for(b).size()
			assert_eq(len_a, len_b, "%s (%d) ≠ %s (%d)" % [a, len_a, b, len_b])


# ── Сегменти с еднаква дължина ────────────────────────────────────────────────

func test_main_loop_segment_length_equal_for_all_seats() -> void:
	# Всеки маршрут обхожда цялото main_loop преди home stretch.
	var main_len := Classic15x15Board.MAIN_LOOP_LENGTH
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var main_segment := route.slice(0, main_len)
		assert_eq(main_segment.size(), main_len,
				"%s main_loop сегмент" % player_id)
		assert_eq(main_segment[0], Classic15x15Board.spawn_cell_for(player_id),
				"%s main сегмент започва от spawn" % player_id)
		assert_eq(
				main_segment[main_len - 1],
				Classic15x15Board.home_entry_cell_for(player_id),
				"%s main сегмент завършва на home_entry" % player_id)


func test_home_stretch_segment_length_equal_for_all_seats() -> void:
	var home_len := Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER
	var main_len := Classic15x15Board.MAIN_LOOP_LENGTH
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var home_segment := route.slice(main_len)
		assert_eq(home_segment.size(), home_len,
				"%s home stretch сегмент" % player_id)
		assert_eq(
				home_segment,
				Classic15x15Board.home_stretch_cells_for(player_id),
				"%s home stretch опашка" % player_id)


func test_loop_slice_from_start_to_home_entry_is_full_main_loop() -> void:
	# home_entry е непосредствено преди start (циклично) → обход = MAIN_LOOP_LENGTH.
	var loop_len := Classic15x15Board.MAIN_LOOP_LENGTH
	for player_id in PlayerId.ALL:
		var start := Classic15x15Board.start_loop_index_for(player_id)
		var home_entry := Classic15x15Board.home_entry_loop_index_for(player_id)
		var expected_steps := ((home_entry - start + loop_len) % loop_len) + 1
		assert_eq(expected_steps, loop_len,
				"%s: start=%d home_entry=%d → %d стъпки (очаквано %d)" % [
					player_id, start, home_entry, expected_steps, loop_len])


# ── BoardDefinition.build_player_route ────────────────────────────────────────

func test_build_player_route_lengths_are_equal() -> void:
	var board := Classic15x15Board.create()
	var lengths: Array[int] = []
	for player_id in PlayerId.ALL:
		var route := board.build_player_route(player_id)
		assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s build_player_route length" % player_id)
		assert_eq(
				route.size(),
				Classic15x15Board.player_route_cell_ids_for(player_id).size(),
				"%s build_player_route ↔ helper" % player_id)
		lengths.append(route.size())
	_assert_all_equal(lengths, "build_player_route lengths")


func test_restored_board_preserves_equal_route_lengths() -> void:
	var restored := BoardDefinition.from_dict(Classic15x15Board.create().to_dict())
	var lengths: Array[int] = []
	for player_id in PlayerId.ALL:
		var route := restored.build_player_route(player_id)
		assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s restored route length" % player_id)
		lengths.append(route.size())
	_assert_all_equal(lengths, "restored route lengths")


# ── Активни seats при 2/3/4 играчи ────────────────────────────────────────────

func test_active_seats_keep_equal_route_lengths_for_two_player() -> void:
	for pair in Classic15x15Board.two_player_opposite_seat_pairs():
		var lengths: Array[int] = []
		for player_id in pair:
			var route := Classic15x15Board.player_route_cell_ids_for(
					player_id as StringName)
			assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
					"2P %s route length" % player_id)
			lengths.append(route.size())
		_assert_all_equal(lengths, "2P pair %s" % str(pair))


func test_active_seats_keep_equal_route_lengths_for_three_player() -> void:
	for trio in MatchConfig.three_player_seat_trios():
		var lengths: Array[int] = []
		for player_id in trio:
			var route := Classic15x15Board.player_route_cell_ids_for(
					player_id as StringName)
			assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
					"3P %s route length" % player_id)
			lengths.append(route.size())
		_assert_all_equal(lengths, "3P trio %s" % str(trio))


func test_active_seats_keep_equal_route_lengths_for_four_player() -> void:
	var lengths: Array[int] = []
	for player_id in MatchConfig.DEFAULT_SEATS_4P:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"4P %s route length" % player_id)
		lengths.append(route.size())
	_assert_all_equal(lengths, "4P all seats")


# ── Жълт прототип като референтна дължина ─────────────────────────────────────

func test_non_yellow_routes_match_yellow_prototype_length() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md §6 — жълтият маршрут е шаблонът;
	# останалите seats трябва да имат същата дължина.
	var yellow_len := Classic15x15Board.player_route_cell_ids_for(
			PlayerId.YELLOW).size()
	assert_eq(yellow_len, Classic15x15Board.PLAYER_ROUTE_LENGTH)
	for player_id in [PlayerId.CYAN, PlayerId.GREEN, PlayerId.ORANGE]:
		assert_eq(
				Classic15x15Board.player_route_cell_ids_for(player_id).size(),
				yellow_len,
				"%s трябва да съвпада с yellow дължината (%d)" % [
					player_id, yellow_len])


# ── Helpers ───────────────────────────────────────────────────────────────────

func _assert_all_equal(values: Array[int], label: String) -> void:
	assert_gt(values.size(), 0, "%s: празен списък" % label)
	var first: int = values[0]
	for i in values.size():
		assert_eq(values[i], first,
				"%s[%d]=%d ≠ %s[0]=%d" % [label, i, values[i], label, first])
