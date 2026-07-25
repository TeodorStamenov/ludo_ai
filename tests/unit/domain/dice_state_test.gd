class_name DiceStateTest
extends TestCase
## Unit тестове за DiceState (Task #54 / docs/V1_ARCHITECTURE.md, §4.1).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath.
##   - Полета: value, player_id.
##   - Константи VALUE_NONE / 1–6 / EXTRA_TURN_VALUE / EXIT_BASE_VALUE.
##   - Фабрики create / create_none / create_roll.
##   - Helpers: has_result, is_six, grants_extra_turn, allows_exit_base.
##   - Mutators set_roll / clear.
##   - is_valid() инварианти.
##   - Сериализация to_dict / from_dict / equals / duplicate_state.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_dice_state_extends_ref_counted() -> void:
	var dice := DiceState.new()
	assert_true(dice is RefCounted,
			"DiceState трябва да extends RefCounted, не Node")


func test_dice_state_is_not_node() -> void:
	var dice: Object = DiceState.new()
	assert_false(dice is Node,
			"DiceState не трябва да extends Node — domain слой е без сцени")


func test_dice_state_script_path_is_in_domain_model() -> void:
	var dice := DiceState.new()
	var path: String = dice.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"DiceState трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var dice := DiceState.create_roll(PlayerId.YELLOW, 6)
	var d := dice.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DiceState")
	assert_false(d.has("global_position"), "global_position не е част от DiceState")
	assert_false(d.has("node_path"), "NodePath не е част от DiceState")
	assert_false(d.has("is_rolling"), "is_rolling е presentation (DiceView)")
	assert_false(d.has("texture"), "texture не е част от domain DiceState")
	assert_false(d.has("rotation"), "rotation не е част от domain DiceState")


# ── Константи и подразбирания ─────────────────────────────────────────────────

func test_value_bounds() -> void:
	assert_eq(DiceState.VALUE_NONE, 0)
	assert_eq(DiceState.VALUE_MIN, 1)
	assert_eq(DiceState.VALUE_MAX, 6)
	assert_eq(DiceState.EXTRA_TURN_VALUE, 6)
	assert_eq(DiceState.EXIT_BASE_VALUE, 6)


func test_is_face_value() -> void:
	assert_false(DiceState.is_face_value(0))
	assert_true(DiceState.is_face_value(1))
	assert_true(DiceState.is_face_value(6))
	assert_false(DiceState.is_face_value(7))
	assert_false(DiceState.is_face_value(-1))


func test_default_fields() -> void:
	var dice := DiceState.new()
	assert_eq(dice.value, DiceState.VALUE_NONE)
	assert_eq(dice.player_id, &"")
	assert_false(dice.has_result())
	assert_true(dice.is_valid(),
			"default VALUE_NONE без player_id трябва да е валидно")


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var dice := DiceState.create(4, PlayerId.GREEN)
	assert_eq(dice.value, 4)
	assert_eq(dice.player_id, PlayerId.GREEN)
	assert_true(dice.has_result())
	assert_true(dice.is_valid())


func test_create_none() -> void:
	var dice := DiceState.create_none()
	assert_eq(dice.value, DiceState.VALUE_NONE)
	assert_eq(dice.player_id, &"")
	assert_false(dice.has_result())
	assert_false(dice.is_six())
	assert_false(dice.grants_extra_turn())
	assert_false(dice.allows_exit_base())
	assert_true(dice.is_valid())


func test_create_roll() -> void:
	var dice := DiceState.create_roll(PlayerId.CYAN, 3)
	assert_eq(dice.value, 3)
	assert_eq(dice.player_id, PlayerId.CYAN)
	assert_true(dice.has_result())
	assert_true(dice.is_valid())


# ── Helpers (YEL-013 / YEL-030 / game design §3) ───────────────────────────────

func test_has_result_for_faces_1_to_6() -> void:
	for face in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
		var dice := DiceState.create_roll(PlayerId.ORANGE, face)
		assert_true(dice.has_result(),
				"face %d трябва да е has_result()" % face)


func test_six_grants_extra_turn_and_exit_base() -> void:
	var dice := DiceState.create_roll(PlayerId.YELLOW, 6)
	assert_true(dice.is_six())
	assert_true(dice.grants_extra_turn(),
			"зар 6 дава допълнително хвърляне")
	assert_true(dice.allows_exit_base(),
			"зар 6 позволява излизане от база")


func test_non_six_does_not_grant_extra_or_exit() -> void:
	for face in [1, 2, 3, 4, 5]:
		var dice := DiceState.create_roll(PlayerId.YELLOW, face)
		assert_false(dice.is_six())
		assert_false(dice.grants_extra_turn())
		assert_false(dice.allows_exit_base())


# ── Mutators ──────────────────────────────────────────────────────────────────

func test_set_roll_and_clear() -> void:
	var dice := DiceState.create_none()
	dice.set_roll(PlayerId.ORANGE, 5)
	assert_eq(dice.value, 5)
	assert_eq(dice.player_id, PlayerId.ORANGE)
	assert_true(dice.has_result())
	assert_true(dice.is_valid())

	dice.clear()
	assert_eq(dice.value, DiceState.VALUE_NONE)
	assert_eq(dice.player_id, &"")
	assert_false(dice.has_result())
	assert_true(dice.is_valid())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_out_of_range_value() -> void:
	var dice := DiceState.create(7, PlayerId.YELLOW)
	assert_false(dice.is_valid())
	dice.value = -1
	assert_false(dice.is_valid())


func test_is_valid_rejects_result_without_player() -> void:
	var dice := DiceState.create(3, &"")
	assert_false(dice.is_valid(),
			"стойност 1–6 без player_id не е валидна")


func test_is_valid_rejects_none_with_player() -> void:
	var dice := DiceState.create(DiceState.VALUE_NONE, PlayerId.YELLOW)
	assert_false(dice.is_valid(),
			"VALUE_NONE с player_id не е валидно")


func test_is_valid_rejects_unknown_player() -> void:
	var dice := DiceState.create(2, &"purple")
	assert_false(dice.is_valid())


func test_is_valid_accepts_all_player_ids_with_faces() -> void:
	for player_id in PlayerId.ALL:
		var dice := DiceState.create_roll(player_id, 1)
		assert_true(dice.is_valid(),
				"player_id %s + face 1 трябва да е валидно" % str(player_id))


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_keys_and_types() -> void:
	var dice := DiceState.create_roll(PlayerId.GREEN, 6)
	var d := dice.to_dict()
	assert_eq(d.size(), 2)
	assert_true(d.has("value"))
	assert_true(d.has("player_id"))
	assert_eq(d["value"], 6)
	assert_eq(typeof(d["player_id"]), TYPE_STRING,
			"player_id в to_dict трябва да е String, не StringName")
	assert_eq(d["player_id"], "green")


func test_from_dict_round_trip() -> void:
	var original := DiceState.create_roll(PlayerId.CYAN, 2)
	var restored := DiceState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_eq(restored.value, 2)
	assert_eq(restored.player_id, PlayerId.CYAN)
	assert_true(restored.is_valid())


func test_from_dict_defaults_for_missing_keys() -> void:
	var dice := DiceState.from_dict({})
	assert_eq(dice.value, DiceState.VALUE_NONE)
	assert_eq(dice.player_id, &"")
	assert_true(dice.is_valid())


func test_duplicate_state_is_independent() -> void:
	var dice := DiceState.create_roll(PlayerId.YELLOW, 4)
	var copy := dice.duplicate_state()
	assert_true(dice.equals(copy))
	copy.set_roll(PlayerId.GREEN, 6)
	assert_eq(dice.value, 4,
			"duplicate_state не трябва да споделя мутация")
	assert_eq(dice.player_id, PlayerId.YELLOW)


func test_equals() -> void:
	var a := DiceState.create_roll(PlayerId.ORANGE, 5)
	var b := DiceState.create_roll(PlayerId.ORANGE, 5)
	var c := DiceState.create_roll(PlayerId.ORANGE, 1)
	var d := DiceState.create_roll(PlayerId.YELLOW, 5)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(null))
	assert_true(DiceState.create_none().equals(DiceState.create_none()))
