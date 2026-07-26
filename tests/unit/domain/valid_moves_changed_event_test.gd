class_name ValidMovesChangedEventTest
extends TestCase
## Unit тестове за ValidMovesChangedEvent (Task #71 / docs/V1_ARCHITECTURE.md, §4.2 / §4.4 / §6.1).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: player_id + valid_pawn_ids; event_type = TYPE_VALID_MOVES_CHANGED.
##   - Фабрики create_changed / create_from_turn; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + PlayerId + pawn ids на същия играч, без дубликати.
##   - Сериализация to_dict / from_changed_dict / equals / duplicate_event.
##   - Събитието описва факт (валидни пионки), не намерение (§4.3 / §6.1).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_valid_moves_changed_event_extends_domain_event() -> void:
	var event := ValidMovesChangedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"ValidMovesChangedEvent трябва да extends RefCounted чрез DomainEvent")


func test_valid_moves_changed_event_is_not_node() -> void:
	var event: Object = ValidMovesChangedEvent.new()
	assert_false(event is Node,
			"ValidMovesChangedEvent не трябва да extends Node — domain слой е без сцени")


func test_valid_moves_changed_event_script_path_is_in_domain_events() -> void:
	var event := ValidMovesChangedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"ValidMovesChangedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.YELLOW, [PawnId.for_player(PlayerId.YELLOW, 0)])
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от ValidMovesChangedEvent payload")
	assert_false(d.has("dice"), "DiceState snapshot не е payload")
	assert_false(d.has("destination"), "дестинациите не са в ValidMovesChanged")
	assert_false(d.has("to_cell_id"), "клетките не са в ValidMovesChanged")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var pawns := [PawnId.for_player(PlayerId.GREEN, 0), PawnId.for_player(PlayerId.GREEN, 2)]
	var event := ValidMovesChangedEvent.new(PlayerId.GREEN, pawns)
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_eq(event.player_id, PlayerId.GREEN)
	assert_eq(event.valid_pawn_ids.size(), 2)
	assert_eq(event.valid_pawn_ids[0], PawnId.for_player(PlayerId.GREEN, 0))
	assert_eq(event.valid_pawn_ids[1], PawnId.for_player(PlayerId.GREEN, 2))
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_true(event.has_moves())


func test_init_defaults_still_sets_event_type() -> void:
	var event := ValidMovesChangedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_eq(event.player_id, &"")
	assert_eq(event.valid_pawn_ids.size(), 0)
	assert_false(event.is_valid(),
			"ValidMovesChanged без player_id не е валиден факт")


func test_init_copies_pawn_ids_array() -> void:
	var source := [PawnId.for_player(PlayerId.CYAN, 1)]
	var event := ValidMovesChangedEvent.new(PlayerId.CYAN, source)
	source.append(PawnId.for_player(PlayerId.CYAN, 2))
	assert_eq(event.valid_pawn_ids.size(), 1,
			"конструкторът трябва да копира valid_pawn_ids")


func test_create_changed_sets_envelope_and_payload() -> void:
	var pawn_a := PawnId.for_player(PlayerId.ORANGE, 0)
	var pawn_b := PawnId.for_player(PlayerId.ORANGE, 3)
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.ORANGE, [pawn_a, pawn_b], 1)
	assert_eq(event.player_id, PlayerId.ORANGE)
	assert_eq(event.valid_pawn_ids.size(), 2)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())
	assert_true(event.contains_pawn(pawn_a))
	assert_true(event.contains_pawn(pawn_b))
	assert_false(event.contains_pawn(PawnId.for_player(PlayerId.ORANGE, 1)))


func test_create_from_turn_copies_valid_pawn_ids() -> void:
	var turn := TurnState.create_match_start()
	turn.enter_awaiting_move(6, [
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 1),
	])
	var event := ValidMovesChangedEvent.create_from_turn(PlayerId.YELLOW, turn, 2)
	assert_eq(event.player_id, PlayerId.YELLOW)
	assert_eq(event.command_sequence, 2)
	assert_eq(event.valid_pawn_ids.size(), 2)
	assert_eq(event.valid_pawn_ids[0], PawnId.for_player(PlayerId.YELLOW, 0))
	assert_true(event.is_valid())
	turn.set_valid_pawn_ids([])
	assert_eq(event.valid_pawn_ids.size(), 2,
			"мутация на TurnState не трябва да пипа event payload")


func test_create_from_turn_null_turn_yields_empty_pawns() -> void:
	var event := ValidMovesChangedEvent.create_from_turn(PlayerId.GREEN, null, 1)
	assert_eq(event.valid_pawn_ids.size(), 0)
	assert_true(event.is_valid())
	assert_false(event.has_moves())


func test_stamp_uses_base_envelope() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.CYAN, [PawnId.for_player(PlayerId.CYAN, 0)])
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_eq(event.player_id, PlayerId.CYAN)
	assert_true(event.is_valid())


# ── is_valid() / has_moves() / contains_pawn() ────────────────────────────────

func test_is_valid_rejects_empty_player_id() -> void:
	var event := ValidMovesChangedEvent.new(&"", [PawnId.for_player(PlayerId.YELLOW, 0)])
	assert_false(event.is_valid(),
			"ValidMovesChanged без player_id не е валиден факт")


func test_is_valid_rejects_unknown_player_id() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			&"purple", [PawnId.for_player(PlayerId.YELLOW, 0)], 1)
	assert_false(event.is_valid())


func test_is_valid_accepts_empty_pawn_list() -> void:
	var event := ValidMovesChangedEvent.create_changed(PlayerId.GREEN, [], 1)
	assert_true(event.is_valid(),
			"празен valid_pawn_ids е валиден факт (изчистване / няма ходове)")
	assert_false(event.has_moves())


func test_is_valid_rejects_invalid_pawn_id() -> void:
	var event := ValidMovesChangedEvent.new(PlayerId.GREEN, [&"not_a_pawn"])
	assert_false(event.is_valid())


func test_is_valid_rejects_foreign_pawn() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.YELLOW, [PawnId.for_player(PlayerId.GREEN, 0)], 1)
	assert_false(event.is_valid(),
			"пионка на друг играч не е валиден ход за player_id")


func test_is_valid_rejects_duplicate_pawn_ids() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 1)
	var event := ValidMovesChangedEvent.new(PlayerId.ORANGE, [pawn, pawn])
	assert_false(event.is_valid())


func test_is_valid_accepts_all_player_ids() -> void:
	for player_id in PlayerId.ALL:
		var event := ValidMovesChangedEvent.create_changed(
				player_id, [PawnId.for_player(player_id, 0)], 1)
		assert_true(event.is_valid(),
				"player_id %s трябва да е валиден" % str(player_id))


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.GREEN, [PawnId.for_player(PlayerId.GREEN, 0)], -1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.GREEN, [PawnId.for_player(PlayerId.GREEN, 0)])
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"ValidMovesChanged може да е валиден преди stamp на command_sequence")


func test_has_moves_and_contains_pawn() -> void:
	var empty := ValidMovesChangedEvent.create_changed(PlayerId.YELLOW, [])
	assert_false(empty.has_moves())
	assert_false(empty.contains_pawn(PawnId.for_player(PlayerId.YELLOW, 0)))

	var pawn := PawnId.for_player(PlayerId.YELLOW, 2)
	var event := ValidMovesChangedEvent.create_changed(PlayerId.YELLOW, [pawn])
	assert_true(event.has_moves())
	assert_true(event.contains_pawn(pawn))
	assert_false(event.contains_pawn(PawnId.for_player(PlayerId.YELLOW, 0)))


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.YELLOW,
			[PawnId.for_player(PlayerId.YELLOW, 0), PawnId.for_player(PlayerId.YELLOW, 1)],
			2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("player_id"))
	assert_true(d.has("valid_pawn_ids"))
	assert_eq(d["event_type"], "ValidMovesChanged")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["player_id"], "yellow")
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["player_id"]), TYPE_STRING)
	assert_true(d["valid_pawn_ids"] is Array)
	assert_eq(d["valid_pawn_ids"].size(), 2)
	assert_eq(d["valid_pawn_ids"][0], "yellow_0")
	assert_eq(d["valid_pawn_ids"][1], "yellow_1")
	assert_eq(typeof(d["valid_pawn_ids"][0]), TYPE_STRING)


func test_from_dict_round_trip() -> void:
	var original := ValidMovesChangedEvent.create_changed(
			PlayerId.CYAN,
			[PawnId.for_player(PlayerId.CYAN, 3)],
			4)
	var restored := ValidMovesChangedEvent.from_changed_dict(original.to_dict())
	assert_true(restored is ValidMovesChangedEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.player_id, PlayerId.CYAN)
	assert_eq(restored.valid_pawn_ids.size(), 1)
	assert_eq(restored.valid_pawn_ids[0], PawnId.for_player(PlayerId.CYAN, 3))
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := ValidMovesChangedEvent.from_changed_dict({})
	assert_eq(event.player_id, &"")
	assert_eq(event.valid_pawn_ids.size(), 0)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"player_id": "green",
		"valid_pawn_ids": ["green_0"],
	}
	var event := ValidMovesChangedEvent.from_changed_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED,
			"from_changed_dict трябва да форсира TYPE_VALID_MOVES_CHANGED")


func test_duplicate_event_is_independent() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.ORANGE, [PawnId.for_player(PlayerId.ORANGE, 0)], 1)
	var copy := event.duplicate_event() as ValidMovesChangedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.valid_pawn_ids.append(PawnId.for_player(PlayerId.ORANGE, 1))
	copy.stamp(9)
	copy.player_id = PlayerId.GREEN
	assert_eq(event.valid_pawn_ids.size(), 1,
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.player_id, PlayerId.ORANGE)
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var a := ValidMovesChangedEvent.create_changed(PlayerId.GREEN, [pawn], 1)
	var b := ValidMovesChangedEvent.create_changed(PlayerId.GREEN, [pawn], 1)
	var c := ValidMovesChangedEvent.create_changed(PlayerId.GREEN, [pawn], 2)
	var d := ValidMovesChangedEvent.create_changed(PlayerId.YELLOW, [PawnId.for_player(PlayerId.YELLOW, 0)], 1)
	var e := ValidMovesChangedEvent.create_changed(
			PlayerId.GREEN, [pawn, PawnId.for_player(PlayerId.GREEN, 1)], 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_VALID_MOVES_CHANGED, 1)))


# ── Договор с TurnState / MovePawnCommand ─────────────────────────────────────

func test_payload_matches_turn_state_awaiting_move() -> void:
	var pawns := [
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 2),
	]
	var turn := TurnState.create_match_start()
	turn.enter_awaiting_move(4, pawns)
	var event := ValidMovesChangedEvent.create_from_turn(PlayerId.YELLOW, turn, 1)
	assert_true(event.is_valid())
	assert_eq(event.valid_pawn_ids.size(), turn.valid_pawn_ids.size())
	assert_true(event.contains_pawn(pawns[0]))
	assert_true(turn.has_valid_pawn(pawns[0]))
	assert_true(turn.allows_move_pawn())


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_VALID_MOVES_CHANGED, &"ValidMovesChanged")
	var event := ValidMovesChangedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_event_lists_pawns_for_move_commands() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var cmd := MovePawnCommand.new(PlayerId.GREEN, pawn)
	var event := ValidMovesChangedEvent.create_changed(PlayerId.GREEN, [pawn], 1)
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())
	assert_true(event.contains_pawn(cmd.pawn_id),
			"ValidMovesChanged посочва кои MovePawnCommand са legal")
	assert_false(cmd.to_dict().has("valid_pawn_ids"),
			"MovePawnCommand носи намерение за една пионка, не целия набор")
