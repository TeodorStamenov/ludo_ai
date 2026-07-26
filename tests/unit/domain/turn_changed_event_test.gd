class_name TurnChangedEventTest
extends TestCase
## Unit тестове за TurnChangedEvent (Task #78 / docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 — смяна на активен играч; 6/extra turn ≠ TurnChanged).
##
## Покрива критични инварианти на факта:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: previous/new active_player_index + PlayerId.
##   - is_valid(): previous ≠ new; new винаги валиден; NONE само за previous.
##   - create_from_state: чете новия активен играч от GameState.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_turn_changed_event_extends_domain_event() -> void:
	var event := TurnChangedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"TurnChangedEvent трябва да extends RefCounted чрез DomainEvent")


func test_turn_changed_event_is_not_node() -> void:
	var event: Object = TurnChangedEvent.new()
	assert_false(event is Node,
			"TurnChangedEvent не трябва да extends Node — domain слой е без сцени")


func test_turn_changed_event_script_path_is_in_domain_events() -> void:
	var event := TurnChangedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"TurnChangedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, PlayerId.YELLOW)
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от TurnChangedEvent payload")
	assert_false(d.has("turn_label"), "UI текст не е domain payload")
	assert_false(d.has("extra_roll_pending"), "extra roll не е TurnChanged факт")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var event := TurnChangedEvent.new(0, 1, PlayerId.GREEN, PlayerId.YELLOW)
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED)
	assert_eq(event.previous_player_index, 0)
	assert_eq(event.new_player_index, 1)
	assert_eq(event.previous_player_id, PlayerId.GREEN)
	assert_eq(event.new_player_id, PlayerId.YELLOW)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_false(event.is_initial_activation())
	assert_eq(event.get_active_player_id(), PlayerId.YELLOW)


func test_init_defaults_still_sets_event_type() -> void:
	var event := TurnChangedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED)
	assert_eq(event.previous_player_index, TurnChangedEvent.PLAYER_INDEX_NONE)
	assert_eq(event.new_player_index, TurnChangedEvent.PLAYER_INDEX_NONE)
	assert_eq(event.previous_player_id, &"")
	assert_eq(event.new_player_id, &"")
	assert_false(event.is_valid(),
			"TurnChanged без нов активен играч не е валиден факт")


func test_create_changed_sets_envelope_and_payload() -> void:
	var event := TurnChangedEvent.create_changed(
			1, 0, PlayerId.YELLOW, PlayerId.GREEN, 3)
	assert_eq(event.previous_player_index, 1)
	assert_eq(event.new_player_index, 0)
	assert_eq(event.previous_player_id, PlayerId.YELLOW)
	assert_eq(event.new_player_id, PlayerId.GREEN)
	assert_eq(event.command_sequence, 3)
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_create_changed_initial_activation_from_none() -> void:
	var event := TurnChangedEvent.create_changed(
			TurnChangedEvent.PLAYER_INDEX_NONE, 0, &"", PlayerId.GREEN, 1)
	assert_true(event.is_initial_activation())
	assert_true(event.is_valid())
	assert_eq(event.get_active_player_id(), PlayerId.GREEN)


func test_create_from_state_reads_new_active_player() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(2))
	assert_eq(state.active_player_index, 0)
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	state.set_active_player_index(1)
	var event := TurnChangedEvent.create_from_state(state, 0, 2)
	assert_eq(event.previous_player_index, 0)
	assert_eq(event.new_player_index, 1)
	assert_eq(event.previous_player_id, PlayerId.GREEN)
	assert_eq(event.new_player_id, PlayerId.YELLOW)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())


func test_create_from_state_rejects_same_index_or_null() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(2))
	assert_false(TurnChangedEvent.create_from_state(state, 0).is_valid(),
			"същият active_player_index не е смяна на ход")
	assert_false(TurnChangedEvent.create_from_state(null, 0).is_valid())
	state.set_active_player_index(GameState.ACTIVE_PLAYER_NONE)
	assert_false(TurnChangedEvent.create_from_state(state, 0).is_valid(),
			"липсващ нов активен играч → невалиден факт")


func test_stamp_uses_base_envelope() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, PlayerId.YELLOW)
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_same_player_index() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 0, PlayerId.GREEN, PlayerId.YELLOW, 1)
	assert_false(event.is_valid(),
			"TurnChanged изисква previous ≠ new (extra turn не е TurnChanged)")


func test_is_valid_rejects_same_player_id() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, PlayerId.GREEN, 1)
	assert_false(event.is_valid(),
			"смяна към същия PlayerId не описва TurnChanged")


func test_is_valid_rejects_invalid_new_player() -> void:
	var bad_id := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, &"purple", 1)
	var bad_index := TurnChangedEvent.create_changed(
			0, TurnChangedEvent.PLAYER_INDEX_NONE, PlayerId.GREEN, PlayerId.YELLOW, 1)
	assert_false(bad_id.is_valid())
	assert_false(bad_index.is_valid())


func test_is_valid_rejects_previous_id_when_index_none() -> void:
	var event := TurnChangedEvent.create_changed(
			TurnChangedEvent.PLAYER_INDEX_NONE, 0, PlayerId.YELLOW, PlayerId.GREEN, 1)
	assert_false(event.is_valid(),
			"при PLAYER_INDEX_NONE previous_player_id трябва да е празен")


func test_is_valid_rejects_empty_previous_id_when_index_set() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, &"", PlayerId.YELLOW, 1)
	assert_false(event.is_valid())


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, PlayerId.YELLOW, -1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, PlayerId.YELLOW)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"TurnChanged може да е валиден преди stamp на command_sequence")


func test_player_index_none_matches_game_state() -> void:
	assert_eq(TurnChangedEvent.PLAYER_INDEX_NONE, GameState.ACTIVE_PLAYER_NONE)


# ── Сериализация (договор journal / replay) ───────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var event := TurnChangedEvent.create_changed(
			0, 1, PlayerId.GREEN, PlayerId.YELLOW, 2)
	var d := event.to_dict()
	assert_eq(d["event_type"], "TurnChanged")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["previous_player_index"], 0)
	assert_eq(d["new_player_index"], 1)
	assert_eq(d["previous_player_id"], "green")
	assert_eq(d["new_player_id"], "yellow")
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["previous_player_id"]), TYPE_STRING)
	assert_eq(typeof(d["new_player_id"]), TYPE_STRING)


func test_from_dict_round_trip_preserves_fact() -> void:
	var original := TurnChangedEvent.create_changed(
			1, 0, PlayerId.YELLOW, PlayerId.GREEN, 4)
	var restored := TurnChangedEvent.from_changed_dict(original.to_dict())
	assert_true(restored is TurnChangedEvent)
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"previous_player_index": 0,
		"new_player_index": 1,
		"previous_player_id": "green",
		"new_player_id": "yellow",
	}
	var event := TurnChangedEvent.from_changed_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED,
			"from_changed_dict трябва да форсира TYPE_TURN_CHANGED")


func test_equals() -> void:
	var a := TurnChangedEvent.create_changed(0, 1, PlayerId.GREEN, PlayerId.YELLOW, 1)
	var b := TurnChangedEvent.create_changed(0, 1, PlayerId.GREEN, PlayerId.YELLOW, 1)
	var c := TurnChangedEvent.create_changed(0, 1, PlayerId.GREEN, PlayerId.YELLOW, 2)
	var d := TurnChangedEvent.create_changed(1, 0, PlayerId.YELLOW, PlayerId.GREEN, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_TURN_CHANGED, 1)))


# ── Договор с GameState / TYPE_* ──────────────────────────────────────────────

func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_TURN_CHANGED, &"TurnChanged")
	var event := TurnChangedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_payload_matches_game_state_active_player_swap() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(2))
	var previous_index: int = state.active_player_index
	var previous_id: StringName = state.get_active_player_id()
	state.set_active_player_index(1)
	var event := TurnChangedEvent.create_from_state(state, previous_index, 1)
	assert_true(event.is_valid())
	assert_eq(event.previous_player_index, previous_index)
	assert_eq(event.previous_player_id, previous_id)
	assert_eq(event.new_player_index, state.active_player_index)
	assert_eq(event.new_player_id, state.get_active_player_id())
	assert_eq(event.get_active_player_id(), PlayerId.YELLOW)
