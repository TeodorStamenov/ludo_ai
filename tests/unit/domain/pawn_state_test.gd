class_name PawnStateTest
extends TestCase
## Unit тестове за PawnState (Task #51 / docs/V1_ARCHITECTURE.md, §4.1).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath.
##   - Полета: pawn_id, zone, path_index, cell_id, shield_turns_remaining.
##   - Фабрики create / create_in_base / create_at_spawn / create_finished.
##   - Zone helpers и shield helpers.
##   - is_valid() инварианти по зона.
##   - Сериализация to_dict / from_dict / equals / duplicate_state.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_state_extends_ref_counted() -> void:
	var pawn := PawnState.new()
	assert_true(pawn is RefCounted,
			"PawnState трябва да extends RefCounted, не Node")


func test_pawn_state_is_not_node() -> void:
	var pawn: Object = PawnState.new()
	assert_false(pawn is Node,
			"PawnState не трябва да extends Node — domain слой е без сцени")


func test_pawn_state_script_path_is_in_domain_model() -> void:
	var pawn := PawnState.new()
	var path: String = pawn.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"PawnState трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	var d := pawn.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от PawnState")
	assert_false(d.has("global_position"), "global_position не е част от PawnState")
	assert_false(d.has("node_path"), "NodePath не е част от PawnState")
	assert_false(d.has("in_base"), "in_base е derived от zone, не отделно поле")
	assert_false(d.has("texture"), "texture не е част от domain PawnState")


# ── Стойности по подразбиране ─────────────────────────────────────────────────

func test_default_zone_is_base() -> void:
	var pawn := PawnState.new()
	assert_eq(pawn.zone, PawnZone.BASE, "default zone трябва да е BASE")


func test_default_path_index_is_in_base() -> void:
	var pawn := PawnState.new()
	assert_eq(pawn.path_index, PawnState.PATH_INDEX_IN_BASE,
			"default path_index трябва да е PATH_INDEX_IN_BASE (-1)")


func test_default_pawn_id_and_cell_id_are_empty() -> void:
	var pawn := PawnState.new()
	assert_eq(pawn.pawn_id, &"")
	assert_eq(pawn.cell_id, &"")


func test_default_shield_is_zero() -> void:
	var pawn := PawnState.new()
	assert_eq(pawn.shield_turns_remaining, 0)
	assert_false(pawn.has_shield())


func test_default_state_is_not_valid() -> void:
	var pawn := PawnState.new()
	assert_false(pawn.is_valid(),
			"празен pawn_id/cell_id → is_valid() == false")


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var pawn := PawnState.create(
			&"yellow_1", PawnZone.MAIN_PATH, 4, &"c_6_8", 2)
	assert_eq(pawn.pawn_id, &"yellow_1")
	assert_eq(pawn.zone, PawnZone.MAIN_PATH)
	assert_eq(pawn.path_index, 4)
	assert_eq(pawn.cell_id, &"c_6_8")
	assert_eq(pawn.shield_turns_remaining, 2)
	assert_true(pawn.is_valid())


func test_create_in_base_matches_yel_001() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	assert_eq(pawn.zone, PawnZone.BASE)
	assert_eq(pawn.path_index, -1)
	assert_eq(pawn.cell_id, &"c_11_11")
	assert_eq(pawn.shield_turns_remaining, 0)
	assert_true(pawn.is_in_base())
	assert_true(pawn.is_valid())


func test_create_at_spawn_matches_yel_030() -> void:
	var pawn := PawnState.create_at_spawn(&"yellow_0", &"c_6_12")
	assert_eq(pawn.zone, PawnZone.MAIN_PATH)
	assert_eq(pawn.path_index, PawnState.PATH_INDEX_AT_SPAWN)
	assert_eq(pawn.cell_id, &"c_6_12")
	assert_true(pawn.is_on_main_path())
	assert_true(pawn.is_valid())


func test_create_finished_uses_center_cell() -> void:
	var pawn := PawnState.create_finished(&"green_2", Classic15x15Board.PLAYER_ROUTE_LENGTH)
	assert_eq(pawn.zone, PawnZone.FINISHED)
	assert_eq(pawn.cell_id, CellId.CENTER)
	assert_true(pawn.is_finished())
	assert_true(pawn.is_valid())


# ── Zone / board helpers ──────────────────────────────────────────────────────

func test_zone_helpers_are_mutually_exclusive() -> void:
	var pawn := PawnState.create_in_base(&"cyan_0", &"c_2_2")
	assert_true(pawn.is_in_base())
	assert_false(pawn.is_on_main_path())
	assert_false(pawn.is_in_home_stretch())
	assert_false(pawn.is_finished())
	assert_false(pawn.is_on_board())

	pawn.set_position(PawnZone.MAIN_PATH, 3, &"c_6_9")
	assert_false(pawn.is_in_base())
	assert_true(pawn.is_on_main_path())
	assert_true(pawn.is_on_board())

	pawn.set_position(PawnZone.HOME_STRETCH, 50, &"c_7_11")
	assert_true(pawn.is_in_home_stretch())
	assert_true(pawn.is_on_board())
	assert_false(pawn.is_on_main_path())

	pawn.mark_finished(56)
	assert_true(pawn.is_finished())
	assert_false(pawn.is_on_board())
	assert_false(pawn.is_in_base())


func test_get_player_id_and_pawn_index() -> void:
	var pawn := PawnState.create_in_base(&"orange_3", &"c_11_2")
	assert_eq(pawn.get_player_id(), &"orange")
	assert_eq(pawn.get_pawn_index(), 3)


# ── Shield ────────────────────────────────────────────────────────────────────

func test_apply_and_clear_shield() -> void:
	var pawn := PawnState.create_at_spawn(&"yellow_0", &"c_6_12")
	pawn.apply_shield(2)
	assert_true(pawn.has_shield())
	assert_eq(pawn.shield_turns_remaining, 2)
	pawn.clear_shield()
	assert_false(pawn.has_shield())
	assert_eq(pawn.shield_turns_remaining, 0)


func test_apply_shield_clamps_negative_to_zero() -> void:
	var pawn := PawnState.create_at_spawn(&"yellow_0", &"c_6_12")
	pawn.apply_shield(-3)
	assert_eq(pawn.shield_turns_remaining, 0)
	assert_false(pawn.has_shield())


func test_tick_shield_decrements_and_floors_at_zero() -> void:
	var pawn := PawnState.create_at_spawn(&"yellow_0", &"c_6_12")
	pawn.apply_shield(2)
	assert_eq(pawn.tick_shield(), 1)
	assert_eq(pawn.tick_shield(), 0)
	assert_eq(pawn.tick_shield(), 0)
	assert_false(pawn.has_shield())


func test_place_in_base_clears_shield() -> void:
	var pawn := PawnState.create(
			&"yellow_0", PawnZone.MAIN_PATH, 5, &"c_6_7", 3)
	pawn.place_in_base(&"c_11_11")
	assert_true(pawn.is_in_base())
	assert_eq(pawn.path_index, PawnState.PATH_INDEX_IN_BASE)
	assert_eq(pawn.shield_turns_remaining, 0)


func test_exit_base_to_spawn() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	pawn.exit_base_to_spawn(&"c_6_12")
	assert_eq(pawn.zone, PawnZone.MAIN_PATH)
	assert_eq(pawn.path_index, 0)
	assert_eq(pawn.cell_id, &"c_6_12")
	assert_true(pawn.is_valid())


func test_mark_finished_clears_shield_and_sets_center() -> void:
	var pawn := PawnState.create(
			&"yellow_0", PawnZone.HOME_STRETCH, 55, &"c_7_8", 1)
	pawn.mark_finished(56)
	assert_eq(pawn.zone, PawnZone.FINISHED)
	assert_eq(pawn.cell_id, CellId.CENTER)
	assert_eq(pawn.shield_turns_remaining, 0)
	assert_true(pawn.is_valid())


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_rejects_invalid_pawn_id() -> void:
	var pawn := PawnState.create_in_base(&"purple_0", &"c_11_11")
	assert_false(pawn.is_valid())


func test_is_valid_rejects_invalid_zone() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	pawn.zone = 99
	assert_false(pawn.is_valid())


func test_is_valid_rejects_negative_shield() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	pawn.shield_turns_remaining = -1
	assert_false(pawn.is_valid())


func test_is_valid_rejects_invalid_cell_id() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"not_a_cell")
	assert_false(pawn.is_valid())


func test_is_valid_base_requires_path_index_minus_one() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	pawn.path_index = 0
	assert_false(pawn.is_valid(),
			"BASE с path_index != -1 е невалиден")


func test_is_valid_main_path_rejects_negative_path_index() -> void:
	var pawn := PawnState.create(
			&"yellow_0", PawnZone.MAIN_PATH, -1, &"c_6_12")
	assert_false(pawn.is_valid())


func test_is_valid_home_stretch_accepts_non_negative_path_index() -> void:
	var pawn := PawnState.create(
			&"yellow_0", PawnZone.HOME_STRETCH, 52, &"c_7_11")
	assert_true(pawn.is_valid())
	assert_true(pawn.is_in_home_stretch())


func test_is_valid_finished_requires_center_cell() -> void:
	var pawn := PawnState.create(
			&"yellow_0", PawnZone.FINISHED, 56, &"c_7_8")
	assert_false(pawn.is_valid(),
			"FINISHED трябва да е на CellId.CENTER")
	pawn.cell_id = CellId.CENTER
	assert_true(pawn.is_valid())


func test_is_valid_accepts_all_zones_with_consistent_fields() -> void:
	var cases: Array = [
		PawnState.create_in_base(&"green_0", &"c_2_2"),
		PawnState.create_at_spawn(&"green_1", &"c_8_2"),
		PawnState.create(&"green_2", PawnZone.HOME_STRETCH, 53, &"c_7_3"),
		PawnState.create_finished(&"green_3", 56),
	]
	for pawn: PawnState in cases:
		assert_true(pawn.is_valid(),
				"очаква се валиден PawnState в зона %s" % PawnZone.zone_name(pawn.zone))


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_contains_expected_keys_and_types() -> void:
	var pawn := PawnState.create(
			&"cyan_1", PawnZone.MAIN_PATH, 10, &"c_8_6", 1)
	var d := pawn.to_dict()
	assert_eq(d["pawn_id"], "cyan_1")
	assert_eq(d["zone"], PawnZone.MAIN_PATH)
	assert_eq(d["path_index"], 10)
	assert_eq(d["cell_id"], "c_8_6")
	assert_eq(d["shield_turns_remaining"], 1)
	assert_true(d["pawn_id"] is String, "pawn_id сериализира като String")
	assert_true(d["cell_id"] is String, "cell_id сериализира като String")


func test_from_dict_round_trip() -> void:
	var original := PawnState.create(
			&"orange_2", PawnZone.HOME_STRETCH, 54, &"c_8_7", 2)
	var restored := PawnState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_eq(restored.pawn_id, &"orange_2")
	assert_eq(restored.zone, PawnZone.HOME_STRETCH)


func test_from_dict_missing_fields_use_defaults() -> void:
	var pawn := PawnState.from_dict({})
	assert_eq(pawn.pawn_id, &"")
	assert_eq(pawn.zone, PawnZone.BASE)
	assert_eq(pawn.path_index, PawnState.PATH_INDEX_IN_BASE)
	assert_eq(pawn.cell_id, &"")
	assert_eq(pawn.shield_turns_remaining, 0)


func test_duplicate_state_is_independent_copy() -> void:
	var original := PawnState.create_at_spawn(&"yellow_0", &"c_6_12")
	var copy := original.duplicate_state()
	assert_true(original.equals(copy))
	copy.path_index = 5
	copy.cell_id = &"c_6_7"
	assert_false(original.equals(copy))
	assert_eq(original.path_index, 0)
	assert_eq(original.cell_id, &"c_6_12")


func test_equals_null_is_false() -> void:
	var pawn := PawnState.create_in_base(&"yellow_0", &"c_11_11")
	assert_false(pawn.equals(null))


func test_equals_detects_field_differences() -> void:
	var a := PawnState.create_at_spawn(&"yellow_0", &"c_6_12")
	var b := a.duplicate_state()
	assert_true(a.equals(b))
	b.shield_turns_remaining = 1
	assert_false(a.equals(b))
