class_name MatchConfigValidityTest
extends TestCase
## Acceptance тестове за валиден и невалиден MatchConfig (Task #28 /
## docs/V1_ARCHITECTURE.md §5.1 / docs/V1_GAME_DESIGN.md §3.3 / §8.2).
##
## Договорът: MatchConfig.is_valid() (делегира към MatchConfigValidator) е
## единственият gate преди MatchSession.start / MatchFactory.create.
##
## Покрива:
##   - Валидни 2/3/4P, FREE_PLAY и CAMPAIGN конфигурации.
##   - Невалидни нарушения на seats, theme/campaign, schema и mode.
##   - Съгласуваност между is_valid() и MatchConfigValidator.validate().


# ── Helpers ───────────────────────────────────────────────────────────────────

func _assert_valid(cfg: MatchConfig, msg: String = "") -> void:
	var label := msg if not msg.is_empty() else "config трябва да е валиден"
	assert_true(cfg.is_valid(), label)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.is_ok(), "%s (validator Result)" % label)
	assert_eq(result.error_codes.size(), 0)


func _assert_invalid(cfg: MatchConfig, msg: String = "") -> void:
	var label := msg if not msg.is_empty() else "config трябва да е невалиден"
	assert_false(cfg.is_valid(), label)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.is_invalid(), "%s (validator Result)" % label)
	assert_gt(result.error_codes.size(), 0,
			"%s — очакван поне един error code" % label)


func _make_two_player(a: StringName, b: StringName) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.add_seat(a, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(b, MatchConfig.ControllerType.AI, AnimalId.RABBIT, AIDifficulty.EASY)
	return cfg


# ── Валидни конфигурации ──────────────────────────────────────────────────────

func test_valid_default_two_player_config() -> void:
	_assert_valid(MatchConfig.create_with_seat_count(2),
			"default 2P (GREEN↔YELLOW) трябва да е валиден")


func test_valid_default_three_player_config() -> void:
	_assert_valid(MatchConfig.create_with_seat_count(3),
			"default 3P трябва да е валиден")


func test_valid_default_four_player_config() -> void:
	_assert_valid(MatchConfig.create_with_seat_count(4),
			"default 4P трябва да е валиден")


func test_valid_green_yellow_opposite_seats() -> void:
	_assert_valid(_make_two_player(PlayerId.GREEN, PlayerId.YELLOW),
			"GREEN↔YELLOW е валиден 2P")


func test_valid_yellow_green_reversed_order() -> void:
	_assert_valid(_make_two_player(PlayerId.YELLOW, PlayerId.GREEN),
			"редът на срещуположните seats не трябва да влияе")


func test_valid_orange_cyan_opposite_seats() -> void:
	_assert_valid(_make_two_player(PlayerId.ORANGE, PlayerId.CYAN),
			"ORANGE↔CYAN е валиден 2P")


func test_valid_cyan_orange_reversed_order() -> void:
	_assert_valid(_make_two_player(PlayerId.CYAN, PlayerId.ORANGE),
			"CYAN↔ORANGE е валиден 2P")


func test_valid_three_player_non_default_trio() -> void:
	# §3.3: при 3 играчи — кои да е три от четирите.
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.ORANGE, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.MEDIUM)
	cfg.add_seat(PlayerId.CYAN, MatchConfig.ControllerType.AI, AnimalId.COW, AIDifficulty.HARD)
	_assert_valid(cfg, "3P без GREEN трябва да е валиден")


func test_valid_free_play_with_jungle_theme() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(ThemeId.JUNGLE)
	assert_true(cfg.is_free_play())
	_assert_valid(cfg)


func test_valid_free_play_with_desert_theme() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(ThemeId.DESERT)
	_assert_valid(cfg, "FREE_PLAY с Desert тема трябва да е валиден")


func test_valid_campaign_with_level_theme_and_modifier() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"jungle_01", ThemeId.JUNGLE, [LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	assert_true(cfg.is_campaign())
	_assert_valid(cfg, "CAMPAIGN с level + theme + modifier трябва да е валиден")


func test_valid_campaign_desert_without_modifiers() -> void:
	var cfg := MatchConfig.create_with_seat_count(4)
	cfg.configure_campaign(&"desert_03", ThemeId.DESERT, [])
	_assert_valid(cfg, "CAMPAIGN без modifiers е позволен")


func test_valid_all_ai_difficulties() -> void:
	for difficulty in AIDifficulty.ALL:
		var cfg := MatchConfig.new()
		cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG, difficulty)
		_assert_valid(cfg, "AI difficulty %d трябва да е валидна" % difficulty)


func test_valid_mixed_human_ai_remote_controllers() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.RABBIT, AIDifficulty.MEDIUM)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.REMOTE, AnimalId.HEN)
	cfg.add_seat(PlayerId.CYAN, MatchConfig.ControllerType.AI, AnimalId.COW, AIDifficulty.HARD)
	_assert_valid(cfg, "HUMAN/AI/REMOTE микс трябва да е валиден")


func test_valid_all_v1_animals_across_seats() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.RABBIT, AIDifficulty.EASY)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.MEDIUM)
	cfg.add_seat(PlayerId.CYAN, MatchConfig.ControllerType.REMOTE, AnimalId.COW)
	# HEN на GREEN чрез configure
	assert_true(cfg.configure_seat(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN))
	_assert_valid(cfg, "всички v1 animal_id трябва да са приемливи")
	for animal in AnimalId.ALL:
		assert_true(AnimalId.is_valid(animal))


func test_valid_human_seat_ignores_stored_ai_difficulty() -> void:
	# ai_difficulty? е значимо само при AI (§5.1).
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG, 99)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.REMOTE, AnimalId.DOG, -1)
	_assert_valid(cfg,
			"HUMAN/REMOTE с произволна ai_difficulty стойност остават валидни")


func test_valid_after_clear_campaign() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"jungle_01", ThemeId.DESERT, [LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	cfg.clear_campaign()
	assert_true(cfg.is_free_play())
	_assert_valid(cfg, "след clear_campaign config трябва да е валиден FREE_PLAY")


func test_valid_round_trip_preserves_validity() -> void:
	var cfg := MatchConfig.create_with_seat_count(3)
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	cfg.configure_seat(
			PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.HARD)
	cfg.set_theme(ThemeId.DESERT)
	_assert_valid(cfg, "precondition")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	_assert_valid(restored, "сериализиран валиден config трябва да остане валиден")


# ── Невалидни конфигурации ────────────────────────────────────────────────────

func test_invalid_zero_seats() -> void:
	_assert_invalid(MatchConfig.new(), "0 seats трябва да е невалиден")


func test_invalid_one_seat() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	_assert_invalid(cfg, "1 seat трябва да е невалиден")


func test_invalid_five_seats() -> void:
	var cfg := MatchConfig.new()
	for i in 5:
		cfg.add_seat(StringName("p%d" % i), MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	_assert_invalid(cfg, "5 seats трябва да е невалиден")


func test_invalid_adjacent_green_orange() -> void:
	_assert_invalid(_make_two_player(PlayerId.GREEN, PlayerId.ORANGE),
			"2P със съседни бази GREEN–ORANGE трябва да е невалиден")


func test_invalid_adjacent_green_cyan() -> void:
	_assert_invalid(_make_two_player(PlayerId.GREEN, PlayerId.CYAN),
			"2P със съседни бази GREEN–CYAN трябва да е невалиден")


func test_invalid_adjacent_yellow_orange() -> void:
	_assert_invalid(_make_two_player(PlayerId.YELLOW, PlayerId.ORANGE),
			"2P със съседни бази YELLOW–ORANGE трябва да е невалиден")


func test_invalid_adjacent_yellow_cyan() -> void:
	_assert_invalid(_make_two_player(PlayerId.YELLOW, PlayerId.CYAN),
			"2P със съседни бази YELLOW–CYAN трябва да е невалиден")


func test_invalid_duplicate_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.AI, AnimalId.RABBIT)
	_assert_invalid(cfg, "дублиран player_id трябва да е невалиден")


func test_invalid_unknown_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"north", MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(&"south", MatchConfig.ControllerType.AI, AnimalId.RABBIT)
	_assert_invalid(cfg, "player_id извън PlayerId.ALL трябва да е невалиден")


func test_invalid_empty_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	var bad := MatchConfig.SeatConfig.new()
	bad.player_id = &""
	bad.controller_type = MatchConfig.ControllerType.HUMAN
	bad.animal_id = AnimalId.DOG
	cfg.seats.append(bad)
	_assert_invalid(cfg, "празен player_id трябва да е невалиден")


func test_invalid_empty_animal_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN, &"")
	_assert_invalid(cfg, "празен animal_id трябва да е невалиден")


func test_invalid_unknown_animal_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.AI, &"dragon", AIDifficulty.EASY)
	_assert_invalid(cfg, "непознат animal_id трябва да е невалиден")


func test_invalid_controller_type_out_of_range() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	var bad := MatchConfig.SeatConfig.new()
	bad.player_id = PlayerId.YELLOW
	bad.controller_type = 99
	bad.animal_id = AnimalId.RABBIT
	cfg.seats.append(bad)
	_assert_invalid(cfg, "controller_type извън [HUMAN, REMOTE] трябва да е невалиден")


func test_invalid_ai_difficulty_out_of_range() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	var bad := MatchConfig.SeatConfig.new()
	bad.player_id = PlayerId.YELLOW
	bad.controller_type = MatchConfig.ControllerType.AI
	bad.animal_id = AnimalId.RABBIT
	bad.ai_difficulty = 99
	cfg.seats.append(bad)
	_assert_invalid(cfg, "AI с ai_difficulty извън диапазона трябва да е невалиден")


func test_invalid_ai_difficulty_negative() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG, -1)
	_assert_invalid(cfg, "отрицателна AI difficulty трябва да е невалидна")


func test_invalid_mode_out_of_range() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.mode = 99
	_assert_invalid(cfg, "mode извън [FREE_PLAY, CAMPAIGN] трябва да е невалиден")


func test_invalid_empty_board_id() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.board_id = &""
	_assert_invalid(cfg, "празен board_id трябва да е невалиден")


func test_invalid_unknown_theme_id() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(&"ice")
	_assert_invalid(cfg, "непознат theme_id трябва да е невалиден")


func test_invalid_empty_theme_id() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.theme_id = &""
	_assert_invalid(cfg, "празен theme_id трябва да е невалиден")


func test_invalid_campaign_without_level_id() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.mode = MatchConfig.Mode.CAMPAIGN
	cfg.campaign_level_id = &""
	_assert_invalid(cfg, "CAMPAIGN без campaign_level_id трябва да е невалиден")


func test_invalid_free_play_with_campaign_level_id() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.mode = MatchConfig.Mode.FREE_PLAY
	cfg.campaign_level_id = &"jungle_01"
	_assert_invalid(cfg, "FREE_PLAY с campaign_level_id трябва да е невалиден")


func test_invalid_unknown_level_modifier() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_level_modifiers([&"double_xp"])
	_assert_invalid(cfg, "непознат level_modifier трябва да е невалиден")


func test_invalid_unsupported_schema_version() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.schema_version = MatchConfig.SCHEMA_VERSION + 1
	_assert_invalid(cfg, "бъдещ schema_version трябва да е невалиден")


func test_invalid_create_with_unsupported_seat_count() -> void:
	var cfg := MatchConfig.create_with_seat_count(1)
	assert_eq(cfg.get_active_seat_count(), 0)
	_assert_invalid(cfg, "create_with_seat_count(1) трябва да даде невалиден config")


func test_invalid_null_seat_in_array() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.seats[1] = null
	_assert_invalid(cfg, "null seat в seats[] трябва да е невалиден")


func test_invalid_round_trip_preserves_invalidity() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(&"ice")
	_assert_invalid(cfg, "precondition")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	_assert_invalid(restored,
			"сериализиран невалиден config трябва да остане невалиден")


# ── Съгласуваност на публичния API ────────────────────────────────────────────

func test_is_valid_matches_validator_for_valid_config() -> void:
	var cfg := MatchConfig.create_with_seat_count(4)
	assert_eq(cfg.is_valid(), MatchConfigValidator.is_valid(cfg))
	assert_true(cfg.is_valid())


func test_is_valid_matches_validator_for_invalid_config() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.board_id = &""
	assert_eq(cfg.is_valid(), MatchConfigValidator.is_valid(cfg))
	assert_false(cfg.is_valid())


func test_invalid_config_exposes_stable_error_codes() -> void:
	var cfg := MatchConfig.new()
	cfg.mode = 99
	cfg.board_id = &""
	cfg.set_theme(&"ice")
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.is_invalid())
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_MODE))
	assert_true(result.has_error(MatchConfigValidator.ERR_EMPTY_BOARD_ID))
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_THEME))
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT_COUNT))
	assert_false(cfg.is_valid())
