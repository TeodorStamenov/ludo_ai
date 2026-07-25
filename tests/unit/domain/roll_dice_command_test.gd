class_name RollDiceCommandTest
extends TestCase
## Unit тестове за RollDiceCommand (Task #66 / docs/V1_ARCHITECTURE.md, §4.3 / §11).
##
## Покрива:
##   - Domain: extends GameCommand/RefCounted, път game/domain/commands/.
##   - Payload: player_id; command_type = TYPE_ROLL_DICE; без dice result.
##   - Фабрика create_for_player; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + непразен валиден PlayerId.
##   - Сериализация to_dict / from_roll_dict / equals / duplicate_command.
##   - Командата носи намерение, не резултат (§4.3).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_roll_dice_command_extends_game_command() -> void:
	var cmd := RollDiceCommand.new(PlayerId.YELLOW)
	assert_true(cmd is GameCommand)
	assert_true(cmd is RefCounted,
			"RollDiceCommand трябва да extends RefCounted чрез GameCommand")


func test_roll_dice_command_is_not_node() -> void:
	var cmd: Object = RollDiceCommand.new(PlayerId.YELLOW)
	assert_false(cmd is Node,
			"RollDiceCommand не трябва да extends Node — domain слой е без сцени")


func test_roll_dice_command_script_path_is_in_domain_commands() -> void:
	var cmd := RollDiceCommand.new(PlayerId.GREEN)
	var path: String = cmd.get_script().resource_path
	assert_true(path.contains("game/domain/commands/"),
			"RollDiceCommand трябва да е в game/domain/commands/")


func test_to_dict_has_no_result_or_presentation_fields() -> void:
	var cmd := RollDiceCommand.create_for_player(PlayerId.YELLOW, &"m_1_0", 1)
	var d := cmd.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от командата")
	assert_false(d.has("node_path"), "NodePath не е част от domain командата")
	assert_false(d.has("dice_value"), "командата не носи резултат от зара (§4.3)")
	assert_false(d.has("value"), "RollDiceCommand не сериализира лице на зара")
	assert_false(d.has("dice"), "зарът не е част от командата")
	assert_false(d.has("result"), "командата носи намерение, не резултат")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в командата")
	assert_false(d.has("events"), "events са DomainEvent[], не част от командата")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_command_type_and_player_id() -> void:
	var cmd := RollDiceCommand.new(PlayerId.CYAN)
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE)
	assert_eq(cmd.player_id, PlayerId.CYAN)
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.match_id, &"")
	assert_false(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_init_empty_player_still_sets_command_type() -> void:
	var cmd := RollDiceCommand.new()
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE)
	assert_eq(cmd.player_id, &"")
	assert_false(cmd.is_valid(),
			"RollDice без player_id не е готов за apply")


func test_create_for_player_sets_envelope() -> void:
	var cmd := RollDiceCommand.create_for_player(
			PlayerId.ORANGE, &"m_10_2", 3, "tok")
	assert_eq(cmd.match_id, &"m_10_2")
	assert_eq(cmd.player_id, PlayerId.ORANGE)
	assert_eq(cmd.sequence, 3)
	assert_eq(cmd.auth_token, "tok")
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE)
	assert_true(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_stamp_uses_base_envelope() -> void:
	var cmd := RollDiceCommand.create_for_player(PlayerId.GREEN)
	assert_false(cmd.is_stamped())
	cmd.stamp(&"m_42_0", 1)
	assert_true(cmd.is_stamped())
	assert_eq(cmd.match_id, &"m_42_0")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.player_id, PlayerId.GREEN)
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE)
	assert_true(cmd.is_valid())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_empty_player_id() -> void:
	var cmd := RollDiceCommand.new(&"")
	assert_false(cmd.is_valid(),
			"RollDice винаги е ход на seat — празен player_id е невалиден")


func test_is_valid_rejects_unknown_player_id() -> void:
	var cmd := RollDiceCommand.new(&"purple")
	assert_false(cmd.is_valid())


func test_is_valid_accepts_all_player_ids() -> void:
	for player_id in PlayerId.ALL:
		var cmd := RollDiceCommand.new(player_id)
		assert_true(cmd.is_valid(),
				"player_id %s трябва да е валиден" % str(player_id))


func test_is_valid_rejects_negative_sequence_even_with_valid_player() -> void:
	var cmd := RollDiceCommand.create_for_player(PlayerId.YELLOW, &"m_1_0", -1)
	assert_false(cmd.is_valid())


func test_is_valid_rejects_malformed_match_id() -> void:
	var cmd := RollDiceCommand.create_for_player(PlayerId.YELLOW, &"not_a_match", 1)
	assert_false(cmd.is_valid())


func test_is_valid_accepts_unstamped_with_player() -> void:
	var cmd := RollDiceCommand.new(PlayerId.GREEN)
	assert_false(cmd.is_stamped())
	assert_true(cmd.is_valid(),
			"преди stamp командата носи само намерение — валидна с player_id")


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_only() -> void:
	var cmd := RollDiceCommand.create_for_player(PlayerId.YELLOW, &"m_5_1", 2)
	var d := cmd.to_dict()
	assert_eq(d.size(), 5)
	assert_true(d.has("match_id"))
	assert_true(d.has("player_id"))
	assert_true(d.has("sequence"))
	assert_true(d.has("auth_token"))
	assert_true(d.has("command_type"))
	assert_eq(d["command_type"], "RollDice")
	assert_eq(d["match_id"], "m_5_1")
	assert_eq(d["player_id"], "yellow")
	assert_eq(d["sequence"], 2)
	assert_eq(typeof(d["command_type"]), TYPE_STRING)
	assert_eq(typeof(d["player_id"]), TYPE_STRING)


func test_from_roll_dict_round_trip() -> void:
	var original := RollDiceCommand.create_for_player(
			PlayerId.CYAN, &"m_7_3", 4, "v2")
	var restored := RollDiceCommand.from_roll_dict(original.to_dict())
	assert_true(restored is RollDiceCommand)
	assert_true(original.equals(restored))
	assert_eq(restored.match_id, &"m_7_3")
	assert_eq(restored.player_id, PlayerId.CYAN)
	assert_eq(restored.sequence, 4)
	assert_eq(restored.auth_token, "v2")
	assert_eq(restored.command_type, GameCommand.TYPE_ROLL_DICE)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_roll_dict_defaults_for_missing_keys() -> void:
	var cmd := RollDiceCommand.from_roll_dict({})
	assert_eq(cmd.match_id, &"")
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.auth_token, "")
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE)
	assert_false(cmd.is_valid())
	assert_false(cmd.is_stamped())


func test_from_roll_dict_forces_command_type() -> void:
	var data := {
		"match_id": "m_1_0",
		"player_id": "green",
		"sequence": 1,
		"auth_token": "",
		"command_type": "StartMatch",
	}
	var cmd := RollDiceCommand.from_roll_dict(data)
	assert_eq(cmd.command_type, GameCommand.TYPE_ROLL_DICE,
			"from_roll_dict трябва да форсира TYPE_ROLL_DICE")
	assert_eq(cmd.player_id, PlayerId.GREEN)
	assert_true(cmd.is_valid())


func test_duplicate_command_is_independent() -> void:
	var cmd := RollDiceCommand.create_for_player(PlayerId.YELLOW, &"m_1_0", 1)
	var copy := cmd.duplicate_command() as RollDiceCommand
	assert_not_null(copy)
	assert_true(cmd.equals(copy))
	copy.stamp(&"m_2_0", 9)
	copy.player_id = PlayerId.GREEN
	assert_eq(cmd.match_id, &"m_1_0",
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.player_id, PlayerId.YELLOW)


func test_equals() -> void:
	var a := RollDiceCommand.create_for_player(PlayerId.GREEN, &"m_1_0", 1)
	var b := RollDiceCommand.create_for_player(PlayerId.GREEN, &"m_1_0", 1)
	var c := RollDiceCommand.create_for_player(PlayerId.GREEN, &"m_1_0", 2)
	var d := RollDiceCommand.create_for_player(PlayerId.YELLOW, &"m_1_0", 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(null))
	assert_false(a.equals(GameCommand.create(
			&"m_1_0", PlayerId.GREEN, 1, GameCommand.TYPE_ROLL_DICE)))
	assert_false(a.equals(StartMatchCommand.new(null)))
	assert_false(a.equals(MovePawnCommand.new(PlayerId.GREEN, &"green_0")))
