class_name MovePawnCommandTest
extends TestCase
## Unit тестове за MovePawnCommand (Task #67 / docs/V1_ARCHITECTURE.md, §4.3 / §11).
##
## Покрива:
##   - Domain: extends GameCommand/RefCounted, път game/domain/commands/.
##   - Payload: player_id + pawn_id; command_type = TYPE_MOVE_PAWN; без destination.
##   - Фабрика create_for_pawn; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + валиден PlayerId + валиден PawnId на същия seat.
##   - Сериализация to_dict / from_move_dict / equals / duplicate_command.
##   - Командата носи намерение, не резултат; human и AI ползват еднакъв тип (§16.4).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_move_pawn_command_extends_game_command() -> void:
	var cmd := MovePawnCommand.new(PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0))
	assert_true(cmd is GameCommand)
	assert_true(cmd is RefCounted,
			"MovePawnCommand трябва да extends RefCounted чрез GameCommand")


func test_move_pawn_command_is_not_node() -> void:
	var cmd: Object = MovePawnCommand.new(
			PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0))
	assert_false(cmd is Node,
			"MovePawnCommand не трябва да extends Node — domain слой е без сцени")


func test_move_pawn_command_script_path_is_in_domain_commands() -> void:
	var cmd := MovePawnCommand.new(PlayerId.GREEN, PawnId.for_player(PlayerId.GREEN, 0))
	var path: String = cmd.get_script().resource_path
	assert_true(path.contains("game/domain/commands/"),
			"MovePawnCommand трябва да е в game/domain/commands/")


func test_to_dict_has_no_result_or_presentation_fields() -> void:
	var cmd := MovePawnCommand.create_for_pawn(
			PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0), &"m_1_0", 1)
	var d := cmd.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от командата")
	assert_false(d.has("node_path"), "NodePath не е част от domain командата")
	assert_false(d.has("cell_id"), "командата не носи целева клетка (§4.3)")
	assert_false(d.has("path_index"), "командата не носи path_index")
	assert_false(d.has("destination"), "дестинацията се изчислява от GameEngine")
	assert_false(d.has("dice_value"), "командата не носи резултат от зара")
	assert_false(d.has("result"), "командата носи намерение, не резултат")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в командата")
	assert_false(d.has("events"), "events са DomainEvent[], не част от командата")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_command_type_player_and_pawn() -> void:
	var pawn := PawnId.for_player(PlayerId.CYAN, 2)
	var cmd := MovePawnCommand.new(PlayerId.CYAN, pawn)
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_eq(cmd.player_id, PlayerId.CYAN)
	assert_eq(cmd.pawn_id, pawn)
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.match_id, &"")
	assert_false(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_init_empty_ids_still_sets_command_type() -> void:
	var cmd := MovePawnCommand.new()
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.pawn_id, &"")
	assert_false(cmd.is_valid(),
			"MovePawn без player_id/pawn_id не е готов за apply")


func test_create_for_pawn_sets_envelope() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 1)
	var cmd := MovePawnCommand.create_for_pawn(
			PlayerId.ORANGE, pawn, &"m_10_2", 3, "tok")
	assert_eq(cmd.match_id, &"m_10_2")
	assert_eq(cmd.player_id, PlayerId.ORANGE)
	assert_eq(cmd.pawn_id, pawn)
	assert_eq(cmd.sequence, 3)
	assert_eq(cmd.auth_token, "tok")
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_true(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_stamp_uses_base_envelope() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var cmd := MovePawnCommand.create_for_pawn(PlayerId.GREEN, pawn)
	assert_false(cmd.is_stamped())
	cmd.stamp(&"m_42_0", 1)
	assert_true(cmd.is_stamped())
	assert_eq(cmd.match_id, &"m_42_0")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.player_id, PlayerId.GREEN)
	assert_eq(cmd.pawn_id, pawn)
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_true(cmd.is_valid())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_empty_player_id() -> void:
	var cmd := MovePawnCommand.new(&"", PawnId.for_player(PlayerId.YELLOW, 0))
	assert_false(cmd.is_valid(),
			"MovePawn винаги е ход на seat — празен player_id е невалиден")


func test_is_valid_rejects_unknown_player_id() -> void:
	var cmd := MovePawnCommand.new(&"purple", &"purple_0")
	assert_false(cmd.is_valid())


func test_is_valid_rejects_empty_pawn_id() -> void:
	var cmd := MovePawnCommand.new(PlayerId.YELLOW, &"")
	assert_false(cmd.is_valid())


func test_is_valid_rejects_malformed_pawn_id() -> void:
	var cmd := MovePawnCommand.new(PlayerId.YELLOW, &"yellow")
	assert_false(cmd.is_valid())


func test_is_valid_rejects_pawn_index_out_of_range() -> void:
	var cmd := MovePawnCommand.new(PlayerId.YELLOW, &"yellow_4")
	assert_false(cmd.is_valid())


func test_is_valid_rejects_pawn_owned_by_other_player() -> void:
	var cmd := MovePawnCommand.new(
			PlayerId.YELLOW, PawnId.for_player(PlayerId.GREEN, 0))
	assert_false(cmd.is_valid(),
			"pionka на друг seat не е валиден payload за MovePawn")


func test_is_valid_accepts_all_player_pawn_pairs() -> void:
	for player_id in PlayerId.ALL:
		for pawn_id in PawnId.all_for_player(player_id):
			var cmd := MovePawnCommand.new(player_id, pawn_id)
			assert_true(cmd.is_valid(),
					"%s / %s трябва да е валиден" % [str(player_id), str(pawn_id)])


func test_is_valid_rejects_negative_sequence_even_with_valid_ids() -> void:
	var cmd := MovePawnCommand.create_for_pawn(
			PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0), &"m_1_0", -1)
	assert_false(cmd.is_valid())


func test_is_valid_rejects_malformed_match_id() -> void:
	var cmd := MovePawnCommand.create_for_pawn(
			PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0), &"not_a_match", 1)
	assert_false(cmd.is_valid())


func test_is_valid_accepts_unstamped_with_ids() -> void:
	var cmd := MovePawnCommand.new(
			PlayerId.GREEN, PawnId.for_player(PlayerId.GREEN, 3))
	assert_false(cmd.is_stamped())
	assert_true(cmd.is_valid(),
			"преди stamp командата носи само намерение — валидна с ids")


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_pawn_id() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 2)
	var cmd := MovePawnCommand.create_for_pawn(PlayerId.YELLOW, pawn, &"m_5_1", 2)
	var d := cmd.to_dict()
	assert_eq(d.size(), 6)
	assert_true(d.has("match_id"))
	assert_true(d.has("player_id"))
	assert_true(d.has("sequence"))
	assert_true(d.has("auth_token"))
	assert_true(d.has("command_type"))
	assert_true(d.has("pawn_id"))
	assert_eq(d["command_type"], "MovePawn")
	assert_eq(d["match_id"], "m_5_1")
	assert_eq(d["player_id"], "yellow")
	assert_eq(d["pawn_id"], "yellow_2")
	assert_eq(d["sequence"], 2)
	assert_eq(typeof(d["command_type"]), TYPE_STRING)
	assert_eq(typeof(d["player_id"]), TYPE_STRING)
	assert_eq(typeof(d["pawn_id"]), TYPE_STRING)


func test_from_move_dict_round_trip() -> void:
	var original := MovePawnCommand.create_for_pawn(
			PlayerId.CYAN, PawnId.for_player(PlayerId.CYAN, 1), &"m_7_3", 4, "v2")
	var restored := MovePawnCommand.from_move_dict(original.to_dict())
	assert_true(restored is MovePawnCommand)
	assert_true(original.equals(restored))
	assert_eq(restored.match_id, &"m_7_3")
	assert_eq(restored.player_id, PlayerId.CYAN)
	assert_eq(restored.pawn_id, PawnId.for_player(PlayerId.CYAN, 1))
	assert_eq(restored.sequence, 4)
	assert_eq(restored.auth_token, "v2")
	assert_eq(restored.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_move_dict_defaults_for_missing_keys() -> void:
	var cmd := MovePawnCommand.from_move_dict({})
	assert_eq(cmd.match_id, &"")
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.pawn_id, &"")
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.auth_token, "")
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_false(cmd.is_valid())
	assert_false(cmd.is_stamped())


func test_from_move_dict_forces_command_type() -> void:
	var data := {
		"match_id": "m_1_0",
		"player_id": "green",
		"pawn_id": "green_0",
		"sequence": 1,
		"auth_token": "",
		"command_type": "RollDice",
	}
	var cmd := MovePawnCommand.from_move_dict(data)
	assert_eq(cmd.command_type, GameCommand.TYPE_MOVE_PAWN,
			"from_move_dict трябва да форсира TYPE_MOVE_PAWN")
	assert_eq(cmd.player_id, PlayerId.GREEN)
	assert_eq(cmd.pawn_id, PawnId.for_player(PlayerId.GREEN, 0))
	assert_true(cmd.is_valid())


func test_duplicate_command_is_independent() -> void:
	var cmd := MovePawnCommand.create_for_pawn(
			PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0), &"m_1_0", 1)
	var copy := cmd.duplicate_command() as MovePawnCommand
	assert_not_null(copy)
	assert_true(cmd.equals(copy))
	copy.stamp(&"m_2_0", 9)
	copy.player_id = PlayerId.GREEN
	copy.pawn_id = PawnId.for_player(PlayerId.GREEN, 1)
	assert_eq(cmd.match_id, &"m_1_0",
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.player_id, PlayerId.YELLOW)
	assert_eq(cmd.pawn_id, PawnId.for_player(PlayerId.YELLOW, 0))


func test_equals() -> void:
	var pawn_g0 := PawnId.for_player(PlayerId.GREEN, 0)
	var pawn_g1 := PawnId.for_player(PlayerId.GREEN, 1)
	var a := MovePawnCommand.create_for_pawn(PlayerId.GREEN, pawn_g0, &"m_1_0", 1)
	var b := MovePawnCommand.create_for_pawn(PlayerId.GREEN, pawn_g0, &"m_1_0", 1)
	var c := MovePawnCommand.create_for_pawn(PlayerId.GREEN, pawn_g0, &"m_1_0", 2)
	var d := MovePawnCommand.create_for_pawn(PlayerId.GREEN, pawn_g1, &"m_1_0", 1)
	var e := MovePawnCommand.create_for_pawn(PlayerId.YELLOW,
			PawnId.for_player(PlayerId.YELLOW, 0), &"m_1_0", 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(GameCommand.create(
			&"m_1_0", PlayerId.GREEN, 1, GameCommand.TYPE_MOVE_PAWN)))
	assert_false(a.equals(RollDiceCommand.new(PlayerId.GREEN)))
	assert_false(a.equals(StartMatchCommand.new(null)))


# ── Human / AI споделят еднакъв тип команда ───────────────────────────────────

func test_human_and_ai_emit_same_command_shape() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 1)
	# Същата форма, която HumanController / AIController биха изпратили.
	var human_cmd := MovePawnCommand.new(PlayerId.YELLOW, pawn)
	var ai_cmd := MovePawnCommand.new(PlayerId.YELLOW, pawn)
	assert_true(human_cmd is MovePawnCommand)
	assert_true(ai_cmd is MovePawnCommand)
	assert_true(human_cmd.equals(ai_cmd))
	assert_eq(human_cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_eq(ai_cmd.command_type, GameCommand.TYPE_MOVE_PAWN)
	assert_true(human_cmd.is_valid())
	assert_true(ai_cmd.is_valid())
