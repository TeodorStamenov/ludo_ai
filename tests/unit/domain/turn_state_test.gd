class_name TurnStateTest
extends TestCase
## Unit тестове за TurnState (Task #53 / docs/V1_ARCHITECTURE.md, §4.2).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath.
##   - Полета: phase, dice_value, base_attempts_remaining, extra_roll_pending,
##     valid_command_kinds[], valid_pawn_ids[], turn_number.
##   - Фабрики create / create_match_start / create_for_player_turn (YEL-003/004).
##   - Phase / dice / attempt / legal-action helpers и mutators.
##   - is_valid() инварианти.
##   - Сериализация to_dict / from_dict / equals / duplicate_state.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_turn_state_extends_ref_counted() -> void:
	var turn := TurnState.new()
	assert_true(turn is RefCounted,
			"TurnState трябва да extends RefCounted, не Node")


func test_turn_state_is_not_node() -> void:
	var turn: Object = TurnState.new()
	assert_false(turn is Node,
			"TurnState не трябва да extends Node — domain слой е без сцени")


func test_turn_state_script_path_is_in_domain_model() -> void:
	var turn := TurnState.new()
	var path: String = turn.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"TurnState трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	var d := turn.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от TurnState")
	assert_false(d.has("global_position"), "global_position не е част от TurnState")
	assert_false(d.has("node_path"), "NodePath не е част от TurnState")
	assert_false(d.has("_awaiting_pawn_choice"),
			"прототипните boolean флагове не са част от TurnState")
	assert_false(d.has("_roll_allowed"),
			"прототипните boolean флагове не са част от TurnState")
	assert_false(d.has("texture"), "texture не е част от domain TurnState")


# ── Константи и подразбирания ─────────────────────────────────────────────────

func test_base_roll_attempts_is_three() -> void:
	assert_eq(TurnState.BASE_ROLL_ATTEMPTS, 3,
			"BASE_ROLL_ATTEMPTS трябва да е 3 (YEL-003)")


func test_single_roll_attempts_is_one() -> void:
	assert_eq(TurnState.SINGLE_ROLL_ATTEMPTS, 1,
			"SINGLE_ROLL_ATTEMPTS трябва да е 1 (YEL-004)")


func test_dice_bounds() -> void:
	assert_eq(TurnState.DICE_NONE, 0)
	assert_eq(TurnState.DICE_MIN, 1)
	assert_eq(TurnState.DICE_MAX, 6)


func test_command_kind_constants() -> void:
	assert_eq(TurnState.COMMAND_ROLL_DICE, &"roll_dice")
	assert_eq(TurnState.COMMAND_MOVE_PAWN, &"move_pawn")
	assert_eq(TurnState.ALL_COMMAND_KINDS.size(), 2)
	assert_true(TurnState.is_known_command_kind(TurnState.COMMAND_ROLL_DICE))
	assert_true(TurnState.is_known_command_kind(TurnState.COMMAND_MOVE_PAWN))
	assert_false(TurnState.is_known_command_kind(&"teleport"))


func test_default_fields() -> void:
	var turn := TurnState.new()
	assert_eq(turn.phase, TurnPhase.MATCH_START)
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_eq(turn.base_attempts_remaining, 0)
	assert_false(turn.extra_roll_pending)
	assert_eq(turn.valid_command_kinds.size(), 0)
	assert_eq(turn.valid_pawn_ids.size(), 0)
	assert_eq(turn.turn_number, 0)
	assert_true(turn.is_valid(),
			"default MATCH_START състояние трябва да е валидно")


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var turn := TurnState.create(
			TurnPhase.AWAITING_MOVE,
			6,
			2,
			true,
			[TurnState.COMMAND_MOVE_PAWN],
			[&"yellow_0", &"yellow_1"],
			4)
	assert_eq(turn.phase, TurnPhase.AWAITING_MOVE)
	assert_eq(turn.dice_value, 6)
	assert_eq(turn.base_attempts_remaining, 2)
	assert_true(turn.extra_roll_pending)
	assert_eq(turn.valid_command_kinds.size(), 1)
	assert_eq(turn.valid_command_kinds[0], TurnState.COMMAND_MOVE_PAWN)
	assert_eq(turn.valid_pawn_ids.size(), 2)
	assert_eq(turn.valid_pawn_ids[0], &"yellow_0")
	assert_eq(turn.turn_number, 4)
	assert_true(turn.is_valid())


func test_create_match_start() -> void:
	var turn := TurnState.create_match_start()
	assert_true(turn.is_match_start())
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_eq(turn.base_attempts_remaining, 0)
	assert_false(turn.extra_roll_pending)
	assert_eq(turn.valid_command_kinds.size(), 0)
	assert_eq(turn.valid_pawn_ids.size(), 0)
	assert_eq(turn.turn_number, 0)
	assert_false(turn.accepts_command())
	assert_true(turn.is_valid())


func test_create_for_player_turn_all_in_base_yel_003() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.turn_number, 1)
	assert_eq(turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_false(turn.extra_roll_pending)
	assert_true(turn.allows_roll_dice())
	assert_eq(turn.valid_pawn_ids.size(), 0)
	assert_true(turn.is_valid())


func test_create_for_player_turn_pawn_on_board_yel_004() -> void:
	var turn := TurnState.create_for_player_turn(2, false)
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.turn_number, 2)
	assert_eq(turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_true(turn.allows_roll_dice())
	assert_true(turn.is_valid())


# ── Phase helpers ─────────────────────────────────────────────────────────────

func test_phase_helpers() -> void:
	var turn := TurnState.create_match_start()
	assert_true(turn.is_match_start())
	assert_eq(turn.phase_name(), &"MATCH_START")

	turn.phase = TurnPhase.AWAITING_ROLL
	assert_true(turn.is_awaiting_roll())
	assert_true(turn.accepts_command())

	turn.phase = TurnPhase.AWAITING_MOVE
	assert_true(turn.is_awaiting_move())
	assert_true(turn.accepts_command())

	turn.phase = TurnPhase.RESOLVING_MOVE
	assert_true(turn.is_resolving_move())
	assert_false(turn.accepts_command())

	turn.phase = TurnPhase.RESOLVING_POWER_UP
	assert_true(turn.is_resolving_power_up())

	turn.phase = TurnPhase.TURN_END
	assert_true(turn.is_turn_end())

	turn.phase = TurnPhase.MATCH_FINISHED
	assert_true(turn.is_match_finished())
	assert_false(turn.accepts_command())


# ── Dice / attempts / extra roll ──────────────────────────────────────────────

func test_has_dice_result() -> void:
	var turn := TurnState.create_match_start()
	assert_false(turn.has_dice_result())
	turn.set_dice_value(4)
	assert_true(turn.has_dice_result())
	turn.clear_dice()
	assert_false(turn.has_dice_result())


func test_consume_base_attempt_yel_010() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	assert_eq(turn.base_attempts_remaining, 3)
	assert_eq(turn.consume_base_attempt(), 2)
	assert_eq(turn.consume_base_attempt(), 1)
	assert_eq(turn.consume_base_attempt(), 0)
	assert_false(turn.has_base_attempts_remaining())
	assert_eq(turn.consume_base_attempt(), 0,
			"consume под 0 не трябва да намалява отрицателно")


func test_extra_roll_grant_and_consume() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	assert_false(turn.has_extra_roll_pending())
	turn.grant_extra_roll()
	assert_true(turn.has_extra_roll_pending())
	assert_true(turn.consume_extra_roll())
	assert_false(turn.has_extra_roll_pending())
	assert_false(turn.consume_extra_roll(),
			"повторно consume без pending → false")
	turn.grant_extra_roll()
	turn.clear_extra_roll()
	assert_false(turn.has_extra_roll_pending())


# ── Valid actions ─────────────────────────────────────────────────────────────

func test_has_command_kind_and_valid_pawn() -> void:
	var turn := TurnState.create(
			TurnPhase.AWAITING_MOVE,
			6,
			1,
			true,
			[TurnState.COMMAND_MOVE_PAWN],
			[&"yellow_0", &"green_2"],
			3)
	assert_true(turn.has_command_kind(TurnState.COMMAND_MOVE_PAWN))
	assert_false(turn.has_command_kind(TurnState.COMMAND_ROLL_DICE))
	assert_true(turn.has_valid_pawn(&"yellow_0"))
	assert_true(turn.has_valid_pawn(&"green_2"))
	assert_false(turn.has_valid_pawn(&"yellow_3"))
	assert_true(turn.allows_move_pawn())
	assert_false(turn.allows_roll_dice())


func test_set_and_clear_valid_actions() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	turn.set_valid_command_kinds([TurnState.COMMAND_ROLL_DICE])
	turn.set_valid_pawn_ids([&"yellow_0"])
	assert_eq(turn.valid_pawn_ids.size(), 1)
	turn.clear_valid_actions()
	assert_eq(turn.valid_command_kinds.size(), 0)
	assert_eq(turn.valid_pawn_ids.size(), 0)


func test_create_copies_arrays() -> void:
	var kinds: Array = [TurnState.COMMAND_MOVE_PAWN]
	var pawns: Array = [&"yellow_0"]
	var turn := TurnState.create(
			TurnPhase.AWAITING_MOVE, 5, 1, false, kinds, pawns, 1)
	kinds.clear()
	pawns.clear()
	assert_eq(turn.valid_command_kinds.size(), 1,
			"create трябва да копира valid_command_kinds")
	assert_eq(turn.valid_pawn_ids.size(), 1,
			"create трябва да копира valid_pawn_ids")


# ── Mutators / phase transitions ──────────────────────────────────────────────

func test_begin_player_turn_resets_roll_state() -> void:
	var turn := TurnState.create(
			TurnPhase.TURN_END, 6, 0, true,
			[TurnState.COMMAND_MOVE_PAWN], [&"yellow_0"], 5)
	turn.begin_player_turn(6, true)
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.turn_number, 6)
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_false(turn.extra_roll_pending)
	assert_eq(turn.base_attempts_remaining, 3)
	assert_eq(turn.valid_pawn_ids.size(), 0)
	assert_true(turn.allows_roll_dice())


func test_enter_awaiting_move() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	turn.enter_awaiting_move(6, [&"yellow_0", &"yellow_1"])
	assert_true(turn.is_awaiting_move())
	assert_eq(turn.dice_value, 6)
	assert_true(turn.allows_move_pawn())
	assert_eq(turn.valid_pawn_ids.size(), 2)
	assert_false(turn.allows_roll_dice())


func test_enter_extra_roll() -> void:
	var turn := TurnState.create(
			TurnPhase.TURN_END, 6, 0, true, [], [], 3)
	turn.enter_extra_roll()
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_false(turn.extra_roll_pending)
	assert_eq(turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_eq(turn.turn_number, 3,
			"допълнителното хвърляне запазва turn_number")
	assert_true(turn.allows_roll_dice())


func test_enter_resolving_and_turn_end_clear_actions() -> void:
	var turn := TurnState.create(
			TurnPhase.AWAITING_MOVE, 3, 1, false,
			[TurnState.COMMAND_MOVE_PAWN], [&"yellow_0"], 2)
	turn.enter_resolving_move()
	assert_true(turn.is_resolving_move())
	assert_eq(turn.valid_command_kinds.size(), 0)
	assert_eq(turn.valid_pawn_ids.size(), 0)

	turn.set_valid_command_kinds([TurnState.COMMAND_MOVE_PAWN])
	turn.enter_resolving_power_up()
	assert_true(turn.is_resolving_power_up())
	assert_eq(turn.valid_command_kinds.size(), 0)

	turn.set_valid_pawn_ids([&"yellow_0"])
	turn.enter_turn_end()
	assert_true(turn.is_turn_end())
	assert_eq(turn.valid_pawn_ids.size(), 0)


func test_enter_match_finished() -> void:
	var turn := TurnState.create(
			TurnPhase.TURN_END, 6, 2, true,
			[TurnState.COMMAND_ROLL_DICE], [&"yellow_0"], 10)
	turn.enter_match_finished()
	assert_true(turn.is_match_finished())
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_false(turn.extra_roll_pending)
	assert_eq(turn.base_attempts_remaining, 0)
	assert_eq(turn.valid_command_kinds.size(), 0)
	assert_eq(turn.valid_pawn_ids.size(), 0)
	assert_eq(turn.turn_number, 10)
	assert_true(turn.is_valid())


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_rejects_invalid_phase() -> void:
	var turn := TurnState.create_match_start()
	turn.phase = 99
	assert_false(turn.is_valid())


func test_is_valid_rejects_invalid_dice() -> void:
	var turn := TurnState.create_match_start()
	turn.dice_value = 7
	assert_false(turn.is_valid())
	turn.dice_value = -1
	assert_false(turn.is_valid())


func test_is_valid_rejects_negative_or_too_high_attempts() -> void:
	var turn := TurnState.create_match_start()
	turn.base_attempts_remaining = -1
	assert_false(turn.is_valid())
	turn.base_attempts_remaining = 4
	assert_false(turn.is_valid())


func test_is_valid_rejects_negative_turn_number() -> void:
	var turn := TurnState.create_match_start()
	turn.turn_number = -1
	assert_false(turn.is_valid())


func test_is_valid_rejects_unknown_command_kind() -> void:
	var turn := TurnState.create_match_start()
	turn.valid_command_kinds = [&"hack"]
	assert_false(turn.is_valid())


func test_is_valid_rejects_duplicate_command_kind() -> void:
	var turn := TurnState.create_match_start()
	turn.valid_command_kinds = [
		TurnState.COMMAND_ROLL_DICE, TurnState.COMMAND_ROLL_DICE,
	]
	assert_false(turn.is_valid())


func test_is_valid_rejects_invalid_pawn_id() -> void:
	var turn := TurnState.create_match_start()
	turn.valid_pawn_ids = [&"not_a_pawn"]
	assert_false(turn.is_valid())


func test_is_valid_rejects_duplicate_pawn_id() -> void:
	var turn := TurnState.create_match_start()
	turn.valid_pawn_ids = [&"yellow_0", &"yellow_0"]
	assert_false(turn.is_valid())


func test_is_valid_accepts_all_dice_faces() -> void:
	for value in range(TurnState.DICE_MIN, TurnState.DICE_MAX + 1):
		var turn := TurnState.create(
				TurnPhase.AWAITING_MOVE, value, 1, false,
				[TurnState.COMMAND_MOVE_PAWN], [&"yellow_0"], 1)
		assert_true(turn.is_valid(),
				"dice_value %d трябва да е валиден" % value)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_keys_and_types() -> void:
	var turn := TurnState.create(
			TurnPhase.AWAITING_MOVE, 6, 2, true,
			[TurnState.COMMAND_MOVE_PAWN], [&"yellow_0"], 7)
	var d := turn.to_dict()
	assert_eq(d["phase"], TurnPhase.AWAITING_MOVE)
	assert_eq(d["dice_value"], 6)
	assert_eq(d["base_attempts_remaining"], 2)
	assert_eq(d["extra_roll_pending"], true)
	assert_eq(d["turn_number"], 7)
	assert_true(d["valid_command_kinds"] is Array)
	assert_eq(d["valid_command_kinds"][0], "move_pawn")
	assert_eq(d["valid_pawn_ids"][0], "yellow_0")


func test_from_dict_round_trip() -> void:
	var original := TurnState.create(
			TurnPhase.AWAITING_ROLL, 0, 3, false,
			[TurnState.COMMAND_ROLL_DICE], [], 1)
	var restored := TurnState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_true(restored.allows_roll_dice())


func test_from_dict_missing_fields_use_defaults() -> void:
	var turn := TurnState.from_dict({})
	assert_eq(turn.phase, TurnPhase.MATCH_START)
	assert_eq(turn.dice_value, TurnState.DICE_NONE)
	assert_eq(turn.base_attempts_remaining, 0)
	assert_false(turn.extra_roll_pending)
	assert_eq(turn.turn_number, 0)
	assert_eq(turn.valid_command_kinds.size(), 0)
	assert_eq(turn.valid_pawn_ids.size(), 0)


func test_duplicate_state_is_independent() -> void:
	var original := TurnState.create(
			TurnPhase.AWAITING_MOVE, 5, 1, true,
			[TurnState.COMMAND_MOVE_PAWN], [&"cyan_1"], 4)
	var copy := original.duplicate_state()
	assert_true(original.equals(copy))
	copy.valid_pawn_ids.clear()
	copy.dice_value = 1
	assert_eq(original.valid_pawn_ids.size(), 1,
			"duplicate_state не трябва да споделя масиви")
	assert_eq(original.dice_value, 5)


func test_equals_false_for_null_and_diff() -> void:
	var a := TurnState.create_for_player_turn(1, true)
	var b := TurnState.create_for_player_turn(1, false)
	assert_false(a.equals(null))
	assert_false(a.equals(b))
	assert_true(a.equals(a.duplicate_state()))
