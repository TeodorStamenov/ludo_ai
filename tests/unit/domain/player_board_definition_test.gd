class_name PlayerBoardDefinitionTest
extends TestCase
## Unit тестове за PlayerBoardDefinition (Task #35 / docs/V1_ARCHITECTURE.md, §4.6).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без тема.
##   - Полета: player_id, spawn_cell, start/home_entry индекси, home_stretch, base_cells.
##   - Инварианти: HOME_STRETCH_LENGTH=4, BASE_CELL_COUNT=4 (game design §3.1–3.3).
##   - is_valid() self-contained проверки.
##   - Сериализация to_dict / from_dict / equals / duplicate_definition.
##   - Референтни yellow данни от CURRENT_YELLOW_BEHAVIOR / ludo_board.gd.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_player_board_definition_extends_ref_counted() -> void:
	var def := PlayerBoardDefinition.new()
	assert_true(def is RefCounted,
			"PlayerBoardDefinition трябва да extends RefCounted, не Node")


func test_player_board_definition_is_not_node() -> void:
	var def: Object = PlayerBoardDefinition.new()
	assert_false(def is Node,
			"PlayerBoardDefinition не трябва да extends Node — domain слой е без сцени")


func test_player_board_definition_script_path_is_in_domain_model() -> void:
	var def := PlayerBoardDefinition.new()
	var path: String = def.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"PlayerBoardDefinition трябва да е в game/domain/model/")


func test_to_dict_does_not_contain_theme_fields() -> void:
	var def := _yellow_definition()
	var d := def.to_dict()
	assert_false(d.has("theme_id"), "темата не е част от PlayerBoardDefinition")
	assert_false(d.has("texture"), "текстурата не е част от PlayerBoardDefinition")
	assert_false(d.has("color"), "цветът не е част от PlayerBoardDefinition")


# ── Константи и defaults ──────────────────────────────────────────────────────

func test_home_stretch_length_constant_is_four() -> void:
	assert_eq(PlayerBoardDefinition.HOME_STRETCH_LENGTH, 4,
			"Финалната зона трябва да е 4 клетки (V1_GAME_DESIGN §3.2)")


func test_base_cell_count_constant_is_four() -> void:
	assert_eq(PlayerBoardDefinition.BASE_CELL_COUNT, 4,
			"Всеки seat има 4 базови клетки / пионки (V1_GAME_DESIGN §3.1)")


func test_defaults_are_empty_or_invalid() -> void:
	var def := PlayerBoardDefinition.new()
	assert_eq(def.player_id, &"")
	assert_eq(def.spawn_cell, &"")
	assert_eq(def.start_loop_index, PlayerBoardDefinition.INVALID_LOOP_INDEX)
	assert_eq(def.home_entry_loop_index, PlayerBoardDefinition.INVALID_LOOP_INDEX)
	assert_eq(def.home_stretch.size(), 0)
	assert_eq(def.base_cells.size(), 0)
	assert_false(def.is_valid())


# ── Фабрика и helpers ─────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var def := _yellow_definition()
	assert_eq(def.player_id, PlayerId.YELLOW)
	assert_eq(def.spawn_cell, &"c_6_12")
	assert_eq(def.start_loop_index, 0)
	assert_eq(def.home_entry_loop_index, 40)
	assert_eq(def.home_stretch_length(), 4)
	assert_eq(def.base_cell_count(), 4)
	assert_true(def.is_valid())


func test_is_spawn_and_contains_helpers() -> void:
	var def := _yellow_definition()
	assert_true(def.is_spawn(&"c_6_12"))
	assert_false(def.is_spawn(&"c_7_12"))
	assert_true(def.contains_home_cell(&"c_7_11"))
	assert_true(def.contains_home_cell(&"c_7_8"))
	assert_false(def.contains_home_cell(&"c_6_12"))
	assert_true(def.contains_base_cell(&"c_11_11"))
	assert_false(def.contains_base_cell(&"c_7_11"))


func test_home_stretch_index_order() -> void:
	var def := _yellow_definition()
	assert_eq(def.home_stretch_index(&"c_7_11"), 0)
	assert_eq(def.home_stretch_index(&"c_7_10"), 1)
	assert_eq(def.home_stretch_index(&"c_7_9"), 2)
	assert_eq(def.home_stretch_index(&"c_7_8"), 3)
	assert_eq(def.home_stretch_index(&"c_0_0"), -1)


func test_get_home_stretch_and_base_cells_return_typed_copies() -> void:
	var def := _yellow_definition()
	var stretch := def.get_home_stretch()
	var bases := def.get_base_cells()
	assert_eq(stretch.size(), 4)
	assert_eq(bases.size(), 4)
	assert_eq(stretch[0], &"c_7_11")
	assert_eq(bases[0], &"c_11_11")
	stretch[0] = &"c_0_0"
	assert_eq(def.home_stretch[0], &"c_7_11",
			"get_home_stretch трябва да връща копие, не споделена референция")


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_valid_yellow_definition_from_prototype() -> void:
	var def := _yellow_definition()
	assert_true(def.is_valid(),
			"Yellow seat от ludo_board.gd / CURRENT_YELLOW_BEHAVIOR трябва да е валиден")


func test_invalid_player_id() -> void:
	var def := _yellow_definition()
	def.player_id = &"purple"
	assert_false(def.is_valid())


func test_invalid_spawn_cell() -> void:
	var def := _yellow_definition()
	def.spawn_cell = &"not_a_cell"
	assert_false(def.is_valid())


func test_negative_loop_indices_invalid() -> void:
	var def := _yellow_definition()
	def.start_loop_index = -1
	assert_false(def.is_valid())
	def = _yellow_definition()
	def.home_entry_loop_index = -1
	assert_false(def.is_valid())


func test_wrong_home_stretch_length_invalid() -> void:
	var def := _yellow_definition()
	def.set_home_stretch([&"c_7_11", &"c_7_10", &"c_7_9"])
	assert_false(def.is_valid())


func test_wrong_base_cell_count_invalid() -> void:
	var def := _yellow_definition()
	def.set_base_cells([&"c_11_11", &"c_12_11", &"c_11_12"])
	assert_false(def.is_valid())


func test_duplicate_home_stretch_cells_invalid() -> void:
	var def := _yellow_definition()
	def.set_home_stretch([&"c_7_11", &"c_7_10", &"c_7_9", &"c_7_11"])
	assert_false(def.is_valid())


func test_duplicate_base_cells_invalid() -> void:
	var def := _yellow_definition()
	def.set_base_cells([&"c_11_11", &"c_12_11", &"c_11_12", &"c_11_11"])
	assert_false(def.is_valid())


func test_invalid_cell_id_in_arrays() -> void:
	var def := _yellow_definition()
	def.set_home_stretch([&"c_7_11", &"bad", &"c_7_9", &"c_7_8"])
	assert_false(def.is_valid())


func test_spawn_in_home_stretch_invalid() -> void:
	var def := _yellow_definition()
	def.spawn_cell = &"c_7_11"
	assert_false(def.is_valid())


func test_spawn_in_base_cells_invalid() -> void:
	var def := _yellow_definition()
	def.spawn_cell = &"c_11_11"
	assert_false(def.is_valid())


func test_overlap_between_base_and_home_invalid() -> void:
	var def := _yellow_definition()
	def.set_base_cells([&"c_11_11", &"c_12_11", &"c_11_12", &"c_7_8"])
	assert_false(def.is_valid())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_shape() -> void:
	var def := _yellow_definition()
	var d := def.to_dict()
	assert_eq(d["player_id"], "yellow")
	assert_eq(d["spawn_cell"], "c_6_12")
	assert_eq(d["start_loop_index"], 0)
	assert_eq(d["home_entry_loop_index"], 40)
	assert_true(d["home_stretch"] is Array)
	assert_true(d["base_cells"] is Array)
	assert_eq((d["home_stretch"] as Array).size(), 4)
	assert_eq((d["base_cells"] as Array).size(), 4)
	assert_eq(typeof(d["player_id"]), TYPE_STRING,
			"StringName трябва да се сериализира като String")


func test_from_dict_round_trip() -> void:
	var original := _yellow_definition()
	var restored := PlayerBoardDefinition.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())


func test_from_dict_empty_uses_defaults() -> void:
	var def := PlayerBoardDefinition.from_dict({})
	assert_eq(def.player_id, &"")
	assert_eq(def.spawn_cell, &"")
	assert_eq(def.start_loop_index, PlayerBoardDefinition.INVALID_LOOP_INDEX)
	assert_eq(def.home_entry_loop_index, PlayerBoardDefinition.INVALID_LOOP_INDEX)
	assert_eq(def.home_stretch.size(), 0)
	assert_eq(def.base_cells.size(), 0)


func test_duplicate_definition_is_independent() -> void:
	var original := _yellow_definition()
	var copy := original.duplicate_definition()
	assert_true(original.equals(copy))
	copy.home_stretch[0] = &"c_0_0"
	assert_eq(original.home_stretch[0], &"c_7_11",
			"duplicate_definition не трябва да споделя масиви")
	assert_false(original.equals(copy))


func test_equals_null_is_false() -> void:
	var def := _yellow_definition()
	assert_false(def.equals(null))


func test_equals_detects_field_difference() -> void:
	var a := _yellow_definition()
	var b := _yellow_definition()
	b.start_loop_index = 1
	assert_false(a.equals(b))


func test_all_four_seats_can_be_represented() -> void:
	var samples: Array[PlayerBoardDefinition] = [
		_yellow_definition(),
		PlayerBoardDefinition.create(
				PlayerId.GREEN, &"c_8_2", 0, 10,
				[&"c_7_3", &"c_7_4", &"c_7_5", &"c_7_6"],
				[&"c_2_2", &"c_3_2", &"c_2_3", &"c_3_3"]),
		PlayerBoardDefinition.create(
				PlayerId.ORANGE, &"c_12_8", 0, 10,
				[&"c_11_7", &"c_10_7", &"c_9_7", &"c_8_7"],
				[&"c_11_2", &"c_12_2", &"c_11_3", &"c_12_3"]),
		PlayerBoardDefinition.create(
				PlayerId.CYAN, &"c_2_6", 0, 10,
				[&"c_3_7", &"c_4_7", &"c_5_7", &"c_6_7"],
				[&"c_2_11", &"c_3_11", &"c_2_12", &"c_3_12"]),
	]
	for def in samples:
		assert_true(PlayerId.is_valid(def.player_id))
		assert_true(def.is_valid(),
				"%s трябва да е валидна PlayerBoardDefinition" % def.player_id)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Yellow seat от прототипа (ludo_board.gd / CURRENT_YELLOW_BEHAVIOR.md).
## start_loop_index=0 и home_entry_loop_index=40 са placeholder индекси в main_loop
## (пълният main_loop идва с BoardDefinition — Task #36); self-contained валидността
## изисква само неотрицателни индекси.
func _yellow_definition() -> PlayerBoardDefinition:
	return PlayerBoardDefinition.create(
			PlayerId.YELLOW,
			CellId.from_grid(6, 12),
			0,
			40,
			[
				CellId.from_grid(7, 11),
				CellId.from_grid(7, 10),
				CellId.from_grid(7, 9),
				CellId.from_grid(7, 8),
			],
			[
				CellId.from_grid(11, 11),
				CellId.from_grid(12, 11),
				CellId.from_grid(11, 12),
				CellId.from_grid(12, 12),
			]
	)
