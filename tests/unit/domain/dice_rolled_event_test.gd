class_name DiceRolledEventTest
extends TestCase
## Unit тестове за DiceRolledEvent (Task #70 / docs/V1_ARCHITECTURE.md, §4.4 / §6.4 / §11).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: player_id + value; event_type = TYPE_DICE_ROLLED.
##   - Фабрика create_rolled; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + PlayerId + лице 1–6.
##   - Сериализация to_dict / from_rolled_dict / equals / duplicate_event.
##   - Събитието описва факт (резултат от RNG), не намерение (§4.3 / §6.4).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_dice_rolled_event_extends_domain_event() -> void:
	var event := DiceRolledEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"DiceRolledEvent трябва да extends RefCounted чрез DomainEvent")


func test_dice_rolled_event_is_not_node() -> void:
	var event: Object = DiceRolledEvent.new()
	assert_false(event is Node,
			"DiceRolledEvent не трябва да extends Node — domain слой е без сцени")


func test_dice_rolled_event_script_path_is_in_domain_events() -> void:
	var event := DiceRolledEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"DiceRolledEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.YELLOW, 6)
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от DiceRolledEvent payload")
	assert_false(d.has("dice"), "DiceState snapshot не е payload — само value + player_id")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var event := DiceRolledEvent.new(PlayerId.GREEN, 4)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_eq(event.player_id, PlayerId.GREEN)
	assert_eq(event.value, 4)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_init_defaults_still_sets_event_type() -> void:
	var event := DiceRolledEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_eq(event.player_id, &"")
	assert_eq(event.value, DiceState.VALUE_NONE)
	assert_false(event.is_valid(),
			"DiceRolled без player_id/value не е валиден факт")


func test_create_rolled_sets_envelope_and_payload() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.CYAN, 6, 1)
	assert_eq(event.player_id, PlayerId.CYAN)
	assert_eq(event.value, 6)
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())
	assert_true(event.is_six())


func test_stamp_uses_base_envelope() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.ORANGE, 2)
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_eq(event.player_id, PlayerId.ORANGE)
	assert_eq(event.value, 2)
	assert_true(event.is_valid())


# ── is_valid() / is_six() ─────────────────────────────────────────────────────

func test_is_valid_rejects_empty_player_id() -> void:
	var event := DiceRolledEvent.new(&"", 3)
	assert_false(event.is_valid(),
			"DiceRolled без player_id не е валиден факт")


func test_is_valid_rejects_unknown_player_id() -> void:
	var event := DiceRolledEvent.create_rolled(&"purple", 3, 1)
	assert_false(event.is_valid())


func test_is_valid_rejects_value_none() -> void:
	var event := DiceRolledEvent.new(PlayerId.YELLOW, DiceState.VALUE_NONE)
	assert_false(event.is_valid(),
			"DiceRolled с VALUE_NONE не описва хвърляне")


func test_is_valid_rejects_out_of_range_value() -> void:
	var event_low := DiceRolledEvent.new(PlayerId.GREEN, -1)
	var event_high := DiceRolledEvent.new(PlayerId.GREEN, 7)
	assert_false(event_low.is_valid())
	assert_false(event_high.is_valid())


func test_is_valid_accepts_all_face_values() -> void:
	for face in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
		var event := DiceRolledEvent.create_rolled(PlayerId.YELLOW, face, 1)
		assert_true(event.is_valid(),
				"лице %d трябва да е валидно" % face)


func test_is_valid_accepts_all_player_ids() -> void:
	for player_id in PlayerId.ALL:
		var event := DiceRolledEvent.create_rolled(player_id, 1, 1)
		assert_true(event.is_valid(),
				"player_id %s трябва да е валиден" % str(player_id))


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.GREEN, 5, -1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.GREEN, 5)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"DiceRolled може да е валиден преди stamp на command_sequence")


func test_is_six() -> void:
	assert_true(DiceRolledEvent.create_rolled(PlayerId.YELLOW, 6).is_six())
	assert_false(DiceRolledEvent.create_rolled(PlayerId.YELLOW, 5).is_six())
	assert_false(DiceRolledEvent.new().is_six())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.YELLOW, 6, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("player_id"))
	assert_true(d.has("value"))
	assert_eq(d["event_type"], "DiceRolled")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["player_id"], "yellow")
	assert_eq(d["value"], 6)
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["player_id"]), TYPE_STRING)
	assert_eq(typeof(d["value"]), TYPE_INT)


func test_from_dict_round_trip() -> void:
	var original := DiceRolledEvent.create_rolled(PlayerId.CYAN, 3, 4)
	var restored := DiceRolledEvent.from_rolled_dict(original.to_dict())
	assert_true(restored is DiceRolledEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.player_id, PlayerId.CYAN)
	assert_eq(restored.value, 3)
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := DiceRolledEvent.from_rolled_dict({})
	assert_eq(event.player_id, &"")
	assert_eq(event.value, DiceState.VALUE_NONE)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "MatchStarted",
		"command_sequence": 1,
		"player_id": "green",
		"value": 2,
	}
	var event := DiceRolledEvent.from_rolled_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED,
			"from_rolled_dict трябва да форсира TYPE_DICE_ROLLED")


func test_duplicate_event_is_independent() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.ORANGE, 1, 1)
	var copy := event.duplicate_event() as DiceRolledEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.value = 6
	copy.stamp(9)
	copy.player_id = PlayerId.GREEN
	assert_eq(event.value, 1,
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.player_id, PlayerId.ORANGE)
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var a := DiceRolledEvent.create_rolled(PlayerId.GREEN, 4, 1)
	var b := DiceRolledEvent.create_rolled(PlayerId.GREEN, 4, 1)
	var c := DiceRolledEvent.create_rolled(PlayerId.GREEN, 4, 2)
	var d := DiceRolledEvent.create_rolled(PlayerId.YELLOW, 4, 1)
	var e := DiceRolledEvent.create_rolled(PlayerId.GREEN, 5, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 1)))


# ── Договор с DiceState / RollDiceCommand ─────────────────────────────────────

func test_payload_matches_dice_state_roll() -> void:
	var dice := DiceState.create_roll(PlayerId.YELLOW, 6)
	var event := DiceRolledEvent.create_rolled(dice.player_id, dice.value, 1)
	assert_true(event.is_valid())
	assert_eq(event.player_id, dice.player_id)
	assert_eq(event.value, dice.value)
	assert_true(event.is_six())
	assert_true(dice.grants_extra_turn())


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_DICE_ROLLED, &"DiceRolled")
	var event := DiceRolledEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_event_carries_result_unlike_roll_command() -> void:
	var cmd := RollDiceCommand.new(PlayerId.GREEN)
	var event := DiceRolledEvent.create_rolled(PlayerId.GREEN, 5, 1)
	assert_false(cmd.to_dict().has("value"),
			"RollDiceCommand носи намерение, не резултат")
	assert_true(event.to_dict().has("value"),
			"DiceRolled носи факта от авторитетния RNG")
	assert_eq(event.value, 5)
