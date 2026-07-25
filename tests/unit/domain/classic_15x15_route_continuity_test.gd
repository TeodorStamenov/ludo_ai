class_name Classic15x15RouteContinuityTest
extends TestCase
## Unit тестове за непрекъснатостта на всички маршрути (Task #48).
##
## Покрива docs/V1_ARCHITECTURE.md §4.6 и docs/V1_GAME_DESIGN.md §3.3 /
## docs/CURRENT_YELLOW_BEHAVIOR.md §6:
##   Всеки seat има собствен маршрут (main_loop slice + home_stretch).
##   Последователните клетки са ортогонално съседни (manhattan = 1) —
##   без диагонали и без телепорти. Същото важи за затворения main_loop
##   и за home stretch сегментите.


# ── Helpers ───────────────────────────────────────────────────────────────────

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _assert_orthogonal_step(a: Vector2i, b: Vector2i, msg: String) -> void:
	var dist := _manhattan(a, b)
	assert_eq(dist, 1, "%s: %s → %s (manhattan=%d)" % [msg, a, b, dist])
	# Точно една ос се променя с ±1 (без диагонал).
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	assert_true((dx == 1 and dy == 0) or (dx == 0 and dy == 1),
			"%s: стъпката трябва да е ортогонална, не диагонал %s → %s" % [
				msg, a, b])


func _assert_grid_path_continuous(path: Array[Vector2i], label: String) -> void:
	assert_gt(path.size(), 1, "%s трябва да има поне 2 клетки" % label)
	for i in range(path.size() - 1):
		_assert_orthogonal_step(path[i], path[i + 1],
				"%s[%d→%d]" % [label, i, i + 1])


func _assert_cell_id_path_continuous(ids: Array[StringName], label: String) -> void:
	assert_gt(ids.size(), 1, "%s трябва да има поне 2 клетки" % label)
	for i in range(ids.size() - 1):
		var a := CellId.to_vec(ids[i])
		var b := CellId.to_vec(ids[i + 1])
		assert_true(CellId.is_valid(ids[i]), "%s[%d] невалиден cell_id" % [label, i])
		assert_true(CellId.is_valid(ids[i + 1]),
				"%s[%d] невалиден cell_id" % [label, i + 1])
		_assert_orthogonal_step(a, b, "%s[%d→%d] (%s→%s)" % [
			label, i, i + 1, ids[i], ids[i + 1]])


# ── Пълни player routes ───────────────────────────────────────────────────────

func test_each_player_route_grid_is_continuous() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_grid_positions_for(player_id)
		assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s route length" % player_id)
		_assert_grid_path_continuous(route, "route(%s)" % player_id)


func test_each_player_route_cell_ids_are_continuous() -> void:
	for player_id in PlayerId.ALL:
		var ids := Classic15x15Board.player_route_cell_ids_for(player_id)
		_assert_cell_id_path_continuous(ids, "route_ids(%s)" % player_id)


func test_build_player_route_is_continuous_for_all_seats() -> void:
	var board := Classic15x15Board.create()
	for player_id in PlayerId.ALL:
		var ids := board.build_player_route(player_id)
		assert_eq(ids.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH)
		_assert_cell_id_path_continuous(ids, "build_player_route(%s)" % player_id)


func test_restored_board_routes_remain_continuous() -> void:
	var restored := BoardDefinition.from_dict(Classic15x15Board.create().to_dict())
	for player_id in PlayerId.ALL:
		_assert_cell_id_path_continuous(
				restored.build_player_route(player_id),
				"restored route(%s)" % player_id)


# ── main_loop непрекъснатост (затворен контур) ────────────────────────────────

func test_main_loop_steps_are_continuous() -> void:
	var loop := Classic15x15Board.main_loop_grid_positions()
	assert_eq(loop.size(), Classic15x15Board.MAIN_LOOP_LENGTH)
	_assert_grid_path_continuous(loop, "main_loop")


func test_main_loop_wraps_continuously() -> void:
	# Последната клетка трябва да е съседна на първата — затворено трасе.
	var loop := Classic15x15Board.main_loop_grid_positions()
	var first: Vector2i = loop[0]
	var last: Vector2i = loop[loop.size() - 1]
	_assert_orthogonal_step(last, first,
			"main_loop wrap (%s → %s)" % [last, first])


func test_main_loop_cell_ids_are_continuous_including_wrap() -> void:
	var ids := Classic15x15Board.main_loop_cell_ids()
	_assert_cell_id_path_continuous(ids, "main_loop_ids")
	_assert_orthogonal_step(CellId.to_vec(ids[ids.size() - 1]), CellId.to_vec(ids[0]),
			"main_loop_ids wrap")


# ── home stretch + вход от main_loop ──────────────────────────────────────────

func test_each_home_stretch_is_continuous() -> void:
	for player_id in PlayerId.ALL:
		var home := Classic15x15Board.home_stretch_grid_positions_for(player_id)
		assert_eq(home.size(), Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
		_assert_grid_path_continuous(home, "home_stretch(%s)" % player_id)


func test_home_entry_to_first_home_is_continuous_for_all_seats() -> void:
	for player_id in PlayerId.ALL:
		var entry := Classic15x15Board.home_entry_grid_position_for(player_id)
		var first := Classic15x15Board.home_stretch_grid_positions_for(player_id)[0]
		_assert_orthogonal_step(entry, first,
				"%s home_entry→home[0]" % player_id)


func test_route_junction_at_home_entry_is_continuous() -> void:
	# В пълния маршрут: последната main_loop клетка = home_entry; следва HOME[0].
	var main_len := Classic15x15Board.MAIN_LOOP_LENGTH
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_grid_positions_for(player_id)
		assert_eq(route[main_len - 1],
				Classic15x15Board.home_entry_grid_position_for(player_id))
		_assert_orthogonal_step(route[main_len - 1], route[main_len],
				"%s route home_entry→HOME" % player_id)


# ── Жълт прототип (CURRENT_YELLOW_BEHAVIOR §6) ────────────────────────────────

func test_yellow_prototype_route_is_fully_continuous() -> void:
	var route := Classic15x15Board.player_route_grid_positions_for(PlayerId.YELLOW)
	_assert_grid_path_continuous(route, "yellow prototype")
	# Референтни стъпки от YEL-041 / §6.
	_assert_orthogonal_step(Vector2i(6, 12), Vector2i(6, 11), "YEL spawn→+1")
	assert_eq(route[0], Vector2i(6, 12))
	assert_eq(route[1], Vector2i(6, 11))
	assert_eq(route[4], Vector2i(6, 8))
	_assert_orthogonal_step(route[3], route[4], "YEL path_index 3→4")


# ── Инварианти срещу „дупки“ в маршрута ───────────────────────────────────────

func test_no_route_contains_zero_or_long_jumps() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_grid_positions_for(player_id)
		for i in range(route.size() - 1):
			var dist := _manhattan(route[i], route[i + 1])
			assert_false(dist == 0,
					"%s[%d]: дублирана позиция / нулева стъпка" % [player_id, i])
			assert_false(dist > 1,
					"%s[%d]: скок с manhattan=%d (%s→%s)" % [
						player_id, i, dist, route[i], route[i + 1]])


func test_route_continuity_holds_across_main_loop_wrap_for_non_yellow() -> void:
	# CYAN/GREEN/ORANGE минават през края на main_loop обратно към индекс 0.
	for player_id in [PlayerId.CYAN, PlayerId.GREEN, PlayerId.ORANGE]:
		var route := Classic15x15Board.player_route_grid_positions_for(player_id)
		var yellow_spawn := Classic15x15Board.spawn_grid_position_for(PlayerId.YELLOW)
		var idx := -1
		for i in route.size():
			if route[i] == yellow_spawn:
				idx = i
				break
		assert_true(idx > 0, "%s трябва да съдържа yellow spawn след wrap" % player_id)
		_assert_orthogonal_step(route[idx - 1], route[idx],
				"%s wrap към yellow spawn" % player_id)
		if idx + 1 < Classic15x15Board.MAIN_LOOP_LENGTH:
			_assert_orthogonal_step(route[idx], route[idx + 1],
					"%s след yellow spawn" % player_id)
