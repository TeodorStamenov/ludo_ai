class_name PawnFinishedEventTest
extends TestCase
## Unit тестове за PawnFinishedEvent (Task #77 / docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 / §3.2 — прибиране в центъра от home stretch).
##
## Покрива критични инварианти на факта:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: pawn_id + from_cell_id + center_cell_id (== CellId.CENTER).
##   - create_from_states: само HOME_STRETCH → FINISHED.
##   - is_valid(): from ≠ center и center е винаги CellId.CENTER.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_finished_event_extends_domain_event() -> void:
	var event := PawnFinishedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PawnFinishedEvent трябва да extends RefCounted чрез DomainEvent")


func test_pawn_finished_event_is_not_node() -> void:
	var event: Object = PawnFinishedEvent.new()
	assert_false(event is Node,
			"PawnFinishedEvent не трябва да extends Node — domain слой е без сцени")


func test_pawn_finished_event_script_path_is_in_domain_events() -> void:
	var event := PawnFinishedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PawnFinishedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 0),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER)
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PawnFinishedEvent payload")
	assert_false(d.has("path_index"), "path_index е в PawnState, не в PawnFinished payload")
	assert_false(d.has("zone"), "zone след прибиране е винаги FINISHED — не е отделно поле")
	assert_false(d.has("player_id"), "player_id се извежда от pawn_id, не е отделно поле")
	assert_false(d.has("to_cell_id"), "дестинацията е center_cell_id, не to_cell_id")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.GREEN)[3]
	var event := PawnFinishedEvent.new(pawn, from_cell, CellId.CENTER)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.center_cell_id, CellId.CENTER)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.get_player_id(), PlayerId.GREEN)


func test_init_defaults_still_sets_event_type() -> void:
	var event := PawnFinishedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.center_cell_id, &"")
	assert_false(event.is_valid(),
			"PawnFinished без pawn_id/клетки не е валиден факт")


func test_create_finished_sets_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.CYAN, 0)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.CYAN)[3]
	var event := PawnFinishedEvent.create_finished(pawn, from_cell, CellId.CENTER, 1)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.center_cell_id, CellId.CENTER)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_from_states_copies_finish_transition() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 2)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.ORANGE)[3]
	var before := PawnState.create(
			pawn, PawnZone.HOME_STRETCH, Classic15x15Board.PLAYER_ROUTE_LENGTH - 1, from_cell, 0)
	var after := PawnState.create_finished(pawn, Classic15x15Board.PLAYER_ROUTE_LENGTH)
	var event := PawnFinishedEvent.create_from_states(before, after, 2)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.center_cell_id, after.cell_id)
	assert_eq(event.center_cell_id, CellId.CENTER)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_states_rejects_mismatched_null_or_non_finish() -> void:
	var yellow := PawnId.for_player(PlayerId.YELLOW, 0)
	var green := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3]
	var before := PawnState.create(
			yellow, PawnZone.HOME_STRETCH, Classic15x15Board.PLAYER_ROUTE_LENGTH - 1, from_cell, 0)
	var after_finished := PawnState.create_finished(
			yellow, Classic15x15Board.PLAYER_ROUTE_LENGTH)
	var after_other := PawnState.create_finished(
			green, Classic15x15Board.PLAYER_ROUTE_LENGTH)
	var on_path := PawnState.create(
			yellow, PawnZone.MAIN_PATH, 3, CellId.from_grid(6, 10), 0)
	var still_home := PawnState.create(
			yellow, PawnZone.HOME_STRETCH, Classic15x15Board.PLAYER_ROUTE_LENGTH - 2,
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[2], 0)
	assert_false(PawnFinishedEvent.create_from_states(before, after_other, 1).is_valid())
	assert_false(PawnFinishedEvent.create_from_states(null, after_finished).is_valid())
	assert_false(PawnFinishedEvent.create_from_states(before, null).is_valid())
	assert_false(PawnFinishedEvent.create_from_states(after_finished, before).is_valid(),
			"обратен преход FINISHED→HOME не е PawnFinished")
	assert_false(PawnFinishedEvent.create_from_states(on_path, after_finished).is_valid(),
			"finish само от HOME_STRETCH")
	assert_false(PawnFinishedEvent.create_from_states(before, still_home).is_valid(),
			"after трябва да е FINISHED")


func test_stamp_uses_base_envelope() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 0),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER)
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_pawn_id() -> void:
	var event := PawnFinishedEvent.new(
			&"",
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER)
	assert_false(event.is_valid(),
			"PawnFinished без pawn_id не е валиден факт")


func test_is_valid_rejects_unknown_pawn_id() -> void:
	var event := PawnFinishedEvent.create_finished(
			&"purple_0",
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER,
			1)
	assert_false(event.is_valid())


func test_is_valid_rejects_invalid_cells() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var bad_from := PawnFinishedEvent.new(pawn, &"not_a_cell", CellId.CENTER)
	var bad_center := PawnFinishedEvent.new(
			pawn, Classic15x15Board.home_stretch_cells_for(PlayerId.GREEN)[3], &"x_0_0")
	assert_false(bad_from.is_valid())
	assert_false(bad_center.is_valid())


func test_is_valid_rejects_non_center_destination() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 1),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.from_grid(7, 8),
			1)
	assert_false(event.is_valid(),
			"PawnFinished дестинацията трябва да е CellId.CENTER")


func test_is_valid_rejects_same_from_and_center() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 1),
			CellId.CENTER,
			CellId.CENTER,
			1)
	assert_false(event.is_valid(),
			"PawnFinished с from == center не описва прибиране")


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 0),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER,
			-1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 0),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PawnFinished може да е валиден преди stamp на command_sequence")


func test_get_player_id() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.CYAN, 2),
			Classic15x15Board.home_stretch_cells_for(PlayerId.CYAN)[3],
			CellId.CENTER)
	assert_eq(event.get_player_id(), PlayerId.CYAN)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3]
	var event := PawnFinishedEvent.create_finished(pawn, from_cell, CellId.CENTER, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("pawn_id"))
	assert_true(d.has("from_cell_id"))
	assert_true(d.has("center_cell_id"))
	assert_eq(d["event_type"], "PawnFinished")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["pawn_id"], "yellow_0")
	assert_eq(d["from_cell_id"], String(from_cell))
	assert_eq(d["center_cell_id"], String(CellId.CENTER))
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["pawn_id"]), TYPE_STRING)
	assert_eq(typeof(d["from_cell_id"]), TYPE_STRING)
	assert_eq(typeof(d["center_cell_id"]), TYPE_STRING)


func test_from_dict_round_trip() -> void:
	var original := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.CYAN, 3),
			Classic15x15Board.home_stretch_cells_for(PlayerId.CYAN)[3],
			CellId.CENTER,
			4)
	var restored := PawnFinishedEvent.from_finished_dict(original.to_dict())
	assert_true(restored is PawnFinishedEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.pawn_id, original.pawn_id)
	assert_eq(restored.from_cell_id, original.from_cell_id)
	assert_eq(restored.center_cell_id, original.center_cell_id)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := PawnFinishedEvent.from_finished_dict({})
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.center_cell_id, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"pawn_id": "green_0",
		"from_cell_id": "c_7_6",
		"center_cell_id": "c_7_7",
	}
	var event := PawnFinishedEvent.from_finished_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED,
			"from_finished_dict трябва да форсира TYPE_PAWN_FINISHED")


func test_duplicate_event_is_independent() -> void:
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.ORANGE)[3]
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.ORANGE, 1),
			from_cell,
			CellId.CENTER,
			1)
	var copy := event.duplicate_event() as PawnFinishedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.center_cell_id = CellId.from_grid(1, 1)
	copy.stamp(9)
	copy.pawn_id = PawnId.for_player(PlayerId.GREEN, 0)
	assert_eq(event.center_cell_id, CellId.CENTER,
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.pawn_id, PawnId.for_player(PlayerId.ORANGE, 1))
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.GREEN)[3]
	var a := PawnFinishedEvent.create_finished(pawn, from_cell, CellId.CENTER, 1)
	var b := PawnFinishedEvent.create_finished(pawn, from_cell, CellId.CENTER, 1)
	var c := PawnFinishedEvent.create_finished(pawn, from_cell, CellId.CENTER, 2)
	var d := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 0), from_cell, CellId.CENTER, 1)
	var e := PawnFinishedEvent.create_finished(
			pawn, Classic15x15Board.home_stretch_cells_for(PlayerId.GREEN)[2], CellId.CENTER, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PAWN_FINISHED, 1)))


# ── Договор с PawnState / MovePawnCommand / mark_finished ──────────────────────

func test_payload_matches_mark_finished() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3]
	var before := PawnState.create(
			pawn, PawnZone.HOME_STRETCH, Classic15x15Board.PLAYER_ROUTE_LENGTH - 1, from_cell, 1)
	var after := before.duplicate_state()
	after.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH)
	var event := PawnFinishedEvent.create_from_states(before, after, 1)
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, after.pawn_id)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.center_cell_id, after.cell_id)
	assert_eq(after.cell_id, CellId.CENTER)
	assert_true(after.is_finished())
	assert_eq(after.shield_turns_remaining, 0)
	assert_true(before.is_in_home_stretch())


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PAWN_FINISHED, &"PawnFinished")
	var event := PawnFinishedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_distinct_from_pawn_moved_event_type() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell: StringName = Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3]
	var finished := PawnFinishedEvent.create_finished(pawn, from_cell, CellId.CENTER, 1)
	var moved := PawnMovedEvent.create_moved(
			pawn, from_cell, CellId.CENTER, PawnZone.FINISHED, 1)
	assert_eq(finished.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_eq(moved.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_false(finished.equals(moved))
	assert_true(finished.is_valid())
	assert_true(moved.is_valid())
	assert_true(moved.is_finished())


func test_event_carries_center_unlike_move_command() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var cmd := MovePawnCommand.new(PlayerId.GREEN, pawn)
	var event := PawnFinishedEvent.create_finished(
			pawn,
			Classic15x15Board.home_stretch_cells_for(PlayerId.GREEN)[3],
			CellId.CENTER,
			1)
	assert_false(cmd.to_dict().has("center_cell_id"),
			"MovePawnCommand носи намерение, не center дестинация")
	assert_false(cmd.to_dict().has("from_cell_id"))
	assert_true(event.to_dict().has("center_cell_id"),
			"PawnFinished носи факта от GameEngine прибирането")
	assert_eq(event.center_cell_id, CellId.CENTER)
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, cmd.pawn_id)
