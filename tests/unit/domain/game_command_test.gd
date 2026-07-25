class_name GameCommandTest
extends TestCase
## Unit тестове за базовия GameCommand (Task #64 / docs/V1_ARCHITECTURE.md, §4.3 / §11).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/commands/, без Vector2/NodePath.
##   - Envelope: match_id, player_id, sequence, auth_token, command_type.
##   - Константи TYPE_* / SEQUENCE_UNSET.
##   - Фабрика create, stamp / is_stamped.
##   - is_valid() инварианти.
##   - Сериализация to_dict / from_dict / equals / duplicate_command.
##   - Подкласовете наследяват envelope полетата (без да носят резултат).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_game_command_extends_ref_counted() -> void:
	var cmd := GameCommand.new()
	assert_true(cmd is RefCounted,
			"GameCommand трябва да extends RefCounted, не Node")


func test_game_command_is_not_node() -> void:
	var cmd: Object = GameCommand.new()
	assert_false(cmd is Node,
			"GameCommand не трябва да extends Node — domain слой е без сцени")


func test_game_command_script_path_is_in_domain_commands() -> void:
	var cmd := GameCommand.new()
	var path: String = cmd.get_script().resource_path
	assert_true(path.contains("game/domain/commands/"),
			"GameCommand трябва да е в game/domain/commands/")


func test_to_dict_has_no_presentation_or_result_fields() -> void:
	var cmd := GameCommand.create(&"m_1_0", PlayerId.YELLOW, 1, GameCommand.TYPE_ROLL_DICE)
	var d := cmd.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от GameCommand")
	assert_false(d.has("global_position"), "global_position не е част от GameCommand")
	assert_false(d.has("node_path"), "NodePath не е част от GameCommand")
	assert_false(d.has("dice_value"), "командата не носи резултат от зара (§4.3)")
	assert_false(d.has("result"), "командата носи намерение, не резултат")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в GameCommand")
	assert_false(d.has("events"), "events са DomainEvent[], не част от командата")


# ── Константи и подразбирания ─────────────────────────────────────────────────

func test_sequence_unset_and_type_constants() -> void:
	assert_eq(GameCommand.SEQUENCE_UNSET, 0)
	assert_eq(GameCommand.TYPE_START_MATCH, &"StartMatch")
	assert_eq(GameCommand.TYPE_ROLL_DICE, &"RollDice")
	assert_eq(GameCommand.TYPE_MOVE_PAWN, &"MovePawn")


func test_default_fields() -> void:
	var cmd := GameCommand.new()
	assert_eq(cmd.match_id, &"")
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.auth_token, "")
	assert_eq(cmd.command_type, &"")
	assert_false(cmd.is_stamped())
	assert_true(cmd.is_valid(),
			"празен envelope преди stamp трябва да е валиден (само намерение)")


# ── Фабрики и stamp ───────────────────────────────────────────────────────────

func test_create_sets_all_envelope_fields() -> void:
	var cmd := GameCommand.create(
			&"m_10_2", PlayerId.GREEN, 3, GameCommand.TYPE_MOVE_PAWN, "tok")
	assert_eq(cmd.match_id, &"m_10_2")
	assert_eq(cmd.player_id, PlayerId.GREEN)
	assert_eq(cmd.sequence, 3)
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_eq(cmd.auth_token, "tok")
	assert_true(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_stamp_sets_match_id_and_sequence() -> void:
	var cmd := GameCommand.create(&"", PlayerId.CYAN, 0, GameCommand.TYPE_ROLL_DICE)
	assert_false(cmd.is_stamped())
	cmd.stamp(&"m_99_0", 1)
	assert_eq(cmd.match_id, &"m_99_0")
	assert_eq(cmd.sequence, 1)
	assert_true(cmd.is_stamped())
	assert_eq(cmd.player_id, PlayerId.CYAN,
			"stamp не трябва да пипа player_id / command_type")
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE)


func test_is_stamped_requires_match_id_and_positive_sequence() -> void:
	var only_match := GameCommand.create(&"m_1_0", &"", 0)
	assert_false(only_match.is_stamped(), "sequence=0 → не е stamped")
	var only_seq := GameCommand.create(&"", &"", 1)
	assert_false(only_seq.is_stamped(), "празен match_id → не е stamped")
	var both := GameCommand.create(&"m_1_0", &"", 1)
	assert_true(both.is_stamped())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_negative_sequence() -> void:
	var cmd := GameCommand.create(&"m_1_0", PlayerId.YELLOW, -1)
	assert_false(cmd.is_valid())


func test_is_valid_rejects_malformed_match_id() -> void:
	var cmd := GameCommand.create(&"not_a_match", PlayerId.YELLOW, 1)
	assert_false(cmd.is_valid(),
			"match_id без префикс m_ не е валиден")


func test_is_valid_rejects_unknown_player_id() -> void:
	var cmd := GameCommand.create(&"m_1_0", &"purple", 1)
	assert_false(cmd.is_valid())


func test_is_valid_allows_empty_player_id() -> void:
	var cmd := GameCommand.create(&"m_1_0", &"", 1, GameCommand.TYPE_START_MATCH)
	assert_true(cmd.is_valid(),
			"StartMatch може да няма player_id")


func test_is_valid_accepts_all_player_ids() -> void:
	for player_id in PlayerId.ALL:
		var cmd := GameCommand.create(&"m_1_0", player_id, 1, GameCommand.TYPE_ROLL_DICE)
		assert_true(cmd.is_valid(),
				"player_id %s трябва да е валиден" % str(player_id))


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_keys_and_types() -> void:
	var cmd := GameCommand.create(
			&"m_5_1", PlayerId.ORANGE, 2, GameCommand.TYPE_ROLL_DICE, "")
	var d := cmd.to_dict()
	assert_eq(d.size(), 5)
	assert_true(d.has("match_id"))
	assert_true(d.has("player_id"))
	assert_true(d.has("sequence"))
	assert_true(d.has("auth_token"))
	assert_true(d.has("command_type"))
	assert_eq(typeof(d["match_id"]), TYPE_STRING,
			"match_id в to_dict трябва да е String, не StringName")
	assert_eq(typeof(d["player_id"]), TYPE_STRING)
	assert_eq(typeof(d["command_type"]), TYPE_STRING)
	assert_eq(d["match_id"], "m_5_1")
	assert_eq(d["player_id"], "orange")
	assert_eq(d["sequence"], 2)
	assert_eq(d["command_type"], "RollDice")
	assert_eq(d["auth_token"], "")


func test_from_dict_round_trip() -> void:
	var original := GameCommand.create(
			&"m_7_3", PlayerId.CYAN, 4, GameCommand.TYPE_MOVE_PAWN, "v2-token")
	var restored := GameCommand.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_eq(restored.match_id, &"m_7_3")
	assert_eq(restored.player_id, PlayerId.CYAN)
	assert_eq(restored.sequence, 4)
	assert_eq(restored.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_eq(restored.auth_token, "v2-token")
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var cmd := GameCommand.from_dict({})
	assert_eq(cmd.match_id, &"")
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.auth_token, "")
	assert_eq(cmd.command_type, &"")
	assert_true(cmd.is_valid())
	assert_false(cmd.is_stamped())


func test_duplicate_command_is_independent() -> void:
	var cmd := GameCommand.create(&"m_1_0", PlayerId.YELLOW, 1, GameCommand.TYPE_ROLL_DICE)
	var copy := cmd.duplicate_command()
	assert_true(cmd.equals(copy))
	copy.stamp(&"m_2_0", 9)
	copy.player_id = PlayerId.GREEN
	assert_eq(cmd.match_id, &"m_1_0",
			"duplicate_command не трябва да споделя мутация")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.player_id, PlayerId.YELLOW)


func test_equals() -> void:
	var a := GameCommand.create(&"m_1_0", PlayerId.GREEN, 1, GameCommand.TYPE_ROLL_DICE)
	var b := GameCommand.create(&"m_1_0", PlayerId.GREEN, 1, GameCommand.TYPE_ROLL_DICE)
	var c := GameCommand.create(&"m_1_0", PlayerId.GREEN, 2, GameCommand.TYPE_ROLL_DICE)
	var d := GameCommand.create(&"m_1_0", PlayerId.YELLOW, 1, GameCommand.TYPE_ROLL_DICE)
	var e := GameCommand.create(&"m_1_0", PlayerId.GREEN, 1, GameCommand.TYPE_MOVE_PAWN)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))


# ── Подкласове наследяват envelope ────────────────────────────────────────────

func test_roll_dice_command_is_game_command() -> void:
	var cmd := RollDiceCommand.new(PlayerId.YELLOW)
	assert_true(cmd is GameCommand)
	assert_eq(cmd.player_id, PlayerId.YELLOW)
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_false(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_move_pawn_command_is_game_command() -> void:
	var cmd := MovePawnCommand.new(PlayerId.GREEN, &"green_0")
	assert_true(cmd is GameCommand)
	assert_eq(cmd.player_id, PlayerId.GREEN)
	assert_true(cmd.is_valid())


func test_start_match_command_is_game_command() -> void:
	var cmd := StartMatchCommand.new(null)
	assert_true(cmd is GameCommand)
	assert_eq(cmd.player_id, &"")
	assert_true(cmd.is_valid(),
			"StartMatch без player_id трябва да е валиден envelope")


func test_subclass_stamp_uses_base_envelope() -> void:
	var cmd := RollDiceCommand.new(PlayerId.ORANGE)
	cmd.stamp(&"m_42_0", 5)
	assert_true(cmd.is_stamped())
	assert_eq(cmd.match_id, &"m_42_0")
	assert_eq(cmd.sequence, 5)
	assert_eq(cmd.player_id, PlayerId.ORANGE)
	assert_true(cmd.is_valid())


func test_command_does_not_carry_dice_result() -> void:
	var cmd := RollDiceCommand.new(PlayerId.YELLOW)
	var d := (cmd as GameCommand).to_dict()
	assert_false(d.has("value"), "RollDiceCommand не сериализира лице на зара")
	assert_false(d.has("dice"), "зарът не е част от командата")
