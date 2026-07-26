class_name PawnStackFormedEventTest
extends TestCase
## Unit тестове за PawnStackFormedEvent (Task #76 / docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.2 — купчина от 2 свои пионки, имунна срещу взимане).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: cell_id + arriving_pawn_id + resident_pawn_id;
##     event_type = TYPE_PAWN_STACK_FORMED.
##   - Фабрики create_stack_formed / create_from_states; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + CellId + два валидни PawnId на един играч.
##   - Сериализация to_dict / from_stack_formed_dict / equals / duplicate_event.
##   - Събитието описва факт (купчина), не намерение (§4.3 / §6.2).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_pawn_stack_formed_event_extends_domain_event() -> void:
	var event := PawnStackFormedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PawnStackFormedEvent трябва да extends RefCounted чрез DomainEvent")


func test_pawn_stack_formed_event_is_not_node() -> void:
	var event: Object = PawnStackFormedEvent.new()
	assert_false(event is Node,
			"PawnStackFormedEvent не трябва да extends Node — domain слой е без сцени")


func test_pawn_stack_formed_event_script_path_is_in_domain_events() -> void:
	var event := PawnStackFormedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PawnStackFormedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 1))
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PawnStackFormedEvent payload")
	assert_false(d.has("from_cell_id"), "from_cell_id е в PawnMoved, не тук")
	assert_false(d.has("to_cell_id"), "to_cell_id е в PawnMoved, не тук")
	assert_false(d.has("player_id"), "player_id се извежда от pawn_id, не е отделно поле")
	assert_false(d.has("pawn_id"), "payload ползва arriving/resident_pawn_id")
	assert_false(d.has("capturing_pawn_id"), "capture pair е в PawnCaptured, не тук")
	assert_false(d.has("captured_pawn_id"), "capture pair е в PawnCaptured, не тук")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var cell := CellId.from_grid(8, 5)
	var arriving := PawnId.for_player(PlayerId.YELLOW, 0)
	var resident := PawnId.for_player(PlayerId.YELLOW, 2)
	var event := PawnStackFormedEvent.new(cell, arriving, resident)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_eq(event.cell_id, cell)
	assert_eq(event.arriving_pawn_id, arriving)
	assert_eq(event.resident_pawn_id, resident)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.get_player_id(), PlayerId.YELLOW)


func test_init_defaults_still_sets_event_type() -> void:
	var event := PawnStackFormedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_eq(event.cell_id, &"")
	assert_eq(event.arriving_pawn_id, &"")
	assert_eq(event.resident_pawn_id, &"")
	assert_false(event.is_valid(),
			"PawnStackFormed без cell/pawn_id не е валиден факт")


func test_create_stack_formed_sets_envelope_and_payload() -> void:
	var cell := CellId.from_grid(6, 8)
	var arriving := PawnId.for_player(PlayerId.CYAN, 1)
	var resident := PawnId.for_player(PlayerId.CYAN, 0)
	var event := PawnStackFormedEvent.create_stack_formed(
			cell, arriving, resident, 1)
	assert_eq(event.cell_id, cell)
	assert_eq(event.arriving_pawn_id, arriving)
	assert_eq(event.resident_pawn_id, resident)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_from_states_copies_stack_pair() -> void:
	var cell := CellId.from_grid(8, 5)
	var arriving := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnZone.MAIN_PATH, 4, cell, 0)
	var resident := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 1),
			PawnZone.MAIN_PATH, 12, cell, 0)
	var event := PawnStackFormedEvent.create_from_states(arriving, resident, 2)
	assert_eq(event.cell_id, cell)
	assert_eq(event.arriving_pawn_id, arriving.pawn_id)
	assert_eq(event.resident_pawn_id, resident.pawn_id)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_states_rejects_invalid_stack_setup() -> void:
	var cell := CellId.from_grid(8, 5)
	var yellow_a := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnZone.MAIN_PATH, 4, cell, 0)
	var yellow_b := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 1),
			PawnZone.MAIN_PATH, 3, cell, 0)
	var green := PawnState.create(
			PawnId.for_player(PlayerId.GREEN, 0),
			PawnZone.MAIN_PATH, 12, cell, 0)
	var yellow_elsewhere := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 1),
			PawnZone.MAIN_PATH, 10, CellId.from_grid(8, 2), 0)
	var yellow_home := PawnState.create(
			PawnId.for_player(PlayerId.YELLOW, 1),
			PawnZone.HOME_STRETCH, 1, CellId.from_grid(7, 11), 0)
	assert_false(PawnStackFormedEvent.create_from_states(null, yellow_b).is_valid())
	assert_false(PawnStackFormedEvent.create_from_states(yellow_a, null).is_valid())
	assert_false(PawnStackFormedEvent.create_from_states(yellow_a, yellow_a).is_valid(),
			"същата пионка не е купчина")
	assert_false(PawnStackFormedEvent.create_from_states(yellow_a, green).is_valid(),
			"купчина е само от свои пионки")
	assert_false(PawnStackFormedEvent.create_from_states(yellow_a, yellow_elsewhere).is_valid(),
			"купчина изисква една и съща клетка")
	assert_false(PawnStackFormedEvent.create_from_states(yellow_a, yellow_home).is_valid(),
			"home stretch не е MAIN_PATH stack факт")
	assert_true(PawnStackFormedEvent.create_from_states(yellow_a, yellow_b).is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 1))
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_fields() -> void:
	var cell := CellId.from_grid(8, 5)
	var arriving := PawnId.for_player(PlayerId.YELLOW, 0)
	var resident := PawnId.for_player(PlayerId.YELLOW, 1)
	assert_false(PawnStackFormedEvent.new(&"", arriving, resident).is_valid())
	assert_false(PawnStackFormedEvent.new(cell, &"", resident).is_valid())
	assert_false(PawnStackFormedEvent.new(cell, arriving, &"").is_valid())


func test_is_valid_rejects_unknown_pawn_ids() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			&"purple_0",
			PawnId.for_player(PlayerId.YELLOW, 0),
			1)
	assert_false(event.is_valid())


func test_is_valid_rejects_same_pawn() -> void:
	var pawn := PawnId.for_player(PlayerId.YELLOW, 0)
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5), pawn, pawn, 1)
	assert_false(event.is_valid(),
			"PawnStackFormed със същия pawn_id не описва купчина от 2")


func test_is_valid_rejects_different_players() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.GREEN, 0),
			1)
	assert_false(event.is_valid(),
			"купчина е само от пионки на един и същ играч")


func test_is_valid_accepts_all_seats() -> void:
	var seats := [PlayerId.YELLOW, PlayerId.GREEN, PlayerId.CYAN, PlayerId.ORANGE]
	for seat in seats:
		var event := PawnStackFormedEvent.create_stack_formed(
				CellId.from_grid(8, 5),
				PawnId.for_player(seat, 0),
				PawnId.for_player(seat, 1),
				1)
		assert_true(event.is_valid(),
				"купчина за %s трябва да е валидна" % seat)


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 1),
			-1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.YELLOW, 1))
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PawnStackFormed може да е валиден преди stamp на command_sequence")


func test_player_id_helper() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(6, 8),
			PawnId.for_player(PlayerId.ORANGE, 2),
			PawnId.for_player(PlayerId.ORANGE, 3))
	assert_eq(event.get_player_id(), PlayerId.ORANGE)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var cell := CellId.from_grid(8, 5)
	var arriving := PawnId.for_player(PlayerId.YELLOW, 0)
	var resident := PawnId.for_player(PlayerId.YELLOW, 1)
	var event := PawnStackFormedEvent.create_stack_formed(
			cell, arriving, resident, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("cell_id"))
	assert_true(d.has("arriving_pawn_id"))
	assert_true(d.has("resident_pawn_id"))
	assert_eq(d["event_type"], "PawnStackFormed")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["cell_id"], String(cell))
	assert_eq(d["arriving_pawn_id"], "yellow_0")
	assert_eq(d["resident_pawn_id"], "yellow_1")
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["cell_id"]), TYPE_STRING)
	assert_eq(typeof(d["arriving_pawn_id"]), TYPE_STRING)
	assert_eq(typeof(d["resident_pawn_id"]), TYPE_STRING)


func test_from_dict_round_trip() -> void:
	var original := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(6, 8),
			PawnId.for_player(PlayerId.CYAN, 3),
			PawnId.for_player(PlayerId.CYAN, 0),
			4)
	var restored := PawnStackFormedEvent.from_stack_formed_dict(original.to_dict())
	assert_true(restored is PawnStackFormedEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.cell_id, original.cell_id)
	assert_eq(restored.arriving_pawn_id, original.arriving_pawn_id)
	assert_eq(restored.resident_pawn_id, original.resident_pawn_id)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := PawnStackFormedEvent.from_stack_formed_dict({})
	assert_eq(event.cell_id, &"")
	assert_eq(event.arriving_pawn_id, &"")
	assert_eq(event.resident_pawn_id, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"cell_id": "c_8_5",
		"arriving_pawn_id": "green_0",
		"resident_pawn_id": "green_1",
	}
	var event := PawnStackFormedEvent.from_stack_formed_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED,
			"from_stack_formed_dict трябва да форсира TYPE_PAWN_STACK_FORMED")


func test_duplicate_event_is_independent() -> void:
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5),
			PawnId.for_player(PlayerId.ORANGE, 1),
			PawnId.for_player(PlayerId.ORANGE, 2),
			1)
	var copy := event.duplicate_event() as PawnStackFormedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.resident_pawn_id = PawnId.for_player(PlayerId.ORANGE, 0)
	copy.stamp(9)
	copy.arriving_pawn_id = PawnId.for_player(PlayerId.YELLOW, 0)
	assert_eq(event.resident_pawn_id, PawnId.for_player(PlayerId.ORANGE, 2),
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.arriving_pawn_id, PawnId.for_player(PlayerId.ORANGE, 1))
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var cell := CellId.from_grid(8, 5)
	var arriving := PawnId.for_player(PlayerId.GREEN, 0)
	var resident := PawnId.for_player(PlayerId.GREEN, 1)
	var a := PawnStackFormedEvent.create_stack_formed(cell, arriving, resident, 1)
	var b := PawnStackFormedEvent.create_stack_formed(cell, arriving, resident, 1)
	var c := PawnStackFormedEvent.create_stack_formed(cell, arriving, resident, 2)
	var d := PawnStackFormedEvent.create_stack_formed(
			cell, PawnId.for_player(PlayerId.GREEN, 2), resident, 1)
	var e := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 2), arriving, resident, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PAWN_STACK_FORMED, 1)))


# ── Договор с MovePawnCommand / sibling events ─────────────────────────────────

func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PAWN_STACK_FORMED, &"PawnStackFormed")
	var event := PawnStackFormedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_event_carries_stack_pair_unlike_move_command() -> void:
	var arriving := PawnId.for_player(PlayerId.GREEN, 1)
	var resident := PawnId.for_player(PlayerId.GREEN, 0)
	var cmd := MovePawnCommand.new(PlayerId.GREEN, arriving)
	var event := PawnStackFormedEvent.create_stack_formed(
			CellId.from_grid(8, 5), arriving, resident, 1)
	assert_false(cmd.to_dict().has("arriving_pawn_id"),
			"MovePawnCommand носи намерение, не stack резултат")
	assert_false(cmd.to_dict().has("resident_pawn_id"))
	assert_false(cmd.to_dict().has("cell_id"))
	assert_true(event.to_dict().has("resident_pawn_id"),
			"PawnStackFormed носи факта от GameEngine купчината")
	assert_eq(event.arriving_pawn_id, cmd.pawn_id)
	assert_true(cmd.is_valid())
	assert_true(event.is_valid())


func test_distinct_from_pawn_moved_and_captured() -> void:
	var arriving := PawnId.for_player(PlayerId.YELLOW, 0)
	var resident := PawnId.for_player(PlayerId.YELLOW, 1)
	var cell_from := CellId.from_grid(8, 2)
	var cell_to := CellId.from_grid(8, 5)
	var stack := PawnStackFormedEvent.create_stack_formed(
			cell_to, arriving, resident, 1)
	var moved := PawnMovedEvent.create_moved(
			arriving, cell_from, cell_to, PawnZone.MAIN_PATH, 1)
	var captured := PawnCapturedEvent.create_captured(
			arriving, PawnId.for_player(PlayerId.GREEN, 0), 1)
	assert_eq(stack.event_type, DomainEvent.TYPE_PAWN_STACK_FORMED)
	assert_eq(moved.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_eq(captured.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_false(stack.equals(moved))
	assert_false(stack.equals(captured))
	assert_true(stack.is_valid())
	assert_true(moved.is_valid())
	assert_true(captured.is_valid())
