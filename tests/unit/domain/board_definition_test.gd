class_name BoardDefinitionTest
extends TestCase
## Unit тестове за BoardDefinition (Task #36 / docs/V1_ARCHITECTURE.md, §4.6).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без тема.
##   - Полета: board_id, cells, main_loop, player_definitions.
##   - Helpers: get_cell, get_player_definition, build_player_route.
##   - is_valid() self-contained проверки (не пълния валидатор — Task #47).
##   - Сериализация to_dict / from_dict / equals / duplicate_definition.
##   - Миниатюрна 4-seat дъска (не classic_15x15 данни — Tasks #37–#43).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_board_definition_extends_ref_counted() -> void:
	var def := BoardDefinition.new()
	assert_true(def is RefCounted,
			"BoardDefinition трябва да extends RefCounted, не Node")


func test_board_definition_is_not_node() -> void:
	var def: Object = BoardDefinition.new()
	assert_false(def is Node,
			"BoardDefinition не трябва да extends Node — domain слой е без сцени")


func test_board_definition_script_path_is_in_domain_model() -> void:
	var def := BoardDefinition.new()
	var path: String = def.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"BoardDefinition трябва да е в game/domain/model/")


func test_to_dict_does_not_contain_theme_fields() -> void:
	var def := _mini_board()
	var d := def.to_dict()
	assert_false(d.has("theme_id"), "темата не е част от BoardDefinition")
	assert_false(d.has("texture"), "текстурата не е част от BoardDefinition")
	assert_false(d.has("color"), "цветът не е част от BoardDefinition")


# ── Константи и defaults ──────────────────────────────────────────────────────

func test_default_board_id_is_classic_15x15() -> void:
	assert_eq(BoardDefinition.DEFAULT_BOARD_ID, &"classic_15x15")
	var def := BoardDefinition.new()
	assert_eq(def.board_id, BoardDefinition.DEFAULT_BOARD_ID)


func test_board_size_matches_cell_id() -> void:
	assert_eq(BoardDefinition.BOARD_SIZE, CellId.BOARD_SIZE)
	assert_eq(BoardDefinition.BOARD_SIZE, 15)


func test_seat_count_is_four() -> void:
	assert_eq(BoardDefinition.SEAT_COUNT, PlayerId.COUNT)
	assert_eq(BoardDefinition.SEAT_COUNT, 4)


func test_defaults_are_empty_collections() -> void:
	var def := BoardDefinition.new()
	assert_eq(def.cell_count(), 0)
	assert_eq(def.main_loop_length(), 0)
	assert_eq(def.player_definition_count(), 0)
	assert_false(def.is_valid())


# ── Фабрика и helpers ─────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var def := _mini_board()
	assert_eq(def.board_id, &"mini_test")
	assert_eq(def.cell_count(), _expected_cell_count())
	assert_eq(def.main_loop_length(), 4)
	assert_eq(def.player_definition_count(), BoardDefinition.SEAT_COUNT)
	assert_true(def.is_valid())


func test_has_and_get_cell() -> void:
	var def := _mini_board()
	assert_true(def.has_cell(&"c_6_12"))
	var spawn := def.get_cell(&"c_6_12")
	assert_true(spawn != null)
	assert_true(spawn.is_spawn())
	assert_false(def.has_cell(&"c_0_0"))
	assert_true(def.get_cell(&"c_0_0") == null)


func test_get_cell_at_grid() -> void:
	var def := _mini_board()
	var spawn := def.get_cell_at_grid(6, 12)
	assert_true(spawn != null)
	assert_eq(spawn.cell_id, &"c_6_12")
	assert_true(def.has_cell_at_grid(6, 12))
	assert_false(def.has_cell_at_grid(0, 0))
	assert_true(def.get_cell_at_grid(-1, 0) == null)
	assert_true(def.get_cell_at_grid(15, 0) == null)


func test_put_cell_adds_and_replaces() -> void:
	var def := BoardDefinition.new()
	def.board_id = &"tmp"
	var cell := CellDefinition.create_from_grid(1, 1, CellType.PATH)
	def.put_cell(cell)
	assert_true(def.has_cell(&"c_1_1"))
	assert_eq(def.get_cell(&"c_1_1").cell_type, CellType.PATH)
	def.put_cell(CellDefinition.create_from_grid(1, 1, CellType.SPAWN))
	assert_eq(def.get_cell(&"c_1_1").cell_type, CellType.SPAWN)


func test_get_main_loop_returns_typed_copy() -> void:
	var def := _mini_board()
	var loop := def.get_main_loop()
	assert_eq(loop.size(), 4)
	assert_eq(loop[0], &"c_6_12")
	loop[0] = &"c_0_0"
	assert_eq(def.main_loop[0], &"c_6_12",
			"get_main_loop трябва да връща копие")


func test_get_player_definition_by_id() -> void:
	var def := _mini_board()
	assert_true(def.has_player_definition(PlayerId.YELLOW))
	var yellow := def.get_player_definition(PlayerId.YELLOW)
	assert_true(yellow != null)
	assert_eq(yellow.spawn_cell, &"c_6_12")
	assert_true(def.get_player_definition(&"purple") == null)


func test_get_player_definitions_returns_all_seats() -> void:
	var def := _mini_board()
	var defs := def.get_player_definitions()
	assert_eq(defs.size(), 4)
	var ids: Dictionary = {}
	for p in defs:
		ids[p.player_id] = true
	for seat in PlayerId.ALL:
		assert_true(ids.has(seat), "липсва seat %s" % seat)


func test_get_active_player_definitions_filters_two_player_opposite() -> void:
	# Task #44: 2P ползва subset от SEAT_COUNT дефиниции.
	var def := _mini_board()
	var active := def.get_active_player_definitions(
			[PlayerId.GREEN, PlayerId.YELLOW])
	assert_eq(active.size(), 2)
	assert_eq(active[0].player_id, PlayerId.GREEN)
	assert_eq(active[1].player_id, PlayerId.YELLOW)
	assert_true(def.has_definitions_for_players(
			[PlayerId.ORANGE, PlayerId.CYAN]))
	assert_eq(def.player_definition_count(), BoardDefinition.SEAT_COUNT)


func test_get_active_player_definitions_filters_three_player_trio() -> void:
	# Task #45: 3P ползва кои да е три от SEAT_COUNT дефиниции.
	var def := _mini_board()
	var active := def.get_active_player_definitions(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW])
	assert_eq(active.size(), 3)
	assert_eq(active[0].player_id, PlayerId.GREEN)
	assert_eq(active[1].player_id, PlayerId.ORANGE)
	assert_eq(active[2].player_id, PlayerId.YELLOW)
	assert_true(def.has_definitions_for_players(
			[PlayerId.ORANGE, PlayerId.YELLOW, PlayerId.CYAN]))
	assert_eq(def.player_definition_count(), BoardDefinition.SEAT_COUNT)


# ── build_player_route ────────────────────────────────────────────────────────

func test_build_player_route_yellow_no_wrap() -> void:
	# YELLOW: start=0 → home_entry=3 по main_loop, после home_stretch.
	var def := _mini_board()
	var route := def.build_player_route(PlayerId.YELLOW)
	var expected: Array[StringName] = [
		&"c_6_12", &"c_6_11", &"c_6_10", &"c_7_12",
		&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_8",
	]
	assert_eq(route.size(), expected.size())
	for i in expected.size():
		assert_eq(route[i], expected[i], "route[%d]" % i)


func test_build_player_route_wraps_around_main_loop() -> void:
	# GREEN: start=1, home_entry=0 → 1,2,3,0 + home_stretch.
	var def := _mini_board()
	var route := def.build_player_route(PlayerId.GREEN)
	assert_eq(route[0], &"c_6_11")
	assert_eq(route[1], &"c_6_10")
	assert_eq(route[2], &"c_7_12")
	assert_eq(route[3], &"c_6_12")
	assert_eq(route[4], &"c_7_3")
	assert_eq(route.size(), 8)


func test_build_player_route_unknown_player_is_empty() -> void:
	var def := _mini_board()
	assert_eq(def.build_player_route(&"purple").size(), 0)


func test_build_player_route_out_of_range_index_is_empty() -> void:
	var def := _mini_board()
	var yellow := def.get_player_definition(PlayerId.YELLOW)
	yellow.home_entry_loop_index = 99
	assert_eq(def.build_player_route(PlayerId.YELLOW).size(), 0)


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_valid_mini_board() -> void:
	assert_true(_mini_board().is_valid())


func test_empty_board_id_invalid() -> void:
	var def := _mini_board()
	def.board_id = &""
	assert_false(def.is_valid())


func test_empty_cells_invalid() -> void:
	var def := _mini_board()
	def.cells.clear()
	assert_false(def.is_valid())


func test_empty_main_loop_invalid() -> void:
	var def := _mini_board()
	def.main_loop.clear()
	assert_false(def.is_valid())


func test_wrong_seat_count_invalid() -> void:
	var def := _mini_board()
	def.player_definitions.pop_back()
	assert_false(def.is_valid())


func test_duplicate_player_id_invalid() -> void:
	var def := _mini_board()
	var yellow := def.get_player_definition(PlayerId.YELLOW)
	var dup := yellow.duplicate_definition()
	def.player_definitions[1] = dup
	assert_false(def.is_valid())


func test_invalid_nested_cell_invalid() -> void:
	var def := _mini_board()
	var bad := CellDefinition.new()
	bad.cell_id = &"not_a_cell"
	bad.cell_type = CellType.PATH
	def.cells[&"not_a_cell"] = bad
	assert_false(def.is_valid())


func test_cell_key_mismatch_invalid() -> void:
	var def := _mini_board()
	var cell := CellDefinition.create_from_grid(1, 1, CellType.PATH)
	def.cells[&"c_2_2"] = cell
	assert_false(def.is_valid())


func test_duplicate_main_loop_cells_invalid() -> void:
	var def := _mini_board()
	def.set_main_loop([&"c_6_12", &"c_6_11", &"c_6_10", &"c_6_12"])
	assert_false(def.is_valid())


func test_invalid_main_loop_cell_id_invalid() -> void:
	var def := _mini_board()
	def.set_main_loop([&"c_6_12", &"bad", &"c_6_10", &"c_7_12"])
	assert_false(def.is_valid())


func test_invalid_nested_player_definition_invalid() -> void:
	var def := _mini_board()
	var yellow := def.get_player_definition(PlayerId.YELLOW)
	yellow.spawn_cell = &"not_a_cell"
	assert_false(def.is_valid())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_shape() -> void:
	var def := _mini_board()
	var d := def.to_dict()
	assert_eq(d["board_id"], "mini_test")
	assert_true(d["cells"] is Dictionary)
	assert_true(d["main_loop"] is Array)
	assert_true(d["player_definitions"] is Array)
	assert_eq((d["main_loop"] as Array).size(), 4)
	assert_eq((d["player_definitions"] as Array).size(), 4)
	assert_eq(typeof(d["board_id"]), TYPE_STRING)
	var cells: Dictionary = d["cells"]
	assert_true(cells.has("c_6_12"))
	assert_true(cells["c_6_12"] is Dictionary)


func test_from_dict_round_trip() -> void:
	var original := _mini_board()
	var restored := BoardDefinition.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_eq(restored.build_player_route(PlayerId.YELLOW),
			original.build_player_route(PlayerId.YELLOW))


func test_from_dict_empty_uses_defaults() -> void:
	var def := BoardDefinition.from_dict({})
	assert_eq(def.board_id, BoardDefinition.DEFAULT_BOARD_ID)
	assert_eq(def.cell_count(), 0)
	assert_eq(def.main_loop_length(), 0)
	assert_eq(def.player_definition_count(), 0)


func test_duplicate_definition_is_independent() -> void:
	var original := _mini_board()
	var copy := original.duplicate_definition()
	assert_true(original.equals(copy))
	copy.main_loop[0] = &"c_0_0"
	assert_eq(original.main_loop[0], &"c_6_12",
			"duplicate_definition не трябва да споделя main_loop")
	copy.get_cell(&"c_6_12").cell_type = CellType.PATH
	assert_eq(original.get_cell(&"c_6_12").cell_type, CellType.SPAWN,
			"duplicate_definition не трябва да споделя CellDefinition")
	assert_false(original.equals(copy))


func test_equals_null_is_false() -> void:
	assert_false(_mini_board().equals(null))


func test_equals_detects_field_difference() -> void:
	var a := _mini_board()
	var b := _mini_board()
	b.board_id = &"other"
	assert_false(a.equals(b))


func test_serves_two_three_four_players_via_seats() -> void:
	# Архитектура §4.6: една BoardDefinition обслужва 2/3/4 чрез активни seats.
	# Самата дъска винаги има 4 player_definitions; MatchConfig избира активните.
	var def := _mini_board()
	assert_eq(def.player_definition_count(), 4)
	for seat_count in [2, 3, 4]:
		var active: Array[StringName] = []
		for i in seat_count:
			active.append(PlayerId.ALL[i])
		for player_id in active:
			assert_true(def.has_player_definition(player_id))
			assert_true(def.build_player_route(player_id).size() > 0)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _expected_cell_count() -> int:
	# 4 main_loop + 4×4 home + 4×4 base + 1 center = 4+16+16+1 = 37
	return 37


## Миниатюрна валидна дъска с 4-клетъчен main_loop и четири seats.
## Не е classic_15x15 геометрия — само за unit тестове на модела.
func _mini_board() -> BoardDefinition:
	var loop: Array = [&"c_6_12", &"c_6_11", &"c_6_10", &"c_7_12"]
	var cells: Dictionary = {}
	cells[&"c_6_12"] = CellDefinition.create_from_grid(6, 12, CellType.SPAWN)
	cells[&"c_6_11"] = CellDefinition.create_from_grid(6, 11, CellType.PATH)
	cells[&"c_6_10"] = CellDefinition.create_from_grid(6, 10, CellType.PATH)
	cells[&"c_7_12"] = CellDefinition.create_from_grid(7, 12, CellType.PATH)
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
