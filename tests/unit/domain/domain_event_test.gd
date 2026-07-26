class_name DomainEventTest
extends TestCase
## Unit тестове за базовия DomainEvent (Task #68 / docs/V1_ARCHITECTURE.md, §4.4 / §11).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/events/, без Vector2/NodePath.
##   - Envelope: event_type, command_sequence.
##   - Константи TYPE_* / COMMAND_SEQUENCE_UNSET / ALL_TYPES.
##   - Фабрика create, stamp / is_stamped.
##   - is_valid() / is_known_type() инварианти.
##   - Сериализация to_dict / from_dict / equals / duplicate_event.
##   - Подкласовете наследяват envelope полетата.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_domain_event_extends_ref_counted() -> void:
	var event := DomainEvent.new()
	assert_true(event is RefCounted,
			"DomainEvent трябва да extends RefCounted, не Node")


func test_domain_event_is_not_node() -> void:
	var event: Object = DomainEvent.new()
	assert_false(event is Node,
			"DomainEvent не трябва да extends Node — domain слой е без сцени")


func test_domain_event_script_path_is_in_domain_events() -> void:
	var event := DomainEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"DomainEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_PAWN_MOVED, 1)
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от DomainEvent envelope")


# ── Константи и подразбирания ─────────────────────────────────────────────────

func test_sequence_unset_and_type_constants() -> void:
	assert_eq(DomainEvent.COMMAND_SEQUENCE_UNSET, 0)
	assert_eq(DomainEvent.TYPE_MATCH_STARTED, &"MatchStarted")
	assert_eq(DomainEvent.TYPE_DICE_ROLLED, &"DiceRolled")
	assert_eq(DomainEvent.TYPE_VALID_MOVES_CHANGED, &"ValidMovesChanged")
	assert_eq(DomainEvent.TYPE_PAWN_MOVED, &"PawnMoved")
	assert_eq(DomainEvent.TYPE_PAWN_EXITED_BASE, &"PawnExitedBase")
	assert_eq(DomainEvent.TYPE_PAWN_CAPTURED, &"PawnCaptured")
	assert_eq(DomainEvent.TYPE_PAWN_SENT_HOME, &"PawnSentHome")
	assert_eq(DomainEvent.TYPE_PAWN_STACK_FORMED, &"PawnStackFormed")
	assert_eq(DomainEvent.TYPE_PAWN_FINISHED, &"PawnFinished")
	assert_eq(DomainEvent.TYPE_GIFT_SPAWNED, &"GiftSpawned")
	assert_eq(DomainEvent.TYPE_GIFT_COLLECTED, &"GiftCollected")
	assert_eq(DomainEvent.TYPE_POWER_UP_RESOLVED, &"PowerUpResolved")
	assert_eq(DomainEvent.TYPE_SHIELD_APPLIED, &"ShieldApplied")
	assert_eq(DomainEvent.TYPE_TURN_CHANGED, &"TurnChanged")
	assert_eq(DomainEvent.TYPE_PLAYER_RANKED, &"PlayerRanked")
	assert_eq(DomainEvent.TYPE_MATCH_FINISHED, &"MatchFinished")


func test_all_types_covers_architecture_section_4_4() -> void:
	assert_eq(DomainEvent.ALL_TYPES.size(), 16)
	for type_name in DomainEvent.ALL_TYPES:
		assert_true(DomainEvent.is_known_type(type_name),
				"ALL_TYPES entry %s трябва да е known" % str(type_name))
	assert_true(DomainEvent.ALL_TYPES.has(DomainEvent.TYPE_MATCH_STARTED))
	assert_true(DomainEvent.ALL_TYPES.has(DomainEvent.TYPE_DICE_ROLLED))
	assert_true(DomainEvent.ALL_TYPES.has(DomainEvent.TYPE_PAWN_MOVED))
	assert_true(DomainEvent.ALL_TYPES.has(DomainEvent.TYPE_MATCH_FINISHED))


func test_default_fields() -> void:
	var event := DomainEvent.new()
	assert_eq(event.event_type, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid(),
			"празен envelope преди попълване трябва да е валиден")


# ── Фабрики и stamp ───────────────────────────────────────────────────────────

func test_create_sets_envelope_fields() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 3)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_eq(event.command_sequence, 3)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_stamp_sets_command_sequence() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_TURN_CHANGED)
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_eq(event.command_sequence, 1)
	assert_true(event.is_stamped())
	assert_eq(event.event_type, DomainEvent.TYPE_TURN_CHANGED,
			"stamp не трябва да пипа event_type")


func test_is_stamped_requires_positive_sequence() -> void:
	var unset := DomainEvent.create(DomainEvent.TYPE_PAWN_MOVED, 0)
	assert_false(unset.is_stamped(), "sequence=0 → не е stamped")
	var stamped := DomainEvent.create(DomainEvent.TYPE_PAWN_MOVED, 1)
	assert_true(stamped.is_stamped())


# ── is_valid() / is_known_type() ───────────────────────────────────────────────

func test_is_valid_rejects_negative_sequence() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, -1)
	assert_false(event.is_valid())


func test_is_valid_rejects_unknown_event_type() -> void:
	var event := DomainEvent.create(&"NotARealEvent", 1)
	assert_false(event.is_valid(),
			"неизвестен event_type не е валиден")


func test_is_valid_allows_empty_event_type() -> void:
	var event := DomainEvent.create(&"", 1)
	assert_true(event.is_valid(),
			"празен event_type на базовия клас е валиден envelope")


func test_is_valid_accepts_all_known_types() -> void:
	for type_name in DomainEvent.ALL_TYPES:
		var event := DomainEvent.create(type_name, 1)
		assert_true(event.is_valid(),
				"event_type %s трябва да е валиден" % str(type_name))


func test_is_known_type() -> void:
	assert_true(DomainEvent.is_known_type(DomainEvent.TYPE_GIFT_SPAWNED))
	assert_false(DomainEvent.is_known_type(&""))
	assert_false(DomainEvent.is_known_type(&"TweenFinished"))


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_keys_and_types() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_POWER_UP_RESOLVED, 2)
	var d := event.to_dict()
	assert_eq(d.size(), 2)
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_eq(typeof(d["event_type"]), TYPE_STRING,
			"event_type в to_dict трябва да е String, не StringName")
	assert_eq(d["event_type"], "PowerUpResolved")
	assert_eq(d["command_sequence"], 2)


func test_from_dict_round_trip() -> void:
	var original := DomainEvent.create(DomainEvent.TYPE_MATCH_FINISHED, 4)
	var restored := DomainEvent.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_eq(restored.event_type, DomainEvent.TYPE_MATCH_FINISHED)
	assert_eq(restored.command_sequence, 4)
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := DomainEvent.from_dict({})
	assert_eq(event.event_type, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid())
	assert_false(event.is_stamped())


func test_duplicate_event_is_independent() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_PAWN_CAPTURED, 1)
	var copy := event.duplicate_event()
	assert_true(event.equals(copy))
	copy.stamp(9)
	copy.event_type = DomainEvent.TYPE_TURN_CHANGED
	assert_eq(event.command_sequence, 1,
			"duplicate_event не трябва да споделя мутация")
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)


func test_equals() -> void:
	var a := DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 1)
	var b := DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 1)
	var c := DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 2)
	var d := DomainEvent.create(DomainEvent.TYPE_PAWN_MOVED, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(null))


# ── Подкласове наследяват envelope ────────────────────────────────────────────

func test_dice_rolled_event_is_domain_event() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.GREEN, 3)
	assert_true(event is DomainEvent)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_valid_moves_changed_event_is_domain_event() -> void:
	var event := ValidMovesChangedEvent.create_changed(
			PlayerId.YELLOW, [PawnId.for_player(PlayerId.YELLOW, 0)])
	assert_true(event is DomainEvent)
	assert_eq(event.event_type, DomainEvent.TYPE_VALID_MOVES_CHANGED)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_pawn_moved_event_is_domain_event() -> void:
	var event := PawnMovedEvent.create_moved(
			PawnId.for_player(PlayerId.GREEN, 0),
			CellId.from_grid(8, 2),
			CellId.from_grid(8, 5),
			PawnZone.MAIN_PATH)
	assert_true(event is DomainEvent)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_MOVED)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_pawn_exited_base_event_is_domain_event() -> void:
	var event := PawnExitedBaseEvent.create_exited(
			PawnId.for_player(PlayerId.YELLOW, 0),
			CellId.from_grid(13, 13),
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	assert_true(event is DomainEvent)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_EXITED_BASE)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_pawn_captured_event_is_domain_event() -> void:
	var event := PawnCapturedEvent.create_captured(
			PawnId.for_player(PlayerId.YELLOW, 0),
			PawnId.for_player(PlayerId.GREEN, 1))
	assert_true(event is DomainEvent)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_CAPTURED)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_pawn_finished_event_is_domain_event() -> void:
	var event := PawnFinishedEvent.create_finished(
			PawnId.for_player(PlayerId.YELLOW, 0),
			Classic15x15Board.home_stretch_cells_for(PlayerId.YELLOW)[3],
			CellId.CENTER)
	assert_true(event is DomainEvent)
	assert_eq(event.event_type, DomainEvent.TYPE_PAWN_FINISHED)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())


func test_gift_spawned_event_is_domain_event() -> void:
	var event := GiftSpawnedEvent.new()
	assert_true(event is DomainEvent)


func test_power_up_resolved_event_is_domain_event() -> void:
	var event := PowerUpResolvedEvent.new()
	assert_true(event is DomainEvent)


func test_turn_changed_event_is_domain_event() -> void:
	var event := TurnChangedEvent.new()
	assert_true(event is DomainEvent)


func test_subclass_stamp_uses_base_envelope() -> void:
	var event := DiceRolledEvent.create_rolled(PlayerId.YELLOW, 6)
	event.stamp(5)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 5)
	assert_eq(event.event_type, DomainEvent.TYPE_DICE_ROLLED)
	assert_eq(event.player_id, PlayerId.YELLOW)
	assert_eq(event.value, 6)
	assert_true(event.is_valid())


func test_match_finished_constant_matches_session_usage() -> void:
	## MatchSession._is_match_over сравнява event_type с &"MatchFinished".
	assert_eq(DomainEvent.TYPE_MATCH_FINISHED, &"MatchFinished")
