class_name PawnSentHomeEventTest
extends TestCase
## Unit тестове за PawnSentHomeEvent (Task #75 / docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 — връщане в базата след взимане).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: pawn_id + from_cell_id + base_cell_id; event_type = TYPE_PAWN_SENT_HOME.
##   - Фабрики create_sent_home / create_from_states; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + PawnId + CellId; from ≠ base.
##   - Сериализация to_dict / from_sent_home_dict / equals / duplicate_event.
##   - Събитието описва факт (връщане вкъщи), не намерение (§4.3 / §6.2).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_sent_home_event_extends_domain_event() -> void:
	var event := PawnSentHomeEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PawnSentHomeEvent трябва да extends RefCounted чрез DomainEvent")


func test_pawn_sent_home_event_is_not_node() -> void:
	var event: Object = PawnSentHomeEvent.new()
	assert_false(event is Node,
			"PawnSentHomeEvent не трябва да extends Node — domain слой е без сцени")


func test_pawn_sent_home_event_script_path_is_in_domain_events() -> void:
	var event := PawnSentHomeEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PawnSentHomeEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.GREEN, 0),
			CellId.from_grid(8, 5),
			Classic15x15Board.base_cells_for(PlayerId.GREEN)[0])
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PawnSentHomeEvent payload")
	assert_false(d.has("path_index"), "path_index е в PawnState, не в PawnSentHome payload")
	assert_false(d.has("zone"), "zone след връщане е винаги BASE — не е отделно поле")
	assert_false(d.has("player_id"), "player_id се извежда от pawn_id, не е отделно поле")
	assert_false(d.has("to_cell_id"), "дестинацията е base_cell_id, не to_cell_id")
	assert_false(d.has("capturing_pawn_id"), "кой е взел е в PawnCaptured, не тук")
	assert_false(d.has("captured_pawn_id"), "capture pair е в PawnCaptured, не тук")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var from_cell := CellId.from_grid(8, 5)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.GREEN)[1]
	var event := PawnSentHomeEvent.new(pawn, from_cell, base_cell)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.base_cell_id, base_cell)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.get_player_id(), PlayerId.GREEN)


func test_init_defaults_still_sets_event_type() -> void:
	var event := PawnSentHomeEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.base_cell_id, &"")
	assert_false(event.is_valid(),
			"PawnSentHome без pawn_id/клетки не е валиден факт")


func test_create_sent_home_sets_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.CYAN, 0)
	var from_cell := CellId.from_grid(6, 8)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.CYAN)[0]
	var event := PawnSentHomeEvent.create_sent_home(pawn, from_cell, base_cell, 1)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.base_cell_id, base_cell)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_from_states_copies_home_transition() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 2)
	var from_cell := CellId.from_grid(8, 2)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.ORANGE)[2]
	var before := PawnState.create(
			pawn, PawnZone.MAIN_PATH, 10, from_cell, 0)
	var after := PawnState.create_in_base(pawn, base_cell)
	var event := PawnSentHomeEvent.create_from_states(before, after, 2)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.base_cell_id, after.cell_id)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_states_rejects_mismatched_null_or_non_home() -> void:
	var yellow := PawnId.for_player(PlayerId.YELLOW, 0)
	var green := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell := CellId.from_grid(8, 5)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0]
	var before := PawnState.create(
			yellow, PawnZone.MAIN_PATH, 4, from_cell, 0)
	var after_home := PawnState.create_in_base(yellow, base_cell)
	var after_other := PawnState.create_in_base(green, Classic15x15Board.base_cells_for(PlayerId.GREEN)[0])
	var still_on_path := PawnState.create(
			yellow, PawnZone.MAIN_PATH, 5, CellId.from_grid(8, 6), 0)
	var in_base := PawnState.create_in_base(yellow, base_cell)
	assert_false(PawnSentHomeEvent.create_from_states(before, after_other, 1).is_valid())
	assert_false(PawnSentHomeEvent.create_from_states(null, after_home).is_valid())
	assert_false(PawnSentHomeEvent.create_from_states(before, null).is_valid())
	assert_false(PawnSentHomeEvent.create_from_states(after_home, before).is_valid(),
			"обратен преход base→path не е PawnSentHome")
	assert_false(PawnSentHomeEvent.create_from_states(before, still_on_path).is_valid(),
			"трябва да завърши в BASE")
	assert_false(PawnSentHomeEvent.create_from_states(in_base, after_home).is_valid(),
			"before трябва да е на дъската, не вече в база")
	assert_true(PawnSentHomeEvent.create_from_states(before, after_home).is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 5),
			Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0])
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_pawn_id() -> void:
	var event := PawnSentHomeEvent.new(
			&"", CellId.from_grid(8, 5), CellId.from_grid(12, 12))
	assert_false(event.is_valid(),
			"PawnSentHome без pawn_id не е валиден факт")


func test_is_valid_rejects_unknown_pawn_id() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			&"purple_0",
			CellId.from_grid(8, 5),
			CellId.from_grid(12, 12),
			1)
	assert_false(event.is_valid())


func test_is_valid_rejects_invalid_cells() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var bad_from := PawnSentHomeEvent.new(
			pawn, &"not_a_cell", CellId.from_grid(2, 2))
	var bad_base := PawnSentHomeEvent.new(
			pawn, CellId.from_grid(8, 5), &"x_0_0")
	assert_false(bad_from.is_valid())
	assert_false(bad_base.is_valid())


func test_is_valid_rejects_same_from_and_base() -> void:
	var cell := CellId.from_grid(4, 4)
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.YELLOW, 1),
			cell,
			cell,
			1)
	assert_false(event.is_valid(),
			"PawnSentHome с from == base не описва връщане")


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 5),
			Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0],
			-1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 5),
			Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0])
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PawnSentHome може да е валиден преди stamp на command_sequence")


func test_get_player_id() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.CYAN, 2),
			CellId.from_grid(6, 8),
			Classic15x15Board.base_cells_for(PlayerId.CYAN)[2])
	assert_eq(event.get_player_id(), PlayerId.CYAN)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell := CellId.from_grid(8, 5)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0]
	var event := PawnSentHomeEvent.create_sent_home(pawn, from_cell, base_cell, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("pawn_id"))
	assert_true(d.has("from_cell_id"))
	assert_true(d.has("base_cell_id"))
	assert_eq(d["event_type"], "PawnSentHome")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["pawn_id"], "yellow_0")
	assert_eq(d["from_cell_id"], String(from_cell))
	assert_eq(d["base_cell_id"], String(base_cell))
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["pawn_id"]), TYPE_STRING)
	assert_eq(typeof(d["from_cell_id"]), TYPE_STRING)
	assert_eq(typeof(d["base_cell_id"]), TYPE_STRING)


func test_from_dict_round_trip() -> void:
	var original := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.CYAN, 3),
			CellId.from_grid(2, 8),
			Classic15x15Board.base_cells_for(PlayerId.CYAN)[3],
			4)
	var restored := PawnSentHomeEvent.from_sent_home_dict(original.to_dict())
	assert_true(restored is PawnSentHomeEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.pawn_id, original.pawn_id)
	assert_eq(restored.from_cell_id, original.from_cell_id)
	assert_eq(restored.base_cell_id, original.base_cell_id)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := PawnSentHomeEvent.from_sent_home_dict({})
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.base_cell_id, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"pawn_id": "green_0",
		"from_cell_id": "c_8_5",
		"base_cell_id": "c_2_2",
	}
	var event := PawnSentHomeEvent.from_sent_home_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME,
			"from_sent_home_dict трябва да форсира TYPE_PAWN_SENT_HOME")


func test_duplicate_event_is_independent() -> void:
	var event := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.ORANGE, 1),
			CellId.from_grid(8, 9),
			Classic15x15Board.base_cells_for(PlayerId.ORANGE)[1],
			1)
	var copy := event.duplicate_event() as PawnSentHomeEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.base_cell_id = CellId.from_grid(1, 1)
	copy.stamp(9)
	copy.pawn_id = PawnId.for_player(PlayerId.GREEN, 0)
	assert_eq(event.base_cell_id, Classic15x15Board.base_cells_for(PlayerId.ORANGE)[1],
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.pawn_id, PawnId.for_player(PlayerId.ORANGE, 1))
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell := CellId.from_grid(8, 5)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.GREEN)[0]
	var a := PawnSentHomeEvent.create_sent_home(pawn, from_cell, base_cell, 1)
	var b := PawnSentHomeEvent.create_sent_home(pawn, from_cell, base_cell, 1)
	var c := PawnSentHomeEvent.create_sent_home(pawn, from_cell, base_cell, 2)
	var d := PawnSentHomeEvent.create_sent_home(
			PawnId.for_player(PlayerId.YELLOW, 0), from_cell, base_cell, 1)
	var e := PawnSentHomeEvent.create_sent_home(
			pawn, from_cell, Classic15x15Board.base_cells_for(PlayerId.GREEN)[1], 1)
	var f := PawnSentHomeEvent.create_sent_home(
			pawn, CellId.from_grid(8, 2), base_cell, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(f))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PAWN_SENT_HOME, 1)))


# ── Договор с PawnState / PawnCaptured / place_in_base ─────────────────────────

func test_payload_matches_place_in_base() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell := CellId.from_grid(8, 5)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0]
	var before := PawnState.create(
			pawn, PawnZone.MAIN_PATH, 4, from_cell, 1)
	var after := before.duplicate_state()
	after.place_in_base(base_cell)
	var event := PawnSentHomeEvent.create_from_states(before, after, 1)
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, after.pawn_id)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.base_cell_id, after.cell_id)
	assert_true(after.is_in_base())
	assert_eq(after.shield_turns_remaining, 0)
	assert_true(before.is_on_main_path())


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PAWN_SENT_HOME, &"PawnSentHome")
	var event := PawnSentHomeEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_distinct_from_pawn_captured_and_moved() -> void:
	var capturing := PawnId.for_player(PlayerId.YELLOW, 0)
	var captured := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell := CellId.from_grid(8, 5)
	var base_cell: StringName = Classic15x15Board.base_cells_for(PlayerId.GREEN)[0]
	var sent := PawnSentHomeEvent.create_sent_home(captured, from_cell, base_cell, 1)
	var captured_event := PawnCapturedEvent.create_captured(capturing, captured, 1)
	var moved := PawnMovedEvent.create_moved(
			capturing, CellId.from_grid(8, 2), from_cell, PawnZone.MAIN_PATH, 1)
	assert_eq(sent.event_type, DomainEvent.TYPE_PAWN_SENT_HOME)
	assert_eq(captured_event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_eq(moved.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_false(sent.equals(captured_event))
	assert_false(sent.equals(moved))
	assert_true(sent.is_valid())
	assert_true(captured_event.is_valid())
	assert_true(moved.is_valid())


func test_event_carries_base_unlike_move_command() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var cmd := MovePawnCommand.new(PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0))
	var event := PawnSentHomeEvent.create_sent_home(
			pawn,
			CellId.from_grid(8, 5),
			Classic15x15Board.base_cells_for(PlayerId.GREEN)[1],
			1)
	assert_false(cmd.to_dict().has("base_cell_id"),
			"MovePawnCommand носи намерение, не base дестинация")
	assert_false(cmd.to_dict().has("from_cell_id"))
	assert_true(event.to_dict().has("base_cell_id"),
			"PawnSentHome носи факта от GameEngine връщането")
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())
