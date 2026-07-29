class_name PawnMovedEventTest
extends TestCase
## Unit тестове за PawnMovedEvent (Task #72 / docs/V1_ARCHITECTURE.md, §4.4 / §6.2 / §11).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: pawn_id + from_cell_id + to_cell_id + zone; event_type = TYPE_PAWN_MOVED.
##   - Фабрики create_moved / create_from_states; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + PawnId + CellId + PawnZone; from ≠ to;
##     zone никога FINISHED (V1.1 — това е PawnFinishedEvent, флаг без движение).
##   - Сериализация to_dict / from_moved_dict / equals / duplicate_event.
##   - Събитието описва факт (дестинация), не намерение (§4.3 / §6.2).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_moved_event_extends_domain_event() -> void:
	var event := PawnMovedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PawnMovedEvent трябва да extends RefCounted чрез DomainEvent")


func test_pawn_moved_event_is_not_node() -> void:
	var event: Object = PawnMovedEvent.new()
	assert_false(event is Node,
			"PawnMovedEvent не трябва да extends Node — domain слой е без сцени")


func test_pawn_moved_event_script_path_is_in_domain_events() -> void:
	var event := PawnMovedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PawnMovedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 2),
			CellId.from_grid(8, 5),
			PawnZone.MAIN_PATH)
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PawnMovedEvent payload")
	assert_false(d.has("path_index"), "path_index е в PawnState, не в PawnMoved payload")
	assert_false(d.has("player_id"), "player_id се извежда от pawn_id, не е отделно поле")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var from_cell := CellId.from_grid(8, 2)
	var to_cell := CellId.from_grid(7, 2)
	var event := PawnMovedEvent.new(pawn, from_cell, to_cell, PawnZone.MAIN_PATH)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.to_cell_id, to_cell)
	assert_eq(event.zone, PawnZone.MAIN_PATH)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_true(event.is_on_main_path())
	assert_eq(event.get_player_id(), PlayerId.GREEN)


func test_init_defaults_still_sets_event_type() -> void:
	var event := PawnMovedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.to_cell_id, &"")
	assert_eq(event.zone, PawnZone.BASE)
	assert_false(event.is_valid(),
			"PawnMoved без pawn_id/клетки не е валиден факт")


func test_create_moved_sets_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.CYAN, 0)
	var from_cell := CellId.from_grid(2, 8)
	var to_cell := CellId.from_grid(5, 8)
	var event := PawnMovedEvent.create_moved(
			pawn, from_cell, to_cell, PawnZone.MAIN_PATH, 1)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.to_cell_id, to_cell)
	assert_eq(event.zone, PawnZone.MAIN_PATH)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_from_states_copies_transition() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 2)
	var before := PawnState.create_at_spawn(pawn, CellId.from_grid(6, 13))
	var after := PawnState.create(
			pawn, PawnZone.MAIN_PATH, 3, CellId.from_grid(6, 10), 0)
	var event := PawnMovedEvent.create_from_states(before, after, 2)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.to_cell_id, after.cell_id)
	assert_eq(event.zone, after.zone)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_states_rejects_mismatched_or_null() -> void:
	var yellow := PawnId.for_player(PlayerId.YELLOW, 0)
	var green := PawnId.for_player(PlayerId.GREEN, 0)
	var before := PawnState.create_at_spawn(yellow, CellId.from_grid(8, 2))
	var after_other := PawnState.create_at_spawn(green, CellId.from_grid(8, 5))
	var mismatched := PawnMovedEvent.create_from_states(before, after_other, 1)
	assert_false(mismatched.is_valid())
	assert_false(PawnMovedEvent.create_from_states(null, before).is_valid())
	assert_false(PawnMovedEvent.create_from_states(before, null).is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 2),
			CellId.from_grid(8, 4),
			PawnZone.MAIN_PATH)
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_pawn_id() -> void:
	var event := PawnMovedEvent.new(
			&"", CellId.from_grid(1, 1), CellId.from_grid(1, 2), PawnZone.MAIN_PATH)
	assert_false(event.is_valid(),
			"PawnMoved без pawn_id не е валиден факт")


func test_is_valid_rejects_unknown_pawn_id() -> void:
	var event := PawnMovedEvent.create_moved(
			&"purple_0",
			CellId.from_grid(1, 1),
			CellId.from_grid(1, 2),
			PawnZone.MAIN_PATH,
			1)
	assert_false(event.is_valid())


func test_is_valid_rejects_invalid_cells() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var bad_from := PawnMovedEvent.new(
			pawn, &"not_a_cell", CellId.from_grid(1, 2), PawnZone.MAIN_PATH)
	var bad_to := PawnMovedEvent.new(
			pawn, CellId.from_grid(1, 1), &"x_0_0", PawnZone.MAIN_PATH)
	assert_false(bad_from.is_valid())
	assert_false(bad_to.is_valid())


func test_is_valid_rejects_same_from_and_to() -> void:
	var cell := CellId.from_grid(4, 4)
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.YELLOW, 1),
			cell,
			cell,
			PawnZone.MAIN_PATH,
			1)
	assert_false(event.is_valid(),
			"PawnMoved с from == to не описва преместване")


func test_is_valid_rejects_invalid_zone() -> void:
	var event := PawnMovedEvent.new(
			PawnId.for_player(PlayerId.CYAN, 0),
			CellId.from_grid(2, 2),
			CellId.from_grid(3, 2),
			99)
	assert_false(event.is_valid())


func test_is_valid_rejects_finished_zone() -> void:
	# V1.1: FINISHED е чисто флаг-превключване без движение (PawnFinishedEvent) —
	# PawnMoved никога не описва преход към FINISHED, дори с различна to клетка.
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.GREEN, 3),
			CellId.from_grid(7, 6),
			CellId.from_grid(7, 5),
			PawnZone.FINISHED,
			1)
	assert_false(event.is_valid(),
			"PawnMoved не трябва никога да сочи zone=FINISHED")


func test_is_valid_accepts_all_movable_zones_except_same_cell() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 0)
	var from_cell := CellId.from_grid(6, 13)
	var cases := [
		[PawnZone.BASE, CellId.from_grid(12, 12)],
		[PawnZone.MAIN_PATH, CellId.from_grid(6, 10)],
		[PawnZone.HOME_STRETCH, CellId.from_grid(7, 11)],
	]
	for entry in cases:
		var event := PawnMovedEvent.create_moved(
				pawn, from_cell, entry[1], entry[0], 1)
		assert_true(event.is_valid(),
				"zone %s трябва да е валидна с различна to клетка" % str(entry[0]))


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 2),
			CellId.from_grid(8, 3),
			PawnZone.MAIN_PATH,
			-1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(8, 2),
			CellId.from_grid(8, 3),
			PawnZone.MAIN_PATH)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PawnMoved може да е валиден преди stamp на command_sequence")


func test_get_player_id_and_zone_helpers() -> void:
	var main := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.CYAN, 2),
			CellId.from_grid(1, 1),
			CellId.from_grid(2, 1),
			PawnZone.MAIN_PATH)
	assert_eq(main.get_player_id(), PlayerId.CYAN)
	assert_true(main.is_on_main_path())
	assert_false(main.is_finished())
	var finished := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.CYAN, 2),
			CellId.from_grid(7, 6),
			CellId.CENTER,
			PawnZone.FINISHED)
	assert_true(finished.is_finished())
	assert_false(finished.is_on_main_path())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell := CellId.from_grid(8, 2)
	var to_cell := CellId.from_grid(8, 5)
	var event := PawnMovedEvent.create_moved(
			pawn, from_cell, to_cell, PawnZone.MAIN_PATH, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("pawn_id"))
	assert_true(d.has("from_cell_id"))
	assert_true(d.has("to_cell_id"))
	assert_true(d.has("zone"))
	assert_eq(d["event_type"], "PawnMoved")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["pawn_id"], "yellow_0")
	assert_eq(d["from_cell_id"], String(from_cell))
	assert_eq(d["to_cell_id"], String(to_cell))
	assert_eq(d["zone"], PawnZone.MAIN_PATH)
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["pawn_id"]), TYPE_STRING)
	assert_eq(typeof(d["from_cell_id"]), TYPE_STRING)
	assert_eq(typeof(d["to_cell_id"]), TYPE_STRING)
	assert_eq(typeof(d["zone"]), TYPE_INT)


func test_from_dict_round_trip() -> void:
	var original := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.CYAN, 3),
			CellId.from_grid(2, 8),
			CellId.from_grid(4, 8),
			PawnZone.HOME_STRETCH,
			4)
	var restored := PawnMovedEvent.from_moved_dict(original.to_dict())
	assert_true(restored is PawnMovedEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.pawn_id, original.pawn_id)
	assert_eq(restored.from_cell_id, original.from_cell_id)
	assert_eq(restored.to_cell_id, original.to_cell_id)
	assert_eq(restored.zone, PawnZone.HOME_STRETCH)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := PawnMovedEvent.from_moved_dict({})
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.to_cell_id, &"")
	assert_eq(event.zone, PawnZone.BASE)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"pawn_id": "green_0",
		"from_cell_id": "c_8_2",
		"to_cell_id": "c_8_5",
		"zone": PawnZone.MAIN_PATH,
	}
	var event := PawnMovedEvent.from_moved_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED,
			"from_moved_dict трябва да форсира TYPE_PAWN_MOVED")


func test_duplicate_event_is_independent() -> void:
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.ORANGE, 1),
			CellId.from_grid(6, 13),
			CellId.from_grid(6, 10),
			PawnZone.MAIN_PATH,
			1)
	var copy := event.duplicate_event() as PawnMovedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.to_cell_id = CellId.from_grid(6, 8)
	copy.zone = PawnZone.HOME_STRETCH
	copy.stamp(9)
	copy.pawn_id = PawnId.for_player(PlayerId.GREEN, 0)
	assert_eq(event.to_cell_id, CellId.from_grid(6, 10),
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.pawn_id, PawnId.for_player(PlayerId.ORANGE, 1))
	assert_eq(event.zone, PawnZone.MAIN_PATH)
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell := CellId.from_grid(8, 2)
	var to_cell := CellId.from_grid(8, 4)
	var a := PawnMovedEvent.create_moved(
			pawn, from_cell, to_cell, PawnZone.MAIN_PATH, 1)
	var b := PawnMovedEvent.create_moved(
			pawn, from_cell, to_cell, PawnZone.MAIN_PATH, 1)
	var c := PawnMovedEvent.create_moved(
			pawn, from_cell, to_cell, PawnZone.MAIN_PATH, 2)
	var d := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.YELLOW, 0),
			from_cell, to_cell, PawnZone.MAIN_PATH, 1)
	var e := PawnMovedEvent.create_moved(
			pawn, from_cell, CellId.from_grid(8, 5), PawnZone.MAIN_PATH, 1)
	var f := PawnMovedEvent.create_moved(
			pawn, from_cell, to_cell, PawnZone.HOME_STRETCH, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(f))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PAWN_MOVED, 1)))


# ── Договор с PawnState / MovePawnCommand ─────────────────────────────────────

func test_payload_matches_pawn_state_transition() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var before := PawnState.create_in_base(pawn, CellId.from_grid(13, 13))
	var after := PawnState.create_at_spawn(pawn, CellId.from_grid(8, 13))
	var event := PawnMovedEvent.create_from_states(before, after, 1)
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, after.pawn_id)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.to_cell_id, after.cell_id)
	assert_eq(event.zone, after.zone)
	assert_true(event.is_on_main_path())
	assert_true(after.is_on_main_path())


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PAWN_MOVED, &"PawnMoved")
	var event := PawnMovedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_event_carries_destination_unlike_move_command() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var cmd := MovePawnCommand.new(PlayerId.GREEN, pawn)
	var event := PawnMovedEvent.create_moved(
			pawn,
			CellId.from_grid(8, 2),
			CellId.from_grid(8, 5),
			PawnZone.MAIN_PATH,
			1)
	assert_false(cmd.to_dict().has("to_cell_id"),
			"MovePawnCommand носи намерение, не дестинация")
	assert_false(cmd.to_dict().has("from_cell_id"))
	assert_true(event.to_dict().has("to_cell_id"),
			"PawnMoved носи факта от GameEngine движението")
	assert_eq(event.to_cell_id, CellId.from_grid(8, 5))
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, cmd.pawn_id)
