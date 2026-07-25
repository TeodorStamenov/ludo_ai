class_name MatchConfigValidatorTest
extends TestCase
## Unit тестове за MatchConfigValidator (Task #26 /
## docs/V1_ARCHITECTURE.md §5.1 / docs/V1_GAME_DESIGN.md §3.3 / §8.2).
##
## Покрива:
##   - Domain архитектура (RefCounted, път game/domain/).
##   - Валиден 2/3/4P config → Result.ok.
##   - Стабилни error codes за всяко договорно нарушение.
##   - MatchConfig.is_valid() делегира към валидатора.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_validator_extends_ref_counted() -> void:
	var v := MatchConfigValidator.new()
	assert_true(v is RefCounted,
			"MatchConfigValidator трябва да extends RefCounted")


func test_validator_is_not_node() -> void:
	var v: Object = MatchConfigValidator.new()
	assert_false(v is Node,
			"MatchConfigValidator не трябва да extends Node")


func test_validator_script_path_is_in_domain() -> void:
	var v := MatchConfigValidator.new()
	var path: String = v.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"MatchConfigValidator трябва да е в game/domain/")


func test_result_extends_ref_counted() -> void:
	var result := MatchConfigValidator.Result.new()
	assert_true(result is RefCounted,
			"MatchConfigValidator.Result трябва да extends RefCounted")


# ── Валидни конфигурации ──────────────────────────────────────────────────────

func test_valid_two_player_config() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.is_ok(), "2P default трябва да е валиден")
	assert_eq(result.error_codes.size(), 0)
	assert_true(MatchConfigValidator.is_valid(cfg))


func test_valid_three_player_config() -> void:
	var cfg := MatchConfig.create_with_seat_count(3)
	assert_true(MatchConfigValidator.validate(cfg).is_ok())


func test_valid_four_player_config() -> void:
	var cfg := MatchConfig.create_with_seat_count(4)
	assert_true(MatchConfigValidator.validate(cfg).is_ok())


func test_valid_campaign_config() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"jungle_01", ThemeId.JUNGLE, [LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.is_ok(), "валиден campaign config")
	assert_true(MatchConfigValidator.are_theme_and_campaign_fields_valid(cfg))


func test_valid_alternate_opposite_seats() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.ORANGE, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.CYAN, MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	assert_true(MatchConfigValidator.validate(cfg).is_ok(),
			"ORANGE↔CYAN е валиден 2P")


# ── Делегиране от MatchConfig ─────────────────────────────────────────────────

func test_match_config_is_valid_delegates_to_validator() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	assert_eq(cfg.is_valid(), MatchConfigValidator.is_valid(cfg),
			"MatchConfig.is_valid трябва да съвпада с валидатора")
	cfg.mode = 99
	assert_eq(cfg.is_valid(), MatchConfigValidator.is_valid(cfg))
	assert_false(cfg.is_valid())


func test_match_config_theme_helpers_delegate() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(&"ice")
	assert_eq(cfg.are_theme_and_campaign_fields_valid(),
			MatchConfigValidator.are_theme_and_campaign_fields_valid(cfg))
	assert_false(cfg.are_theme_and_campaign_fields_valid())


# ── Error codes ───────────────────────────────────────────────────────────────

func test_null_config_error() -> void:
	var result := MatchConfigValidator.validate(null)
	assert_true(result.is_invalid())
	assert_true(result.has_error(MatchConfigValidator.ERR_NULL_CONFIG))
	assert_eq(result.first_error_code(), MatchConfigValidator.ERR_NULL_CONFIG)
	assert_false(MatchConfigValidator.is_valid(null))


func test_unsupported_schema_error() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.schema_version = MatchConfig.SCHEMA_VERSION + 1
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_UNSUPPORTED_SCHEMA))
	assert_false(result.is_ok())


func test_invalid_mode_error() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.mode = 99
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_MODE))


func test_empty_board_id_error() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.board_id = &""
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_EMPTY_BOARD_ID))
	assert_false(cfg.is_valid(), "празен board_id трябва да прави config невалиден")


func test_invalid_theme_error() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(&"ice")
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_THEME))


func test_campaign_level_required_error() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.mode = MatchConfig.Mode.CAMPAIGN
	cfg.campaign_level_id = &""
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_CAMPAIGN_LEVEL_REQUIRED))


func test_campaign_level_forbidden_in_free_play() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.mode = MatchConfig.Mode.FREE_PLAY
	cfg.campaign_level_id = &"jungle_01"
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_CAMPAIGN_LEVEL_FORBIDDEN))


func test_invalid_level_modifier_error() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_level_modifiers([&"unknown_mod"])
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_LEVEL_MODIFIER))


func test_invalid_seat_count_too_few() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT_COUNT))


func test_invalid_seat_count_too_many() -> void:
	var cfg := MatchConfig.new()
	for i in 5:
		cfg.add_seat(StringName("p%d" % i), MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT_COUNT))


func test_invalid_seat_unknown_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, AnimalId.RABBIT)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT))


func test_invalid_seat_empty_animal() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN, &"")
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT))


func test_invalid_seat_bad_ai_difficulty() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	var bad := MatchConfig.SeatConfig.new()
	bad.player_id = PlayerId.YELLOW
	bad.controller_type = MatchConfig.ControllerType.AI
	bad.animal_id = AnimalId.RABBIT
	bad.ai_difficulty = 99
	cfg.seats.append(bad)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT))


func test_duplicate_player_id_error() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.AI, AnimalId.RABBIT)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_DUPLICATE_PLAYER_ID))


func test_non_opposite_two_player_seats_error() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.add_seat(PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.RABBIT)
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.has_error(MatchConfigValidator.ERR_NON_OPPOSITE_SEATS))


func test_collects_multiple_errors() -> void:
	var cfg := MatchConfig.new()
	cfg.schema_version = 99
	cfg.mode = 99
	cfg.board_id = &""
	cfg.set_theme(&"ice")
	# 0 seats → invalid seat count; няма seats за opposite check
	var result := MatchConfigValidator.validate(cfg)
	assert_true(result.is_invalid())
	assert_true(result.has_error(MatchConfigValidator.ERR_UNSUPPORTED_SCHEMA))
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_MODE))
	assert_true(result.has_error(MatchConfigValidator.ERR_EMPTY_BOARD_ID))
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_THEME))
	assert_true(result.has_error(MatchConfigValidator.ERR_INVALID_SEAT_COUNT))
	assert_gt(result.error_codes.size(), 1,
			"валидаторът трябва да събира множество грешки")


func test_result_first_error_helpers_on_ok() -> void:
	var result := MatchConfigValidator.Result.new()
	assert_true(result.is_ok())
	assert_eq(result.first_error_code(), &"")
	assert_eq(result.first_error_message(), "")
	assert_false(result.has_error(MatchConfigValidator.ERR_NULL_CONFIG))
