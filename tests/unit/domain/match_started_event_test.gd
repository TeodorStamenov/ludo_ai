class_name MatchStartedEventTest
extends TestCase
## Unit тестове за MatchStartedEvent (Task #69 / docs/V1_ARCHITECTURE.md, §4.4 / §5.1 / §11).
##
## Покрива:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: match_id + MatchConfig; event_type = TYPE_MATCH_STARTED.
##   - Фабрика create_started; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + MatchId + не-null валиден MatchConfig.
##   - Сериализация to_dict / from_started_dict / equals / duplicate_event.
##   - Събитието описва факт (config + match_id), не намерение.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_match_started_event_extends_domain_event() -> void:
	var event := MatchStartedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"MatchStartedEvent трябва да extends RefCounted чрез DomainEvent")


func test_match_started_event_is_not_node() -> void:
	var event: Object = MatchStartedEvent.new()
	assert_false(event is Node,
			"MatchStartedEvent не трябва да extends Node — domain слой е без сцени")


func test_match_started_event_script_path_is_in_domain_events() -> void:
	var event := MatchStartedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"MatchStartedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := MatchStartedEvent.create_started(&"m_1_0", _two_player_config())
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от MatchStartedEvent payload")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var cfg := _two_player_config()
	var event := MatchStartedEvent.new(&"m_10_2", cfg)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_eq(event.match_id, &"m_10_2")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.config == cfg)


func test_init_defaults_still_sets_event_type() -> void:
	var event := MatchStartedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_eq(event.match_id, &"")
	assert_true(event.config == null)


func test_create_started_sets_envelope_and_payload() -> void:
	var cfg := _two_player_config(99)
	var event := MatchStartedEvent.create_started(&"m_10_2", cfg, 1)
	assert_eq(event.match_id, &"m_10_2")
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_eq(event.config.rng_seed, 99)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := MatchStartedEvent.create_started(&"m_42_0", _two_player_config())
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_eq(event.match_id, &"m_42_0")
	assert_true(event.is_valid())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_empty_match_id() -> void:
	var event := MatchStartedEvent.new(&"", _two_player_config())
	assert_false(event.is_valid(),
			"MatchStarted без match_id не е валиден факт")


func test_is_valid_rejects_malformed_match_id() -> void:
	var event := MatchStartedEvent.create_started(&"not_a_match", _two_player_config(), 1)
	assert_false(event.is_valid())


func test_is_valid_rejects_null_config() -> void:
	var event := MatchStartedEvent.new(&"m_1_0", null)
	assert_false(event.is_valid(),
			"MatchStarted без MatchConfig не е валиден факт")


func test_is_valid_rejects_invalid_config() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 1
	# без seats → MatchConfig.is_valid() == false
	var event := MatchStartedEvent.new(&"m_1_0", cfg)
	assert_false(cfg.is_valid())
	assert_false(event.is_valid(),
			"MatchStarted с невалиден MatchConfig трябва да е невалиден")


func test_is_valid_accepts_valid_payload() -> void:
	var event := MatchStartedEvent.create_started(&"m_1_0", _two_player_config(), 1)
	assert_true(event.is_valid())


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := MatchStartedEvent.create_started(&"m_1_0", _two_player_config(), -1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := MatchStartedEvent.create_started(&"m_1_0", _two_player_config())
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"MatchStarted може да е валиден преди stamp на command_sequence")


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var cfg := _two_player_config(7)
	var event := MatchStartedEvent.create_started(&"m_5_1", cfg, 2)
	var d := event.to_dict()
	assert_true(d.has("event_type"))
	assert_true(d.has("command_sequence"))
	assert_true(d.has("match_id"))
	assert_true(d.has("config"))
	assert_eq(d["event_type"], "MatchStarted")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["match_id"], "m_5_1")
	assert_true(d["config"] is Dictionary)
	assert_eq(d["config"]["rng_seed"], 7)
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["match_id"]), TYPE_STRING)


func test_to_dict_null_config_emits_empty_dict() -> void:
	var event := MatchStartedEvent.new(&"m_1_0", null)
	var d := event.to_dict()
	assert_true(d.has("config"))
	assert_true(d["config"] is Dictionary)
	assert_eq((d["config"] as Dictionary).size(), 0)


func test_from_dict_round_trip() -> void:
	var original := MatchStartedEvent.create_started(
			&"m_7_3", _two_player_config(4242), 4)
	var restored := MatchStartedEvent.from_started_dict(original.to_dict())
	assert_true(restored is MatchStartedEvent)
	assert_true(original.equals(restored))
	assert_eq(restored.match_id, &"m_7_3")
	assert_eq(restored.command_sequence, 4)
	assert_eq(restored.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_not_null(restored.config)
	assert_eq(restored.config.rng_seed, 4242)
	assert_true(restored.config.equals(original.config))
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var event := MatchStartedEvent.from_started_dict({})
	assert_eq(event.match_id, &"")
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_true(event.config == null)
	assert_false(event.is_valid())
	assert_false(event.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "DiceRolled",
		"command_sequence": 1,
		"match_id": "m_1_0",
		"config": _two_player_config(1).to_dict(),
	}
	var event := MatchStartedEvent.from_started_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED,
			"from_started_dict трябва да форсира TYPE_MATCH_STARTED")


func test_duplicate_event_is_independent() -> void:
	var event := MatchStartedEvent.create_started(&"m_1_0", _two_player_config(11), 1)
	var copy := event.duplicate_event() as MatchStartedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	assert_false(event.config == copy.config,
			"duplicate не трябва да споделя MatchConfig референция")
	copy.config.rng_seed = 999
	copy.stamp(9)
	copy.match_id = &"m_2_0"
	assert_eq(event.config.rng_seed, 11,
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.match_id, &"m_1_0")
	assert_eq(event.command_sequence, 1)


func test_equals() -> void:
	var cfg_a := _two_player_config(5)
	var cfg_b := _two_player_config(5)
	var a := MatchStartedEvent.create_started(&"m_1_0", cfg_a, 1)
	var b := MatchStartedEvent.create_started(&"m_1_0", cfg_b, 1)
	var c := MatchStartedEvent.create_started(&"m_1_0", cfg_a, 2)
	var d := MatchStartedEvent.create_started(&"m_2_0", cfg_a, 1)
	var e := MatchStartedEvent.create_started(&"m_1_0", _two_player_config(6), 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_MATCH_STARTED, 1)))


func test_equals_both_null_config() -> void:
	var a := MatchStartedEvent.new(&"m_1_0", null)
	var b := MatchStartedEvent.new(&"m_1_0", null)
	assert_true(a.equals(b))


# ── Договор с MatchConfig / free-play + campaign ──────────────────────────────

func test_config_accessible_after_start() -> void:
	var cfg := _two_player_config(42)
	var event := MatchStartedEvent.new(&"m_1_0", cfg)
	assert_eq(event.config.rng_seed, 42)
	assert_eq(event.config.get_active_seat_count(), 2)
	assert_true(event.config.is_free_play())


func test_campaign_match_config_is_accepted() -> void:
	var cfg := _campaign_two_player_config()
	var event := MatchStartedEvent.create_started(&"m_9_0", cfg, 1)
	assert_true(event.is_valid())
	assert_true(event.config.is_campaign())
	assert_eq(event.config.campaign_level_id, &"jungle_start_01")
	var restored := MatchStartedEvent.from_started_dict(event.to_dict())
	assert_true(restored.is_valid())
	assert_true(restored.config.is_campaign())
	assert_eq(restored.config.campaign_level_id, &"jungle_start_01")


func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_MATCH_STARTED, &"MatchStarted")
	var event := MatchStartedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_STARTED)
	assert_true(DomainEvent.is_known_type(event.event_type))


# ── Helpers ───────────────────────────────────────────────────────────────────

func _two_player_config(rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG,
			AIDifficulty.EASY)
	assert_true(cfg.is_valid(), "helper MatchConfig трябва да е валиден")
	return cfg


func _campaign_two_player_config() -> MatchConfig:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"jungle_start_01",
			ThemeId.JUNGLE,
			[LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	cfg.rng_seed = 1001
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.RABBIT,
			AIDifficulty.HARD)
	assert_true(cfg.is_valid(), "campaign helper MatchConfig трябва да е валиден")
	return cfg
