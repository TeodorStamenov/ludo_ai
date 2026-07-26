class_name StartMatchCommandTest
extends TestCase
## Unit тестове за StartMatchCommand (Task #65 / docs/V1_ARCHITECTURE.md, §4.3 / §5.1 / §11).
##
## Покрива:
##   - Domain: extends GameCommand/RefCounted, път game/domain/commands/.
##   - Payload: MatchConfig; command_type = TYPE_START_MATCH.
##   - Фабрика create_with_config; stamp / is_stamped от envelope.
##   - is_valid(): валиден envelope + не-null валиден MatchConfig.
##   - Сериализация to_dict / from_config_dict / equals / duplicate_command.
##   - Командата носи намерение (config), не резултат.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_start_match_command_extends_game_command() -> void:
	var cmd := StartMatchCommand.new(null)
	assert_true(cmd is GameCommand)
	assert_true(cmd is RefCounted,
			"StartMatchCommand трябва да extends RefCounted чрез GameCommand")


func test_start_match_command_is_not_node() -> void:
	var cmd: Object = StartMatchCommand.new(null)
	assert_false(cmd is Node,
			"StartMatchCommand не трябва да extends Node — domain слой е без сцени")


func test_start_match_command_script_path_is_in_domain_commands() -> void:
	var cmd := StartMatchCommand.new(null)
	var path: String = cmd.get_script().resource_path
	assert_true(path.contains("game/domain/commands/"),
			"StartMatchCommand трябва да е в game/domain/commands/")


func test_to_dict_has_no_result_or_presentation_fields() -> void:
	var cmd := StartMatchCommand.create_with_config(_two_player_config())
	var d := cmd.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от командата")
	assert_false(d.has("node_path"), "NodePath не е част от domain командата")
	assert_false(d.has("dice_value"), "командата не носи резултат от зара (§4.3)")
	assert_false(d.has("result"), "командата носи намерение, не резултат")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в командата")
	assert_false(d.has("events"), "events са DomainEvent[], не част от командата")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_command_type_and_config() -> void:
	var cfg := _two_player_config()
	var cmd := StartMatchCommand.new(cfg)
	assert_eq(cmd.command_type, GameCommand.TYPE_START_MATCH)
	assert_eq(cmd.player_id, &"",
			"StartMatch не е ход на seat — player_id остава празен")
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_false(cmd.is_stamped())
	assert_true(cmd.config == cfg)


func test_init_null_config_still_sets_command_type() -> void:
	var cmd := StartMatchCommand.new(null)
	assert_eq(cmd.command_type, GameCommand.TYPE_START_MATCH)
	assert_true(cmd.config == null)


func test_create_sets_envelope_and_config() -> void:
	var cfg := _two_player_config(99)
	var cmd := StartMatchCommand.create_with_config(cfg, &"m_10_2", 1, "tok")
	assert_eq(cmd.match_id, &"m_10_2")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.auth_token, "tok")
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.command_type, GameCommand.TYPE_START_MATCH)
	assert_eq(cmd.config.rng_seed, 99)
	assert_true(cmd.is_stamped())
	assert_true(cmd.is_valid())


func test_stamp_uses_base_envelope() -> void:
	var cmd := StartMatchCommand.create_with_config(_two_player_config())
	assert_false(cmd.is_stamped())
	cmd.stamp(&"m_42_0", 1)
	assert_true(cmd.is_stamped())
	assert_eq(cmd.match_id, &"m_42_0")
	assert_eq(cmd.sequence, 1)
	assert_eq(cmd.command_type, GameCommand.TYPE_START_MATCH)
	assert_true(cmd.is_valid())


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_null_config() -> void:
	var cmd := StartMatchCommand.new(null)
	assert_false(cmd.is_valid(),
			"StartMatch без MatchConfig не е готов за apply")


func test_is_valid_rejects_invalid_config() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 1
	# без seats → MatchConfig.is_valid() == false
	var cmd := StartMatchCommand.new(cfg)
	assert_false(cfg.is_valid())
	assert_false(cmd.is_valid(),
			"StartMatch с невалиден MatchConfig трябва да е невалиден")


func test_is_valid_accepts_valid_config() -> void:
	var cmd := StartMatchCommand.new(_two_player_config())
	assert_true(cmd.is_valid())


func test_is_valid_rejects_negative_sequence_even_with_valid_config() -> void:
	var cmd := StartMatchCommand.create_with_config(_two_player_config(), &"m_1_0", -1)
	assert_false(cmd.is_valid())


func test_is_valid_rejects_malformed_match_id() -> void:
	var cmd := StartMatchCommand.create_with_config(_two_player_config(), &"not_a_match", 1)
	assert_false(cmd.is_valid())


func test_is_valid_allows_empty_player_id() -> void:
	var cmd := StartMatchCommand.create_with_config(_two_player_config(), &"m_1_0", 1)
	assert_eq(cmd.player_id, &"")
	assert_true(cmd.is_valid(),
			"StartMatch може да няма player_id")


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_includes_envelope_and_config() -> void:
	var cfg := _two_player_config(7)
	var cmd := StartMatchCommand.create_with_config(cfg, &"m_5_1", 2)
	var d := cmd.to_dict()
	assert_true(d.has("match_id"))
	assert_true(d.has("player_id"))
	assert_true(d.has("sequence"))
	assert_true(d.has("auth_token"))
	assert_true(d.has("command_type"))
	assert_true(d.has("config"))
	assert_eq(d["command_type"], "StartMatch")
	assert_eq(d["match_id"], "m_5_1")
	assert_eq(d["sequence"], 2)
	assert_eq(d["player_id"], "")
	assert_true(d["config"] is Dictionary)
	assert_eq(d["config"]["rng_seed"], 7)
	assert_eq(typeof(d["command_type"]), TYPE_STRING)


func test_to_dict_null_config_emits_empty_dict() -> void:
	var cmd := StartMatchCommand.new(null)
	var d := cmd.to_dict()
	assert_true(d.has("config"))
	assert_true(d["config"] is Dictionary)
	assert_eq((d["config"] as Dictionary).size(), 0)


func test_from_dict_round_trip() -> void:
	var original := StartMatchCommand.create_with_config(_two_player_config(4242), &"m_7_3", 4, "v2")
	var restored := StartMatchCommand.from_config_dict(original.to_dict())
	assert_true(restored is StartMatchCommand)
	assert_true(original.equals(restored))
	assert_eq(restored.match_id, &"m_7_3")
	assert_eq(restored.sequence, 4)
	assert_eq(restored.auth_token, "v2")
	assert_eq(restored.command_type, GameCommand.TYPE_START_MATCH)
	assert_eq(restored.player_id, &"")
	assert_not_null(restored.config)
	assert_eq(restored.config.rng_seed, 4242)
	assert_true(restored.config.equals(original.config))
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_defaults_for_missing_keys() -> void:
	var cmd := StartMatchCommand.from_config_dict({})
	assert_eq(cmd.match_id, &"")
	assert_eq(cmd.player_id, &"")
	assert_eq(cmd.sequence, GameCommand.SEQUENCE_UNSET)
	assert_eq(cmd.auth_token, "")
	assert_eq(cmd.command_type, GameCommand.TYPE_START_MATCH)
	assert_true(cmd.config == null)
	assert_false(cmd.is_valid())
	assert_false(cmd.is_stamped())


func test_from_dict_forces_command_type() -> void:
	var data := {
		"match_id": "m_1_0",
		"player_id": "",
		"sequence": 1,
		"auth_token": "",
		"command_type": "RollDice",
		"config": _two_player_config(1).to_dict(),
	}
	var cmd := StartMatchCommand.from_config_dict(data)
	assert_eq(cmd.command_type, GameCommand.TYPE_START_MATCH,
			"from_dict трябва да форсира TYPE_START_MATCH")


func test_duplicate_command_is_independent() -> void:
	var cmd := StartMatchCommand.create_with_config(_two_player_config(11), &"m_1_0", 1)
	var copy := cmd.duplicate_command() as StartMatchCommand
	assert_not_null(copy)
	assert_true(cmd.equals(copy))
	assert_false(cmd.config == copy.config,
			"duplicate не трябва да споделя MatchConfig референция")
	copy.config.rng_seed = 999
	copy.stamp(&"m_2_0", 9)
	assert_eq(cmd.config.rng_seed, 11,
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(cmd.match_id, &"m_1_0")
	assert_eq(cmd.sequence, 1)


func test_equals() -> void:
	var cfg_a := _two_player_config(5)
	var cfg_b := _two_player_config(5)
	var a := StartMatchCommand.create_with_config(cfg_a, &"m_1_0", 1)
	var b := StartMatchCommand.create_with_config(cfg_b, &"m_1_0", 1)
	var c := StartMatchCommand.create_with_config(cfg_a, &"m_1_0", 2)
	var d := StartMatchCommand.create_with_config(_two_player_config(6), &"m_1_0", 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(null))
	assert_false(a.equals(GameCommand.create(&"m_1_0", &"", 1, GameCommand.TYPE_START_MATCH)))
	assert_false(a.equals(RollDiceCommand.new(PlayerId.YELLOW)))


func test_equals_both_null_config() -> void:
	var a := StartMatchCommand.new(null)
	var b := StartMatchCommand.new(null)
	assert_true(a.equals(b))


# ── Договор с MatchConfig / free-play + campaign ──────────────────────────────

func test_config_accessible_for_engine_init() -> void:
	var cfg := _two_player_config(42)
	var cmd := StartMatchCommand.new(cfg)
	assert_eq(cmd.config.rng_seed, 42)
	assert_eq(cmd.config.get_active_seat_count(), 2)
	assert_true(cmd.config.is_free_play())


func test_campaign_match_config_is_accepted() -> void:
	var cfg := _campaign_two_player_config()
	var cmd := StartMatchCommand.create_with_config(cfg, &"m_9_0", 1)
	assert_true(cmd.is_valid())
	assert_true(cmd.config.is_campaign())
	assert_eq(cmd.config.campaign_level_id, &"jungle_start_01")
	var restored := StartMatchCommand.from_config_dict(cmd.to_dict())
	assert_true(restored.is_valid())
	assert_true(restored.config.is_campaign())
	assert_eq(restored.config.campaign_level_id, &"jungle_start_01")


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
