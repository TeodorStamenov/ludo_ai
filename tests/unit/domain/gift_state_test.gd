class_name GiftStateTest
extends TestCase
## Unit тестове за GiftState / GiftId (Task #55 / docs/V1_ARCHITECTURE.md, §4.1).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath.
##   - Полета: gift_id, cell_id (без power_up_id — съдържанието се тегли при collect).
##   - GiftId.generate / is_valid (префикс "g_").
##   - Фабрики create / create_on_cell.
##   - Helpers: is_on_cell, set_cell.
##   - is_valid() инварианти (вкл. отказ на CENTER).
##   - Сериализация to_dict / from_dict / equals / duplicate_state.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_gift_state_extends_ref_counted() -> void:
	var gift := GiftState.new()
	assert_true(gift is RefCounted,
			"GiftState трябва да extends RefCounted, не Node")


func test_gift_state_is_not_node() -> void:
	var gift: Object = GiftState.new()
	assert_false(gift is Node,
			"GiftState не трябва да extends Node — domain слой е без сцени")


func test_gift_state_script_path_is_in_domain_model() -> void:
	var gift := GiftState.new()
	var path: String = gift.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"GiftState трябва да е в game/domain/model/")


func test_gift_id_script_path_is_in_domain_ids() -> void:
	var path: String = GiftId.new().get_script().resource_path
	assert_true(path.contains("game/domain/ids/"),
			"GiftId трябва да е в game/domain/ids/")


func test_to_dict_has_no_presentation_or_content_fields() -> void:
	var gift := GiftState.create(&"g_1_0", &"c_6_8")
	var d := gift.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от GiftState")
	assert_false(d.has("global_position"), "global_position не е част от GiftState")
	assert_false(d.has("node_path"), "NodePath не е част от GiftState")
	assert_false(d.has("texture"), "texture не е част от domain GiftState")
	assert_false(d.has("power_up_id"),
			"power_up_id се тегли при collect, не се пази в GiftState")
	assert_false(d.has("contents"), "съдържанието е скрито до GiftCollected")
	assert_false(d.has("revealed"), "revealed не е domain поле на GiftState")


# ── GiftId ────────────────────────────────────────────────────────────────────

func test_gift_id_prefix_constant() -> void:
	assert_eq(GiftId.PREFIX, "g_")


func test_gift_id_generate_returns_unique_valid_ids() -> void:
	GiftId._reset_counter_for_tests()
	var seen: Array[StringName] = []
	for _i in 8:
		var id := GiftId.generate()
		assert_true(id is StringName)
		assert_true(GiftId.is_valid(id),
				"generate() трябва да върне валиден gift_id: %s" % id)
		assert_true((id as String).begins_with(GiftId.PREFIX))
		assert_false(id in seen, "дублиран gift_id: %s" % id)
		seen.append(id)


func test_gift_id_is_valid_accepts_and_rejects() -> void:
	assert_true(GiftId.is_valid(&"g_0_0"))
	assert_true(GiftId.is_valid(&"g_1721915400000_3"))
	assert_false(GiftId.is_valid(&""))
	assert_false(GiftId.is_valid(&"m_1_0"), "match_id не е gift_id")
	assert_false(GiftId.is_valid(&"yellow_0"), "pawn_id не е gift_id")
	assert_false(GiftId.is_valid(&"c_6_8"), "cell_id не е gift_id")
	assert_false(GiftId.is_valid(&"gift_1"), "gift_ не е g_ префикс")


# ── Стойности по подразбиране ─────────────────────────────────────────────────

func test_default_fields_are_empty_and_invalid() -> void:
	var gift := GiftState.new()
	assert_eq(gift.gift_id, &"")
	assert_eq(gift.cell_id, &"")
	assert_false(gift.is_valid(),
			"празен gift_id/cell_id → is_valid() == false")


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var gift := GiftState.create(&"g_10_2", &"c_6_8")
	assert_eq(gift.gift_id, &"g_10_2")
	assert_eq(gift.cell_id, &"c_6_8")
	assert_true(gift.is_valid())


func test_create_on_cell_generates_gift_id() -> void:
	GiftId._reset_counter_for_tests()
	var gift := GiftState.create_on_cell(&"c_8_6")
	assert_true(GiftId.is_valid(gift.gift_id))
	assert_eq(gift.cell_id, &"c_8_6")
	assert_true(gift.is_valid())


func test_create_on_main_loop_spawn_cell_is_valid() -> void:
	# YELLOW spawn е част от main_loop (PATH/SPAWN) — допустима клетка за gift.
	var gift := GiftState.create(&"g_1_0", &"c_6_12")
	assert_true(gift.is_valid())
	assert_true(Classic15x15Board.is_main_loop_cell(gift.cell_id),
			"тестовата клетка трябва да е на общото трасе")


# ── Helpers ───────────────────────────────────────────────────────────────────

func test_is_on_cell() -> void:
	var gift := GiftState.create(&"g_1_0", &"c_6_8")
	assert_true(gift.is_on_cell(&"c_6_8"))
	assert_false(gift.is_on_cell(&"c_6_9"))


func test_set_cell() -> void:
	var gift := GiftState.create(&"g_1_0", &"c_6_8")
	gift.set_cell(&"c_7_6")
	assert_eq(gift.cell_id, &"c_7_6")
	assert_true(gift.is_on_cell(&"c_7_6"))
	assert_true(gift.is_valid())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_invalid_gift_id() -> void:
	var gift := GiftState.create(&"not_a_gift", &"c_6_8")
	assert_false(gift.is_valid())


func test_is_valid_rejects_invalid_cell_id() -> void:
	var gift := GiftState.create(&"g_1_0", &"not_a_cell")
	assert_false(gift.is_valid())


func test_is_valid_rejects_center_cell() -> void:
	var gift := GiftState.create(&"g_1_0", CellId.CENTER)
	assert_false(gift.is_valid(),
			"подарък никога не се появява в центъра (V1_GAME_DESIGN §4.1)")


func test_is_valid_accepts_path_cells() -> void:
	var cases: Array[StringName] = [&"c_6_8", &"c_8_2", &"c_12_8", &"c_2_6"]
	for cell in cases:
		var gift := GiftState.create(&"g_1_0", cell)
		assert_true(gift.is_valid(),
				"cell %s трябва да минава self-contained is_valid()" % cell)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_keys_and_types() -> void:
	var gift := GiftState.create(&"g_99_1", &"c_6_8")
	var d := gift.to_dict()
	assert_eq(d.size(), 2)
	assert_true(d.has("gift_id"))
	assert_true(d.has("cell_id"))
	assert_eq(typeof(d["gift_id"]), TYPE_STRING,
			"gift_id в to_dict трябва да е String, не StringName")
	assert_eq(typeof(d["cell_id"]), TYPE_STRING,
			"cell_id в to_dict трябва да е String, не StringName")
	assert_eq(d["gift_id"], "g_99_1")
	assert_eq(d["cell_id"], "c_6_8")


func test_from_dict_round_trip() -> void:
	var original := GiftState.create(&"g_5_7", &"c_8_6")
	var restored := GiftState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_eq(restored.gift_id, &"g_5_7")
	assert_eq(restored.cell_id, &"c_8_6")
	assert_true(restored.is_valid())


func test_from_dict_defaults_for_missing_keys() -> void:
	var gift := GiftState.from_dict({})
	assert_eq(gift.gift_id, &"")
	assert_eq(gift.cell_id, &"")
	assert_false(gift.is_valid())


func test_duplicate_state_is_independent() -> void:
	var gift := GiftState.create(&"g_1_0", &"c_6_8")
	var copy := gift.duplicate_state()
	assert_true(gift.equals(copy))
	copy.set_cell(&"c_6_9")
	assert_eq(gift.cell_id, &"c_6_8",
			"duplicate_state не трябва да споделя мутация")
	assert_false(gift.equals(copy))


func test_equals() -> void:
	var a := GiftState.create(&"g_1_0", &"c_6_8")
	var b := GiftState.create(&"g_1_0", &"c_6_8")
	var c := GiftState.create(&"g_1_0", &"c_6_9")
	var d := GiftState.create(&"g_2_0", &"c_6_8")
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(null))
