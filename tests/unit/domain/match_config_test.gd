class_name MatchConfigTest
extends TestCase
## Unit тестове за MatchConfig като domain value object.
##
## Покрива (docs/V1_ARCHITECTURE.md, раздел 5.1 и 12):
##   - Правилни стойности по подразбиране.
##   - Всички enum стойности (Mode, ControllerType, AIDifficulty).
##   - Сериализация/десериализация (to_dict / from_dict).
##   - Валидационни правила.
##   - Кампанийна конфигурация (campaign_level_id, level_modifiers, pre_match_bonus).
##   - Правилно типиране в StartMatchCommand (без Variant workaround).


# ── Стойности по подразбиране ─────────────────────────────────────────────────

func test_default_mode_is_free_play() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.mode, MatchConfig.Mode.FREE_PLAY, "default mode трябва да е FREE_PLAY")


func test_default_board_id() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.board_id, &"classic_15x15", "default board_id трябва да е classic_15x15")


func test_default_theme_id() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.theme_id, &"jungle", "default theme_id трябва да е jungle")


func test_default_seats_is_empty() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.seats.size(), 0, "seats трябва да е празен при създаване")


func test_default_campaign_level_id_is_empty() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.campaign_level_id, &"", "campaign_level_id трябва да е празен по подразбиране")


func test_default_level_modifiers_is_empty() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.level_modifiers.size(), 0, "level_modifiers трябва да е празен по подразбиране")


func test_default_pre_match_bonus_is_empty_dict() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.pre_match_bonus.size(), 0, "pre_match_bonus трябва да е празен речник по подразбиране")


func test_schema_version_constant() -> void:
	assert_eq(MatchConfig.SCHEMA_VERSION, 1, "SCHEMA_VERSION трябва да е 1")


func test_default_schema_version_matches_constant() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.schema_version, MatchConfig.SCHEMA_VERSION, "schema_version трябва да съответства на константата")


func test_rng_seed_not_zero_by_default() -> void:
	var cfg := MatchConfig.new()
	assert_ne(cfg.rng_seed, 0, "rng_seed не трябва да е нула по подразбиране")


func test_rng_seed_is_randomized_per_instance() -> void:
	var a := MatchConfig.new()
	var b := MatchConfig.new()
	# Изключително малко вероятно двата seed-а да съвпаднат случайно.
	assert_ne(a.rng_seed, b.rng_seed, "различни инстанции трябва да имат различни rng_seed")


# ── Enum стойности ────────────────────────────────────────────────────────────

func test_mode_free_play_value() -> void:
	assert_eq(MatchConfig.Mode.FREE_PLAY, 0)


func test_mode_campaign_value() -> void:
	assert_eq(MatchConfig.Mode.CAMPAIGN, 1)


func test_controller_type_human_value() -> void:
	assert_eq(MatchConfig.ControllerType.HUMAN, 0)


func test_controller_type_ai_value() -> void:
	assert_eq(MatchConfig.ControllerType.AI, 1)


func test_controller_type_remote_value() -> void:
	assert_eq(MatchConfig.ControllerType.REMOTE, 2, "REMOTE е placeholder за v2 multiplayer")


func test_ai_difficulty_easy_value() -> void:
	assert_eq(MatchConfig.AIDifficulty.EASY, 0)


func test_ai_difficulty_medium_value() -> void:
	assert_eq(MatchConfig.AIDifficulty.MEDIUM, 1)


func test_ai_difficulty_hard_value() -> void:
	assert_eq(MatchConfig.AIDifficulty.HARD, 2)


# ── SeatConfig ────────────────────────────────────────────────────────────────

func test_seat_config_default_controller_type_is_human() -> void:
	var seat := MatchConfig.SeatConfig.new()
	assert_eq(seat.controller_type, MatchConfig.ControllerType.HUMAN)


func test_seat_config_default_animal_id_is_pig() -> void:
	var seat := MatchConfig.SeatConfig.new()
	assert_eq(seat.animal_id, &"pig")


func test_seat_config_default_ai_difficulty_is_easy() -> void:
	var seat := MatchConfig.SeatConfig.new()
	assert_eq(seat.ai_difficulty, MatchConfig.AIDifficulty.EASY)


func test_add_seat_human() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	assert_eq(cfg.seats.size(), 1)
	var seat: MatchConfig.SeatConfig = cfg.seats[0]
	assert_eq(seat.player_id, &"p1")
	assert_eq(seat.controller_type, MatchConfig.ControllerType.HUMAN)
	assert_eq(seat.animal_id, &"pig")


func test_add_seat_ai_with_difficulty() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"ai1", MatchConfig.ControllerType.AI, &"rabbit", MatchConfig.AIDifficulty.HARD)
	var seat: MatchConfig.SeatConfig = cfg.seats[0]
	assert_eq(seat.controller_type, MatchConfig.ControllerType.AI)
	assert_eq(seat.ai_difficulty, MatchConfig.AIDifficulty.HARD)


func test_add_seat_remote() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"remote1", MatchConfig.ControllerType.REMOTE, &"dog")
	var seat: MatchConfig.SeatConfig = cfg.seats[0]
	assert_eq(seat.controller_type, MatchConfig.ControllerType.REMOTE)


# ── Валидация ─────────────────────────────────────────────────────────────────

func test_valid_three_player_config() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit", MatchConfig.AIDifficulty.MEDIUM)
	cfg.add_seat(&"p3", MatchConfig.ControllerType.AI, &"dog", MatchConfig.AIDifficulty.EASY)
	assert_true(cfg.is_valid(), "3-player config трябва да е валиден")


func test_invalid_empty_animal_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.HUMAN, &"")
	assert_false(cfg.is_valid(), "празен animal_id трябва да е невалиден")


func test_invalid_ai_difficulty_out_of_range_high() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	var bad_seat := MatchConfig.SeatConfig.new()
	bad_seat.player_id = &"p2"
	bad_seat.controller_type = MatchConfig.ControllerType.AI
	bad_seat.animal_id = &"rabbit"
	bad_seat.ai_difficulty = 99
	cfg.seats.append(bad_seat)
	assert_false(cfg.is_valid(), "ai_difficulty извън [0,2] трябва да е невалиден")


# ── Сериализация / десериализация ─────────────────────────────────────────────

func test_to_dict_contains_all_schema_keys() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	var d := cfg.to_dict()
	assert_true(d.has("schema_version"), "to_dict трябва да съдържа schema_version")
	assert_true(d.has("mode"), "to_dict трябва да съдържа mode")
	assert_true(d.has("board_id"), "to_dict трябва да съдържа board_id")
	assert_true(d.has("theme_id"), "to_dict трябва да съдържа theme_id")
	assert_true(d.has("seats"), "to_dict трябва да съдържа seats")
	assert_true(d.has("campaign_level_id"), "to_dict трябва да съдържа campaign_level_id")
	assert_true(d.has("level_modifiers"), "to_dict трябва да съдържа level_modifiers")
	assert_true(d.has("pre_match_bonus"), "to_dict трябва да съдържа pre_match_bonus")
	assert_true(d.has("rng_seed"), "to_dict трябва да съдържа rng_seed")


func test_seat_to_dict_contains_all_keys() -> void:
	var seat := MatchConfig.SeatConfig.new()
	seat.player_id = &"p1"
	seat.controller_type = MatchConfig.ControllerType.AI
	seat.ai_difficulty = MatchConfig.AIDifficulty.MEDIUM
	seat.animal_id = &"cow"
	var d := seat.to_dict()
	assert_true(d.has("player_id"))
	assert_true(d.has("controller_type"))
	assert_true(d.has("ai_difficulty"))
	assert_true(d.has("animal_id"))


func test_seat_from_dict_round_trip() -> void:
	var seat := MatchConfig.SeatConfig.new()
	seat.player_id = &"p_green"
	seat.controller_type = MatchConfig.ControllerType.AI
	seat.ai_difficulty = MatchConfig.AIDifficulty.MEDIUM
	seat.animal_id = &"cow"
	var restored := MatchConfig.SeatConfig.from_dict(seat.to_dict())
	assert_eq(restored.player_id, &"p_green")
	assert_eq(restored.controller_type, MatchConfig.ControllerType.AI)
	assert_eq(restored.ai_difficulty, MatchConfig.AIDifficulty.MEDIUM)
	assert_eq(restored.animal_id, &"cow")


func test_campaign_config_round_trip() -> void:
	var cfg := MatchConfig.new()
	cfg.mode = MatchConfig.Mode.CAMPAIGN
	cfg.board_id = &"classic_15x15"
	cfg.theme_id = &"desert"
	cfg.campaign_level_id = &"jungle_level_3"
	cfg.level_modifiers = ["double_gifts"]
	cfg.pre_match_bonus = {"type": "shield", "pawn_index": 0}
	cfg.rng_seed = 99999
	cfg.add_seat(&"human", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"ai_easy", MatchConfig.ControllerType.AI, &"dog", MatchConfig.AIDifficulty.EASY)

	var restored := MatchConfig.from_dict(cfg.to_dict())

	assert_eq(restored.mode, MatchConfig.Mode.CAMPAIGN, "mode")
	assert_eq(restored.theme_id, &"desert", "theme_id")
	assert_eq(restored.campaign_level_id, &"jungle_level_3", "campaign_level_id")
	assert_eq(restored.level_modifiers.size(), 1, "level_modifiers size")
	assert_eq(restored.level_modifiers[0], "double_gifts", "level_modifiers[0]")
	assert_eq(restored.pre_match_bonus.get("type"), "shield", "pre_match_bonus type")
	assert_eq(restored.rng_seed, 99999, "rng_seed")
	assert_eq(restored.seats.size(), 2, "seats count")


func test_from_dict_missing_optional_fields_use_defaults() -> void:
	var minimal := {"seats": [
		{"player_id": "p1", "controller_type": 0, "ai_difficulty": 0, "animal_id": "pig"},
		{"player_id": "p2", "controller_type": 0, "ai_difficulty": 0, "animal_id": "dog"},
	]}
	var cfg := MatchConfig.from_dict(minimal)
	assert_eq(cfg.mode, MatchConfig.Mode.FREE_PLAY, "default mode")
	assert_eq(cfg.board_id, &"classic_15x15", "default board_id")
	assert_eq(cfg.theme_id, &"jungle", "default theme_id")
	assert_eq(cfg.campaign_level_id, &"", "default campaign_level_id")
	assert_eq(cfg.level_modifiers.size(), 0, "default level_modifiers")
	assert_eq(cfg.pre_match_bonus.size(), 0, "default pre_match_bonus")


func test_to_dict_produces_independent_copy_of_level_modifiers() -> void:
	var cfg := MatchConfig.new()
	cfg.level_modifiers = ["mod_a"]
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.HUMAN, &"dog")
	var d := cfg.to_dict()
	d["level_modifiers"].append("injected")
	assert_eq(cfg.level_modifiers.size(), 1, "to_dict не трябва да споделя референция към level_modifiers")


func test_to_dict_produces_independent_copy_of_pre_match_bonus() -> void:
	var cfg := MatchConfig.new()
	cfg.pre_match_bonus = {"type": "extra_turn"}
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.HUMAN, &"dog")
	var d := cfg.to_dict()
	d["pre_match_bonus"]["injected"] = true
	assert_false(cfg.pre_match_bonus.has("injected"),
			"to_dict не трябва да споделя референция към pre_match_bonus")


# ── Интеграция с StartMatchCommand ────────────────────────────────────────────

func test_start_match_command_accepts_match_config() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	var cmd := StartMatchCommand.new(cfg)
	assert_not_null(cmd.config, "StartMatchCommand трябва да пази config референция")
	assert_true(cmd.config is MatchConfig,
			"StartMatchCommand.config трябва да е MatchConfig инстанция")


func test_start_match_command_config_rng_seed_is_accessible() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 42
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"dog")
	var cmd := StartMatchCommand.new(cfg)
	assert_eq(cmd.config.rng_seed, 42, "rng_seed трябва да е достъпен от командата")
