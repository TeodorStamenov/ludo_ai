extends TestCase
## Unit тестове за MatchConfig — валидация и сериализация.


func test_valid_two_player_config() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit", MatchConfig.AIDifficulty.EASY)
	assert_true(cfg.is_valid(), "2-player config should be valid")


func test_invalid_one_seat() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	assert_false(cfg.is_valid(), "1-seat config must be invalid")


func test_invalid_five_seats() -> void:
	var cfg := MatchConfig.new()
	for i in 5:
		cfg.add_seat(StringName("p%d" % i), MatchConfig.ControllerType.HUMAN, &"pig")
	assert_false(cfg.is_valid(), "5-seat config must be invalid")


func test_invalid_empty_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"", MatchConfig.ControllerType.HUMAN, &"pig")
	assert_false(cfg.is_valid(), "empty player_id must be invalid")


func test_invalid_duplicate_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p1", MatchConfig.ControllerType.AI, &"rabbit")
	assert_false(cfg.is_valid(), "duplicate player_id must be invalid")


func test_four_player_config_valid() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit", MatchConfig.AIDifficulty.EASY)
	cfg.add_seat(&"p3", MatchConfig.ControllerType.AI, &"dog", MatchConfig.AIDifficulty.MEDIUM)
	cfg.add_seat(&"p4", MatchConfig.ControllerType.AI, &"cow", MatchConfig.AIDifficulty.HARD)
	assert_true(cfg.is_valid(), "4-player config should be valid")


func test_serialization_round_trip() -> void:
	var original := MatchConfig.new()
	original.mode = MatchConfig.Mode.CAMPAIGN
	original.board_id = &"classic_15x15"
	original.theme_id = &"jungle"
	original.rng_seed = 12345
	original.add_seat(&"human", MatchConfig.ControllerType.HUMAN, &"pig")
	original.add_seat(&"ai_hard", MatchConfig.ControllerType.AI, &"rabbit", MatchConfig.AIDifficulty.HARD)

	var dict := original.to_dict()
	var restored := MatchConfig.from_dict(dict)

	assert_eq(restored.mode, original.mode, "mode")
	assert_eq(restored.board_id, original.board_id, "board_id")
	assert_eq(restored.theme_id, original.theme_id, "theme_id")
	assert_eq(restored.rng_seed, original.rng_seed, "rng_seed")
	assert_eq(restored.seats.size(), 2, "seat count")

	var seat0: MatchConfig.SeatConfig = restored.seats[0]
	assert_eq(seat0.player_id, &"human", "seat0 player_id")
	assert_eq(seat0.controller_type, MatchConfig.ControllerType.HUMAN, "seat0 type")
	assert_eq(seat0.animal_id, &"pig", "seat0 animal")

	var seat1: MatchConfig.SeatConfig = restored.seats[1]
	assert_eq(seat1.player_id, &"ai_hard", "seat1 player_id")
	assert_eq(seat1.controller_type, MatchConfig.ControllerType.AI, "seat1 type")
	assert_eq(seat1.ai_difficulty, MatchConfig.AIDifficulty.HARD, "seat1 difficulty")
	assert_eq(seat1.animal_id, &"rabbit", "seat1 animal")


func test_schema_version_preserved() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.HUMAN, &"dog")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	assert_eq(restored.schema_version, MatchConfig.SCHEMA_VERSION)


func test_default_rng_seed_is_randomized() -> void:
	var a := MatchConfig.new()
	var b := MatchConfig.new()
	assert_ne(a.rng_seed, 0, "rng_seed should not be zero by default")
