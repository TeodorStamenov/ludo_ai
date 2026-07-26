class_name PawnCapturedEventTest
extends TestCase
## Unit тестове за PawnCapturedEvent (Task #74 / docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 — стъпване върху единична противникова пионка).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: capturing_pawn_id + captured_pawn_id; event_type = TYPE_PAWN_CAPTURED.
##   - Фабрики create_captured / create_from_states; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + два валидни PawnId на различни играчи.
##   - Сериализация to_dict / from_captured_dict / equals / duplicate_event.
##   - Събитието описва факт (взимане), не намерение (§4.3 / §6.2).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_captured_event_extends_domain_event() -> void:
	var event := PawnCapturedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PawnCapturedEvent трябва да extends RefCounted чрез DomainEvent")


func test_pawn_captured_event_is_not_node() -> void:
	var event: Object = PawnCapturedEvent.new()
	assert_false(event is Node,
			"PawnCapturedEvent не трябва да extends Node — domain слой е без сцени")


func test_pawn_captured_event_script_path_is_in_domain_events() -> void:
	var event := PawnCapturedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PawnCapturedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.GREEN, 1))
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PawnCapturedEvent payload")
	assert_false(d.has("cell_id"), "клетката е в PawnMoved / PawnSentHome, не тук")
	assert_false(d.has("from_cell_id"), "from_cell_id е в PawnSentHome, не в PawnCaptured")
	assert_false(d.has("to_cell_id"), "to_cell_id е в PawnMoved, не в PawnCaptured")
	assert_false(d.has("player_id"), "player_id се извежда от pawn_id, не е отделно поле")
	assert_false(d.has("pawn_id"), "payload ползва capturing/captured_pawn_id")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var capturing := PawnId.for_player(PlayerId.YELLOW, 0)
	var captured := PawnId.for_player(PlayerId.GREEN, 2)
	var event := PawnCapturedEvent.new(capturing, captured)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_eq(event.capturing_pawn_id, capturing)
	assert_eq(event.captured_pawn_id, captured)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.get_capturing_player_id(), PlayerId.YELLOW)
	assert_eq(event.get_captured_player_id(), PlayerId.GREEN)


func test_init_defaults_still_sets_event_type() -> void:
	var event := PawnCapturedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_eq(event.capturing_pawn_id, &"")
	assert_eq(event.captured_pawn_id, &"")
	assert_false(event.is_valid(),
			"PawnCaptured без pawn_id не е валиден факт")


func test_create_captured_sets_envelope_and_payload() -> void:
	var capturing := PawnId.for_player(PlayerId.CYAN, 1)
	var captured := PawnId.for_player(PlayerId.ORANGE, 0)
	var event := PawnCapturedEvent.create_captured(capturing, captured, 1)
	assert_eq(event.capturing_pawn_id, capturing)
	assert_eq(event.captured_pawn_id, captured)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_from_states_copies_capture_pair() -> void:
	var cell := CellId.from_grid(8, 5)
	var capturing := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnZone.MAIN_PATH, 4, cell, 0)
	var captured := PawnState.create(
			PawnId.for_player(PlayerId.GREEN, 1),
			PawnZone.MAIN_PATH, 12, cell, 0)
	var event := PawnCapturedEvent.create_from_states(capturing, captured, 2)
	assert_eq(event.capturing_pawn_id, capturing.pawn_id)
	assert_eq(event.captured_pawn_id, captured.pawn_id)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_states_rejects_invalid_capture_setup() -> void:
	var cell := CellId.from_grid(8, 5)
	var yellow := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnZone.MAIN_PATH, 4, cell, 0)
	var yellow_other := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 1),
			PawnZone.MAIN_PATH, 3, cell, 0)
	var green := PawnState.create(
			PawnId.for_player(PlayerId.GREEN, 0),
			PawnZone.MAIN_PATH, 12, cell, 0)
	var green_elsewhere := PawnState.create(
			PawnId.for_player(PlayerId.GREEN, 0),
			PawnZone.MAIN_PATH, 10, CellId.from_grid(8, 2), 0)
	var green_home := PawnState.create(
			PawnId.for_player(PlayerId.GREEN, 0),
			PawnZone.HOME_STRETCH, 1, CellId.from_grid(7, 11), 0)
	assert_false(PawnCapturedEvent.create_from_states(null, green).is_valid())
	assert_false(PawnCapturedEvent.create_from_states(yellow, null).is_valid())
	assert_false(PawnCapturedEvent.create_from_states(yellow, yellow).is_valid(),
			"същата пионка не е capture")
	assert_false(PawnCapturedEvent.create_from_states(yellow, yellow_other).is_valid(),
			"свои пионки не се взимат")
	assert_false(PawnCapturedEvent.create_from_states(yellow, green_elsewhere).is_valid(),
			"capture изисква една и съща клетка")
	assert_false(PawnCapturedEvent.create_from_states(yellow, green_home).is_valid(),
			"home stretch е имунизиран — не е MAIN_PATH capture")
	assert_true(PawnCapturedEvent.create_from_states(yellow, green).is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.GREEN, 0))
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_pawn_ids() -> void:
	var only_capturing := PawnCapturedEvent.new(
			PawnId.for_player(PlayerId.YELLOW, 0), &"")
	var only_captured := PawnCapturedEvent.new(
			&"", PawnId.for_player(PlayerId.GREEN, 0))
	assert_false(only_capturing.is_valid())
	assert_false(only_captured.is_valid())


func test_is_valid_rejects_unknown_pawn_ids() -> void:
	var event := PawnCapturedEvent.create_captured(
			&"purple_0",
			PawnId.for_player(PlayerId.GREEN, 0),
			1)
	assert_false(event.is_valid())


func test_is_valid_rejects_same_pawn() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var event := PawnCapturedEvent.create_captured(pawn, pawn, 1)
	assert_false(event.is_valid(),
			"PawnCaptured със същия pawn_id не описва взимане")


func test_is_valid_rejects_same_player() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 2),
			1)
	assert_false(event.is_valid(),
			"не може да вземеш своя пионка — capture е само срещу противник")


func test_is_valid_accepts_all_opponent_seat_pairs() -> void:
	var seats := [PlayerId.YELLOW, PlayerId.GREEN, PlayerId.CYAN, PlayerId.ORANGE]
	for a in seats:
		for b in seats:
			if a == b:
				continue
			var event := PawnCapturedEvent.create_captured(
					PawnId.for_player(a, 0),
					PawnId.for_player(b, 1),
					1)
			assert_true(event.is_valid(),
					"capture %s → %s трябва да е валиден" % [a, b])


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.GREEN, 0),
			-1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.GREEN, 0))
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PawnCaptured може да е валиден преди stamp на command_sequence")


func test_player_id_helpers() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.CYAN, 2),
			PawnId.for_player(PlayerId.ORANGE, 3))
	assert_eq(event.get_capturing_player_id(), PlayerId.CYAN)
	assert_eq(event.get_captured_player_id(), PlayerId.ORANGE)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var capturing := PawnId.for_player(PlayerId.YELLOW, 0)
	var captured := PawnId.for_player(PlayerId.GREEN, 1)
	var event := PawnCapturedEvent.create_captured(capturing, captured, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("capturing_pawn_id"))
	assert_true(d.has("captured_pawn_id"))
	assert_eq(d["event_type"], "PawnCaptured")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["capturing_pawn_id"], "yellow_0")
	assert_eq(d["captured_pawn_id"], "green_1")
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["capturing_pawn_id"]), TYPE_STRING)
	assert_eq(typeof(d["captured_pawn_id"]), TYPE_STRING)


func test_from_dict_round_trip() -> void:
	var original := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.CYAN, 3),
			PawnId.for_player(PlayerId.ORANGE, 0),
			4)
	var restored := PawnCapturedEvent.from_captured_dict(original.to_dict())
	assert_true(restored is PawnCapturedEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.capturing_pawn_id, original.capturing_pawn_id)
	assert_eq(restored.captured_pawn_id, original.captured_pawn_id)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := PawnCapturedEvent.from_captured_dict({})
	assert_eq(event.capturing_pawn_id, &"")
	assert_eq(event.captured_pawn_id, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"capturing_pawn_id": "green_0",
		"captured_pawn_id": "yellow_1",
	}
	var event := PawnCapturedEvent.from_captured_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED,
			"from_captured_dict трябва да форсира TYPE_PAWN_CAPTURED")


func test_duplicate_event_is_independent() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.ORANGE, 1),
			PawnId.for_player(PlayerId.CYAN, 2),
			1)
	var copy := event.duplicate_event() as PawnCapturedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.captured_pawn_id = PawnId.for_player(PlayerId.GREEN, 0)
	copy.stamp(9)
	copy.capturing_pawn_id = PawnId.for_player(PlayerId.YELLOW, 0)
	assert_eq(event.captured_pawn_id, PawnId.for_player(PlayerId.CYAN, 2),
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.capturing_pawn_id, PawnId.for_player(PlayerId.ORANGE, 1))
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var capturing := PawnId.for_player(PlayerId.GREEN, 0)
	var captured := PawnId.for_player(PlayerId.YELLOW, 1)
	var a := PawnCapturedEvent.create_captured(capturing, captured, 1)
	var b := PawnCapturedEvent.create_captured(capturing, captured, 1)
	var c := PawnCapturedEvent.create_captured(capturing, captured, 2)
	var d := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.CYAN, 0), captured, 1)
	var e := PawnCapturedEvent.create_captured(
			capturing, PawnId.for_player(PlayerId.ORANGE, 0), 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PAWN_CAPTURED, 1)))


# ── Договор с MovePawnCommand / sibling events ─────────────────────────────────

func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PAWN_CAPTURED, &"PawnCaptured")
	var event := PawnCapturedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_event_carries_capture_pair_unlike_move_command() -> void:
	var capturing := PawnId.for_player(PlayerId.GREEN, 1)
	var captured := PawnId.for_player(PlayerId.YELLOW, 0)
	var cmd := MovePawnCommand.new(PlayerId.GREEN, capturing)
	var event := PawnCapturedEvent.create_captured(capturing, captured, 1)
	assert_false(cmd.to_dict().has("capturing_pawn_id"),
			"MovePawnCommand носи намерение, не capture резултат")
	assert_false(cmd.to_dict().has("captured_pawn_id"))
	assert_true(event.to_dict().has("captured_pawn_id"),
			"PawnCaptured носи факта от GameEngine взимането")
	assert_eq(event.capturing_pawn_id, cmd.pawn_id)
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())


func test_distinct_from_pawn_moved_event_type() -> void:
	var capturing := PawnId.for_player(PlayerId.YELLOW, 0)
	var captured := PawnId.for_player(PlayerId.GREEN, 0)
	var cell_from := CellId.from_grid(8, 2)
	var cell_to := CellId.from_grid(8, 5)
	var captured_event := PawnCapturedEvent.create_captured(capturing, captured, 1)
	var moved := PawnMovedEvent.create_moved(
			capturing, cell_from, cell_to, PawnZone.MAIN_PATH, 1)
	assert_eq(captured_event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_eq(moved.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_false(captured_event.equals(moved))
	assert_true(captured_event.is_valid())
	assert_true(moved.is_valid())
