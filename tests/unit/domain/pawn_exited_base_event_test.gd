class_name PawnExitedBaseEventTest
extends TestCase
## Unit тестове за PawnExitedBaseEvent (Task #73 / docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/CURRENT_YELLOW_BEHAVIOR.md, YEL-030).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: pawn_id + from_cell_id + spawn_cell_id; event_type = TYPE_PAWN_EXITED_BASE.
##   - Фабрики create_exited / create_from_states; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + PawnId + CellId; from ≠ spawn.
##   - Сериализация to_dict / from_exited_dict / equals / duplicate_event.
##   - Събитието описва факт (излизане на spawn), не намерение (§4.3 / §6.2).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_exited_base_event_extends_domain_event() -> void:
	var event := PawnExitedBaseEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PawnExitedBaseEvent трябва да extends RefCounted чрез DomainEvent")


func test_pawn_exited_base_event_is_not_node() -> void:
	var event: Object = PawnExitedBaseEvent.new()
	assert_false(event is Node,
			"PawnExitedBaseEvent не трябва да extends Node — domain слой е без сцени")


func test_pawn_exited_base_event_script_path_is_in_domain_events() -> void:
	var event := PawnExitedBaseEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PawnExitedBaseEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(13, 13),
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PawnExitedBaseEvent payload")
	assert_false(d.has("path_index"), "path_index е в PawnState, не в PawnExitedBase payload")
	assert_false(d.has("zone"), "zone след излизане е винаги MAIN_PATH — не е отделно поле")
	assert_false(d.has("player_id"), "player_id се извежда от pawn_id, не е отделно поле")
	assert_false(d.has("to_cell_id"), "дестинацията е spawn_cell_id, не to_cell_id")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var from_cell := CellId.from_grid(2, 2)
	var spawn_cell := Classic15x15Board.spawn_cell_for(PlayerId.GREEN)
	var event := PawnExitedBaseEvent.new(pawn, from_cell, spawn_cell)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.spawn_cell_id, spawn_cell)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.get_player_id(), PlayerId.GREEN)


func test_init_defaults_still_sets_event_type() -> void:
	var event := PawnExitedBaseEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.spawn_cell_id, &"")
	assert_false(event.is_valid(),
			"PawnExitedBase без pawn_id/клетки не е валиден факт")


func test_create_exited_sets_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.CYAN, 0)
	var from_cell := CellId.from_grid(1, 1)
	var spawn_cell := Classic15x15Board.spawn_cell_for(PlayerId.CYAN)
	var event := PawnExitedBaseEvent.create_exited(pawn, from_cell, spawn_cell, 1)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, from_cell)
	assert_eq(event.spawn_cell_id, spawn_cell)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_from_states_copies_exit_transition() -> void:
	var pawn := PawnId.for_player(PlayerId.ORANGE, 2)
	var before := PawnState.create_in_base(pawn, CellId.from_grid(12, 12))
	var after := PawnState.create_at_spawn(
			pawn, Classic15x15Board.spawn_cell_for(PlayerId.ORANGE))
	var event := PawnExitedBaseEvent.create_from_states(before, after, 2)
	assert_eq(event.pawn_id, pawn)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.spawn_cell_id, after.cell_id)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_states_rejects_mismatched_null_or_non_exit() -> void:
	var yellow := PawnId.for_player(PlayerId.YELLOW, 0)
	var green := PawnId.for_player(PlayerId.GREEN, 0)
	var before := PawnState.create_in_base(yellow, CellId.from_grid(13, 13))
	var after_spawn := PawnState.create_at_spawn(
			yellow, Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	var after_other := PawnState.create_at_spawn(
			green, Classic15x15Board.spawn_cell_for(PlayerId.GREEN))
	var on_path := PawnState.create(
			yellow, PawnZone.MAIN_PATH, 3, CellId.from_grid(6, 10), 0)
	assert_false(PawnExitedBaseEvent.create_from_states(before, after_other, 1).is_valid())
	assert_false(PawnExitedBaseEvent.create_from_states(null, before).is_valid())
	assert_false(PawnExitedBaseEvent.create_from_states(before, null).is_valid())
	assert_false(PawnExitedBaseEvent.create_from_states(after_spawn, before).is_valid(),
			"обратен преход spawn→base не е PawnExitedBase")
	assert_false(PawnExitedBaseEvent.create_from_states(before, on_path).is_valid(),
			"излизане само към path_index 0 (spawn)")


func test_stamp_uses_base_envelope() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(13, 13),
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_pawn_id() -> void:
	var event := PawnExitedBaseEvent.new(
			&"", CellId.from_grid(1, 1), CellId.from_grid(6, 12))
	assert_false(event.is_valid(),
			"PawnExitedBase без pawn_id не е валиден факт")


func test_is_valid_rejects_unknown_pawn_id() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			&"purple_0",
			CellId.from_grid(1, 1),
			CellId.from_grid(6, 12),
			1)
	assert_false(event.is_valid())


func test_is_valid_rejects_invalid_cells() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var bad_from := PawnExitedBaseEvent.new(
			pawn, &"not_a_cell", CellId.from_grid(1, 2))
	var bad_spawn := PawnExitedBaseEvent.new(
			pawn, CellId.from_grid(1, 1), &"x_0_0")
	assert_false(bad_from.is_valid())
	assert_false(bad_spawn.is_valid())


func test_is_valid_rejects_same_from_and_spawn() -> void:
	var cell := CellId.from_grid(4, 4)
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 1),
			cell,
			cell,
			1)
	assert_false(event.is_valid(),
			"PawnExitedBase с from == spawn не описва излизане")


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(13, 13),
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW),
			-1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(13, 13),
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PawnExitedBase може да е валиден преди stamp на command_sequence")


func test_get_player_id() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.CYAN, 2),
			CellId.from_grid(1, 1),
			Classic15x15Board.spawn_cell_for(PlayerId.CYAN))
	assert_eq(event.get_player_id(), PlayerId.CYAN)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell := CellId.from_grid(13, 13)
	var spawn_cell := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var event := PawnExitedBaseEvent.create_exited(pawn, from_cell, spawn_cell, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("pawn_id"))
	assert_true(d.has("from_cell_id"))
	assert_true(d.has("spawn_cell_id"))
	assert_eq(d["event_type"], "PawnExitedBase")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["pawn_id"], "yellow_0")
	assert_eq(d["from_cell_id"], String(from_cell))
	assert_eq(d["spawn_cell_id"], String(spawn_cell))
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["pawn_id"]), TYPE_STRING)
	assert_eq(typeof(d["from_cell_id"]), TYPE_STRING)
	assert_eq(typeof(d["spawn_cell_id"]), TYPE_STRING)


func test_from_dict_round_trip() -> void:
	var original := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.CYAN, 3),
			CellId.from_grid(2, 2),
			Classic15x15Board.spawn_cell_for(PlayerId.CYAN),
			4)
	var restored := PawnExitedBaseEvent.from_exited_dict(original.to_dict())
	assert_true(restored is PawnExitedBaseEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.pawn_id, original.pawn_id)
	assert_eq(restored.from_cell_id, original.from_cell_id)
	assert_eq(restored.spawn_cell_id, original.spawn_cell_id)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := PawnExitedBaseEvent.from_exited_dict({})
	assert_eq(event.pawn_id, &"")
	assert_eq(event.from_cell_id, &"")
	assert_eq(event.spawn_cell_id, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"pawn_id": "green_0",
		"from_cell_id": "c_2_2",
		"spawn_cell_id": "c_8_2",
	}
	var event := PawnExitedBaseEvent.from_exited_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE,
			"from_exited_dict трябва да форсира TYPE_PAWN_EXITED_BASE")


func test_duplicate_event_is_independent() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.ORANGE, 1),
			CellId.from_grid(12, 12),
			Classic15x15Board.spawn_cell_for(PlayerId.ORANGE),
			1)
	var copy := event.duplicate_event() as PawnExitedBaseEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.spawn_cell_id = CellId.from_grid(6, 8)
	copy.stamp(9)
	copy.pawn_id = PawnId.for_player(PlayerId.GREEN, 0)
	assert_eq(event.spawn_cell_id, Classic15x15Board.spawn_cell_for(PlayerId.ORANGE),
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.pawn_id, PawnId.for_player(PlayerId.ORANGE, 1))
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 0)
	var from_cell := CellId.from_grid(2, 2)
	var spawn_cell := Classic15x15Board.spawn_cell_for(PlayerId.GREEN)
	var a := PawnExitedBaseEvent.create_exited(pawn, from_cell, spawn_cell, 1)
	var b := PawnExitedBaseEvent.create_exited(pawn, from_cell, spawn_cell, 1)
	var c := PawnExitedBaseEvent.create_exited(pawn, from_cell, spawn_cell, 2)
	var d := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 0), from_cell, spawn_cell, 1)
	var e := PawnExitedBaseEvent.create_exited(
			pawn, from_cell, CellId.from_grid(8, 5), 1)
	var f := PawnExitedBaseEvent.create_exited(
			pawn, CellId.from_grid(3, 3), spawn_cell, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(f))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PAWN_EXITED_BASE, 1)))


# ── Договор с PawnState / MovePawnCommand / YEL-030 ────────────────────────────

func test_payload_matches_exit_base_to_spawn() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var base_cell := CellId.from_grid(13, 13)
	var spawn_cell := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var before := PawnState.create_in_base(pawn, base_cell)
	var after := before.duplicate_state()
	after.exit_base_to_spawn(spawn_cell)
	var event := PawnExitedBaseEvent.create_from_states(before, after, 1)
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, after.pawn_id)
	assert_eq(event.from_cell_id, before.cell_id)
	assert_eq(event.spawn_cell_id, after.cell_id)
	assert_eq(after.path_index, PawnState.PATH_INDEX_AT_SPAWN)
	assert_true(after.is_on_main_path())
	assert_true(before.is_in_base())


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PAWN_EXITED_BASE, &"PawnExitedBase")
	var event := PawnExitedBaseEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_event_carries_spawn_unlike_move_command() -> void:
	var pawn := PawnId.for_player(PlayerId.GREEN, 1)
	var cmd := MovePawnCommand.new(PlayerId.GREEN, pawn)
	var event := PawnExitedBaseEvent.create_exited(
			pawn,
			CellId.from_grid(2, 2),
			Classic15x15Board.spawn_cell_for(PlayerId.GREEN),
			1)
	assert_false(cmd.to_dict().has("spawn_cell_id"),
			"MovePawnCommand носи намерение, не spawn дестинация")
	assert_false(cmd.to_dict().has("from_cell_id"))
	assert_true(event.to_dict().has("spawn_cell_id"),
			"PawnExitedBase носи факта от GameEngine излизането")
	assert_eq(event.spawn_cell_id, Classic15x15Board.spawn_cell_for(PlayerId.GREEN))
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())
	assert_eq(event.pawn_id, cmd.pawn_id)


func test_distinct_from_pawn_moved_event_type() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var from_cell := CellId.from_grid(13, 13)
	var spawn_cell := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var exited := PawnExitedBaseEvent.create_exited(pawn, from_cell, spawn_cell, 1)
	var moved := PawnMovedEvent.create_moved(
			pawn, from_cell, spawn_cell, PawnZone.MAIN_PATH, 1)
	assert_eq(exited.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_eq(moved.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_false(exited.equals(moved))
	assert_true(exited.is_valid())
	assert_true(moved.is_valid())
