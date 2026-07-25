class_name Classic15x15PlayerRoutesTest
extends TestCase
## Unit тестове за маршрутите на четирите играча от общото трасе (Task #43).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6:
##   „Всеки играч има собствен маршрут, изчислен от общия loop + неговия home stretch.“
## и docs/CURRENT_YELLOW_BEHAVIOR.md §6 / §7 (жълтият прототипен маршрут).
##
##   - player_route_*_for() = main_loop[start..home_entry] (циклично) + home_stretch.
##   - Съвпадение с BoardDefinition.build_player_route() от Classic15x15Board.create().
##   - Не включва BASE / CENTER.


# ── Константи ─────────────────────────────────────────────────────────────────

func test_player_route_length_constant() -> void:
	assert_eq(Classic15x15Board.PLAYER_ROUTE_LENGTH, 44)
	assert_eq(
			Classic15x15Board.PLAYER_ROUTE_LENGTH,
			Classic15x15Board.MAIN_LOOP_LENGTH
					+ Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)


# ── Дължина / формат / уникалност ─────────────────────────────────────────────

func test_each_seat_has_full_route_length() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.player_route_grid_positions_for(player_id)
		var ids := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(grid.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s route grid length" % player_id)
		assert_eq(ids.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s route cell_id length" % player_id)


func test_player_route_cell_ids_match_grid_positions() -> void:
	for player_id in PlayerId.ALL:
		var grid := Classic15x15Board.player_route_grid_positions_for(player_id)
		var ids := Classic15x15Board.player_route_cell_ids_for(player_id)
		for i in grid.size():
			assert_eq(ids[i], CellId.from_grid(grid[i].x, grid[i].y),
					"%s route[%d]" % [player_id, i])
			assert_true(CellId.is_valid(ids[i]))


func test_player_route_cell_ids_are_unique_per_seat() -> void:
	for player_id in PlayerId.ALL:
		var ids := Classic15x15Board.player_route_cell_ids_for(player_id)
		var seen: Dictionary = {}
		for cell_id in ids:
			assert_false(seen.has(cell_id),
					"дублирана route клетка за %s: %s" % [player_id, cell_id])
			seen[cell_id] = true
		assert_eq(seen.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH)


func test_invalid_player_id_returns_empty_route() -> void:
	assert_eq(Classic15x15Board.player_route_grid_positions_for(&"purple").size(), 0)
	assert_eq(Classic15x15Board.player_route_cell_ids_for(&"").size(), 0)
	assert_eq(Classic15x15Board.player_route_cell_ids_for(&"red").size(), 0)
	assert_eq(Classic15x15Board.player_route_index_of(&"purple", &"c_6_12"), -1)


# ── Старт / край / home stretch сегмент ───────────────────────────────────────

func test_route_starts_at_own_spawn() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(route[0], Classic15x15Board.spawn_cell_for(player_id),
				"%s route[0] трябва да е spawn" % player_id)


func test_route_reaches_home_entry_before_home_stretch() -> void:
	# Последната main_loop клетка в маршрута е home_entry; след нея идва HOME.
	var main_len := Classic15x15Board.MAIN_LOOP_LENGTH
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(route[main_len - 1],
				Classic15x15Board.home_entry_cell_for(player_id),
				"%s route[%d] трябва да е home_entry" % [player_id, main_len - 1])
		assert_eq(route.slice(main_len),
				Classic15x15Board.home_stretch_cells_for(player_id),
				"%s home stretch опашка" % player_id)


func test_route_ends_at_last_home_stretch_cell() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var home := Classic15x15Board.home_stretch_cells_for(player_id)
		assert_eq(route[route.size() - 1], home[home.size() - 1],
				"%s последната route клетка" % player_id)


func test_route_excludes_base_and_center() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_false(route.has(CellId.CENTER),
				"%s не трябва да включва CENTER" % player_id)
		for base_id in Classic15x15Board.base_cells_for(player_id):
			assert_false(route.has(base_id),
					"%s не трябва да включва base %s" % [player_id, base_id])
		for other_id in PlayerId.ALL:
			if other_id == player_id:
				continue
			for home_id in Classic15x15Board.home_stretch_cells_for(other_id):
				assert_false(route.has(home_id),
						"%s не трябва да включва home на %s (%s)" % [
							player_id, other_id, home_id])


# ── Жълт прототип (CURRENT_YELLOW_BEHAVIOR §6) ────────────────────────────────

func test_yellow_route_matches_current_yellow_behavior() -> void:
	# Референция: docs/CURRENT_YELLOW_BEHAVIOR.md §6 и
	# scripts/ludo_board.gd player_paths[&"yellow"].
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
		Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
	]
	assert_eq(expected.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH)
	assert_eq(
			Classic15x15Board.player_route_grid_positions_for(PlayerId.YELLOW),
			expected)


func test_yel_041_steps_from_spawn_match_yellow_route() -> void:
	# docs/CURRENT_YELLOW_BEHAVIOR.md YEL-041: от (6,12) с 4 → (6,8).
	var route := Classic15x15Board.player_route_grid_positions_for(PlayerId.YELLOW)
	assert_eq(route[0], Vector2i(6, 12))
	assert_eq(route[4], Vector2i(6, 8))


# ── Генериране от main_loop за останалите seats ───────────────────────────────

func test_each_route_is_main_loop_slice_plus_home_stretch() -> void:
	var loop := Classic15x15Board.main_loop_cell_ids()
	var loop_len := loop.size()
	for player_id in PlayerId.ALL:
		var start := Classic15x15Board.start_loop_index_for(player_id)
		var home_entry := Classic15x15Board.home_entry_loop_index_for(player_id)
		var expected: Array[StringName] = []
		var i: int = start
		while true:
			expected.append(loop[i])
			if i == home_entry:
				break
			i = (i + 1) % loop_len
		expected.append_array(Classic15x15Board.home_stretch_cells_for(player_id))
		assert_eq(Classic15x15Board.player_route_cell_ids_for(player_id), expected,
				"%s трябва да е slice(main_loop) + home_stretch" % player_id)


func test_non_yellow_routes_wrap_around_main_loop() -> void:
	# CYAN/GREEN/ORANGE започват след индекс 0 → минават през края и се връщат.
	for player_id in [PlayerId.CYAN, PlayerId.GREEN, PlayerId.ORANGE]:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var start := Classic15x15Board.start_loop_index_for(player_id)
		assert_true(start > 0, "%s трябва да стартира след yellow spawn" % player_id)
		# Първата клетка след wrap към началото на main_loop е yellow spawn.
		var yellow_spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
		assert_true(route.has(yellow_spawn),
				"%s маршрутът обикаля през yellow spawn" % player_id)
		assert_true(
				Classic15x15Board.player_route_index_of(player_id, yellow_spawn)
						< Classic15x15Board.MAIN_LOOP_LENGTH)


func test_cyan_route_starts_and_enters_home_correctly() -> void:
	var route := Classic15x15Board.player_route_grid_positions_for(PlayerId.CYAN)
	assert_eq(route[0], Vector2i(2, 6))   # spawn
	assert_eq(route[1], Vector2i(3, 6))
	assert_eq(route[Classic15x15Board.MAIN_LOOP_LENGTH - 1], Vector2i(2, 7))  # home_entry
	assert_eq(route[Classic15x15Board.MAIN_LOOP_LENGTH], Vector2i(3, 7))      # first HOME
	assert_eq(route[route.size() - 1], Vector2i(6, 7))


func test_green_route_starts_and_enters_home_correctly() -> void:
	var route := Classic15x15Board.player_route_grid_positions_for(PlayerId.GREEN)
	assert_eq(route[0], Vector2i(8, 2))   # spawn
	assert_eq(route[1], Vector2i(8, 3))
	assert_eq(route[Classic15x15Board.MAIN_LOOP_LENGTH - 1], Vector2i(7, 2))  # home_entry
	assert_eq(route[Classic15x15Board.MAIN_LOOP_LENGTH], Vector2i(7, 3))      # first HOME
	assert_eq(route[route.size() - 1], Vector2i(7, 6))


func test_orange_route_starts_and_enters_home_correctly() -> void:
	var route := Classic15x15Board.player_route_grid_positions_for(PlayerId.ORANGE)
	assert_eq(route[0], Vector2i(12, 8))  # spawn
	assert_eq(route[1], Vector2i(11, 8))
	assert_eq(route[Classic15x15Board.MAIN_LOOP_LENGTH - 1], Vector2i(12, 7)) # home_entry
	assert_eq(route[Classic15x15Board.MAIN_LOOP_LENGTH], Vector2i(11, 7))     # first HOME
	assert_eq(route[route.size() - 1], Vector2i(8, 7))


# ── player_route_index_of / is_player_route_cell_of ───────────────────────────

func test_player_route_index_of_and_is_player_route_cell_of() -> void:
	assert_eq(Classic15x15Board.player_route_index_of(PlayerId.YELLOW, &"c_6_12"), 0)
	assert_eq(Classic15x15Board.player_route_index_of(PlayerId.YELLOW, &"c_6_8"), 4)
	assert_eq(Classic15x15Board.player_route_index_of(PlayerId.YELLOW, &"c_7_12"), 39)
	assert_eq(Classic15x15Board.player_route_index_of(PlayerId.YELLOW, &"c_7_11"), 40)
	assert_eq(Classic15x15Board.player_route_index_of(PlayerId.YELLOW, &"c_7_8"), 43)
	assert_true(Classic15x15Board.is_player_route_cell_of(PlayerId.YELLOW, &"c_7_8"))
	assert_false(Classic15x15Board.is_player_route_cell_of(PlayerId.YELLOW, &"c_7_3"))
	assert_false(Classic15x15Board.is_player_route_cell_of(PlayerId.YELLOW, &"c_11_11"))
	assert_false(Classic15x15Board.is_player_route_cell_of(PlayerId.YELLOW, CellId.CENTER))
	assert_eq(Classic15x15Board.player_route_index_of(PlayerId.YELLOW, &""), -1)


func test_spawn_index_is_zero_on_own_route() -> void:
	for player_id in PlayerId.ALL:
		var spawn := Classic15x15Board.spawn_cell_for(player_id)
		assert_eq(Classic15x15Board.player_route_index_of(player_id, spawn), 0)


# ── BoardDefinition.build_player_route интеграция ─────────────────────────────

func test_create_build_player_route_matches_helpers() -> void:
	var board := Classic15x15Board.create()
	for player_id in PlayerId.ALL:
		assert_eq(
				board.build_player_route(player_id),
				Classic15x15Board.player_route_cell_ids_for(player_id),
				"%s BoardDefinition.build_player_route ↔ helper" % player_id)


func test_all_four_routes_are_non_empty_and_equal_length() -> void:
	var board := Classic15x15Board.create()
	var lengths: Array[int] = []
	for player_id in PlayerId.ALL:
		var route := board.build_player_route(player_id)
		assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH)
		lengths.append(route.size())
	assert_eq(lengths[0], lengths[1])
	assert_eq(lengths[1], lengths[2])
	assert_eq(lengths[2], lengths[3])


func test_to_dict_preserves_player_routes() -> void:
	var original := Classic15x15Board.create()
	var restored := BoardDefinition.from_dict(original.to_dict())
	for player_id in PlayerId.ALL:
		assert_eq(
				restored.build_player_route(player_id),
				original.build_player_route(player_id),
				"%s route трябва да се възстановява от to_dict" % player_id)


func test_every_route_cell_exists_on_board() -> void:
	var board := Classic15x15Board.create()
	for player_id in PlayerId.ALL:
		for cell_id in Classic15x15Board.player_route_cell_ids_for(player_id):
			assert_true(board.has_cell(cell_id),
					"%s route клетка %s трябва да е в cells" % [player_id, cell_id])
			var cell := board.get_cell(cell_id)
			assert_true(
					cell.cell_type == CellType.PATH
							or cell.cell_type == CellType.SPAWN
							or cell.cell_type == CellType.HOME,
					"%s route %s трябва да е PATH|SPAWN|HOME" % [player_id, cell_id])
