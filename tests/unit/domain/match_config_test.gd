class_name MatchConfigTest
extends TestCase
## Unit тестове за MatchConfig като domain value object.
##
## Покрива (docs/V1_ARCHITECTURE.md, раздел 5.1, 9 и 12):
##   - Правилни стойности по подразбиране.
##   - schema_version: константа, сериализация, миграция N→N+1, валидация.
##   - Всички enum стойности (Mode, ControllerType, AIDifficulty).
##   - Сериализация/десериализация (to_dict / from_dict).
##   - Валидационни правила.
##   - Кампанийна конфигурация (campaign_level_id, level_modifiers, pre_match_bonus).
##   - Правилно типиране в StartMatchCommand (без Variant workaround).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_match_config_extends_ref_counted() -> void:
	var cfg := MatchConfig.new()
	assert_true(cfg is RefCounted,
			"MatchConfig трябва да extends RefCounted, не Node")


func test_match_config_is_not_node() -> void:
	var cfg: Object = MatchConfig.new()
	assert_false(cfg is Node,
			"MatchConfig не трябва да extends Node — domain слой е без сцени")


func test_match_config_script_path_is_in_domain_model() -> void:
	var cfg := MatchConfig.new()
	var path: String = cfg.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"MatchConfig трябва да е в game/domain/model/")


func test_seat_config_extends_ref_counted() -> void:
	var seat := MatchConfig.SeatConfig.new()
	assert_true(seat is RefCounted,
			"SeatConfig трябва да extends RefCounted")


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


# ── RNG seed (docs/V1_ARCHITECTURE.md, §4.5 и §5.1) ───────────────────────────

func test_rng_seed_not_zero_by_default() -> void:
	var cfg := MatchConfig.new()
	assert_ne(cfg.rng_seed, 0, "авто-генерираният rng_seed не трябва да е нула")


func test_rng_seed_is_randomized_per_instance() -> void:
	var a := MatchConfig.new()
	var b := MatchConfig.new()
	# Изключително малко вероятно двата seed-а да съвпаднат случайно.
	assert_ne(a.rng_seed, b.rng_seed, "различни инстанции трябва да имат различни rng_seed")


func test_generate_rng_seed_never_returns_zero() -> void:
	for _i in 32:
		assert_ne(MatchConfig.generate_rng_seed(), 0,
				"generate_rng_seed() трябва да избягва 0")


func test_explicit_rng_seed_zero_is_allowed() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 0
	assert_eq(cfg.rng_seed, 0, "изричен rng_seed=0 е валидна тестова стойност")


func test_rng_seed_zero_round_trip_preserves_zero() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 0
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"dog")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	assert_eq(restored.rng_seed, 0, "изричен seed 0 трябва да се запази при round-trip")


func test_from_dict_explicit_zero_seed_is_not_replaced_by_auto() -> void:
	var data := {
		"schema_version": MatchConfig.SCHEMA_VERSION,
		"rng_seed": 0,
		"seats": [
			{"player_id": "p1", "controller_type": 0, "animal_id": "pig"},
			{"player_id": "p2", "controller_type": 1, "animal_id": "dog"},
		],
	}
	var cfg := MatchConfig.from_dict(data)
	assert_eq(cfg.rng_seed, 0, "from_dict с rng_seed=0 не трябва да го заменя с авто-seed")


func test_rng_seed_round_trip_preserves_arbitrary_value() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 42
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	assert_eq(restored.rng_seed, 42, "rng_seed трябва да се запази при to_dict/from_dict")


func test_create_random_source_uses_config_seed() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 777
	var rng := cfg.create_random_source()
	assert_true(rng is SeededRandomSource,
			"create_random_source() трябва да връща SeededRandomSource")
	assert_eq(rng.get_state().get("seed"), 777,
			"RNG seed трябва да съвпада с MatchConfig.rng_seed")


func test_create_random_source_same_seed_is_deterministic() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 12345
	var rng_a := cfg.create_random_source()
	var rng_b := cfg.create_random_source()
	for _i in 20:
		assert_eq(rng_a.next_int(1, 6), rng_b.next_int(1, 6),
				"еднакъв MatchConfig.rng_seed → еднаква RNG последователност")


func test_create_random_source_different_seeds_diverge() -> void:
	var cfg_a := MatchConfig.new()
	cfg_a.rng_seed = 1
	var cfg_b := MatchConfig.new()
	cfg_b.rng_seed = 2
	var rng_a := cfg_a.create_random_source()
	var rng_b := cfg_b.create_random_source()
	var same := true
	for _i in 20:
		if rng_a.next_int(0, 1000) != rng_b.next_int(0, 1000):
			same = false
			break
	assert_false(same, "различни MatchConfig.rng_seed трябва да дават различни последователности")


func test_restored_config_create_random_source_matches_original() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 99991
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"cow")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	var rng_a := cfg.create_random_source()
	var rng_b := restored.create_random_source()
	for _i in 15:
		assert_eq(rng_a.next_int(1, 6), rng_b.next_int(1, 6),
				"десериализиран config трябва да възпроизвежда същия RNG")


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

func test_valid_two_player_config() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	assert_true(cfg.is_valid(), "2-player config трябва да е валиден")


func test_valid_three_player_config() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit", MatchConfig.AIDifficulty.MEDIUM)
	cfg.add_seat(&"p3", MatchConfig.ControllerType.AI, &"dog", MatchConfig.AIDifficulty.EASY)
	assert_true(cfg.is_valid(), "3-player config трябва да е валиден")


func test_valid_four_player_config() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	cfg.add_seat(&"p3", MatchConfig.ControllerType.AI, &"dog")
	cfg.add_seat(&"p4", MatchConfig.ControllerType.REMOTE, &"cow")
	assert_true(cfg.is_valid(), "4-player config трябва да е валиден")


func test_invalid_fewer_than_two_seats() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	assert_false(cfg.is_valid(), "1 seat трябва да е невалиден")


func test_invalid_more_than_four_seats() -> void:
	var cfg := MatchConfig.new()
	for i in 5:
		cfg.add_seat(StringName("p%d" % i), MatchConfig.ControllerType.HUMAN, &"pig")
	assert_false(cfg.is_valid(), "5 seats трябва да е невалиден")


func test_invalid_empty_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	var bad_seat := MatchConfig.SeatConfig.new()
	bad_seat.player_id = &""
	bad_seat.controller_type = MatchConfig.ControllerType.HUMAN
	bad_seat.animal_id = &"dog"
	cfg.seats.append(bad_seat)
	assert_false(cfg.is_valid(), "празен player_id трябва да е невалиден")


func test_invalid_duplicate_player_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"same", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"same", MatchConfig.ControllerType.AI, &"rabbit")
	assert_false(cfg.is_valid(), "дублиран player_id трябва да е невалиден")


func test_invalid_empty_animal_id() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.HUMAN, &"")
	assert_false(cfg.is_valid(), "празен animal_id трябва да е невалиден")


func test_invalid_controller_type_out_of_range() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	var bad_seat := MatchConfig.SeatConfig.new()
	bad_seat.player_id = &"p2"
	bad_seat.controller_type = 99
	bad_seat.animal_id = &"rabbit"
	cfg.seats.append(bad_seat)
	assert_false(cfg.is_valid(), "controller_type извън [0,2] трябва да е невалиден")


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


func test_invalid_mode_out_of_range() -> void:
	var cfg := MatchConfig.new()
	cfg.mode = 99
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	assert_false(cfg.is_valid(), "mode извън [0,1] трябва да е невалиден")


# ── schema_version (docs/V1_ARCHITECTURE.md, §5.1 и §9) ───────────────────────

func test_schema_version_constant() -> void:
	assert_eq(MatchConfig.SCHEMA_VERSION, 1, "SCHEMA_VERSION трябва да е 1")


func test_default_schema_version_matches_constant() -> void:
	var cfg := MatchConfig.new()
	assert_eq(cfg.schema_version, MatchConfig.SCHEMA_VERSION,
			"schema_version трябва да съответства на константата")


func test_is_schema_supported_accepts_current_version() -> void:
	assert_true(MatchConfig.is_schema_supported(MatchConfig.SCHEMA_VERSION),
			"текущата SCHEMA_VERSION трябва да е поддържана")


func test_is_schema_supported_rejects_zero() -> void:
	assert_false(MatchConfig.is_schema_supported(0),
			"schema_version 0 (pre-versioned) не е поддържан без миграция")


func test_is_schema_supported_rejects_future_version() -> void:
	assert_false(MatchConfig.is_schema_supported(MatchConfig.SCHEMA_VERSION + 1),
			"бъдещ schema_version не трябва да е поддържан")


func test_is_schema_supported_rejects_negative() -> void:
	assert_false(MatchConfig.is_schema_supported(-1),
			"отрицателен schema_version не трябва да е поддържан")


func test_to_dict_writes_schema_version() -> void:
	var cfg := MatchConfig.new()
	var d := cfg.to_dict()
	assert_eq(d.get("schema_version"), MatchConfig.SCHEMA_VERSION,
			"to_dict трябва да записва текущия SCHEMA_VERSION")


func test_schema_version_round_trip() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	var restored := MatchConfig.from_dict(cfg.to_dict())
	assert_eq(restored.schema_version, MatchConfig.SCHEMA_VERSION,
			"round-trip трябва да запази schema_version")


func test_from_dict_missing_schema_version_migrates_to_current() -> void:
	var minimal := {
		"mode": MatchConfig.Mode.FREE_PLAY,
		"seats": [
			{"player_id": "p1", "controller_type": 0, "animal_id": "pig"},
			{"player_id": "p2", "controller_type": 1, "animal_id": "dog"},
		],
	}
	var cfg := MatchConfig.from_dict(minimal)
	assert_eq(cfg.schema_version, MatchConfig.SCHEMA_VERSION,
			"липсващ schema_version трябва да се мигрира до SCHEMA_VERSION")
	assert_true(cfg.is_valid(), "мигрираният config трябва да е валиден")


func test_from_dict_schema_version_zero_migrates_to_current() -> void:
	var data := {
		"schema_version": 0,
		"seats": [
			{"player_id": "p1", "controller_type": 0, "animal_id": "pig"},
			{"player_id": "p2", "controller_type": 1, "animal_id": "dog"},
		],
	}
	var cfg := MatchConfig.from_dict(data)
	assert_eq(cfg.schema_version, MatchConfig.SCHEMA_VERSION,
			"schema_version 0 трябва да се мигрира до SCHEMA_VERSION")


func test_migrate_dict_sets_schema_version_to_current() -> void:
	var raw := {"mode": 0, "board_id": "classic_15x15"}
	var migrated := MatchConfig.migrate_dict(raw)
	assert_eq(migrated.get("schema_version"), MatchConfig.SCHEMA_VERSION,
			"migrate_dict трябва да запише SCHEMA_VERSION")
	assert_false(raw.has("schema_version"),
			"migrate_dict не трябва да мутира оригиналния dictionary")


func test_migrate_dict_leaves_future_version_unchanged() -> void:
	var future := MatchConfig.SCHEMA_VERSION + 5
	var raw := {"schema_version": future, "mode": 0}
	var migrated := MatchConfig.migrate_dict(raw)
	assert_eq(migrated.get("schema_version"), future,
			"бъдещ schema_version не трябва да се даунгрейдва")


func test_from_dict_future_schema_version_is_preserved_but_invalid() -> void:
	var future := MatchConfig.SCHEMA_VERSION + 1
	var data := {
		"schema_version": future,
		"seats": [
			{"player_id": "p1", "controller_type": 0, "animal_id": "pig"},
			{"player_id": "p2", "controller_type": 1, "animal_id": "dog"},
		],
	}
	var cfg := MatchConfig.from_dict(data)
	assert_eq(cfg.schema_version, future,
			"бъдещ schema_version трябва да се запази за откриване")
	assert_false(cfg.is_valid(),
			"config с бъдещ schema_version трябва да е невалиден")


func test_invalid_when_schema_version_tampered() -> void:
	var cfg := MatchConfig.new()
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	assert_true(cfg.is_valid(), "precondition: валиден config")
	cfg.schema_version = 0
	assert_false(cfg.is_valid(),
			"schema_version извън поддържаните трябва да прави config невалиден")


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

	assert_eq(restored.schema_version, MatchConfig.SCHEMA_VERSION, "schema_version")
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
	assert_eq(cfg.schema_version, MatchConfig.SCHEMA_VERSION, "default schema_version след миграция")
	assert_eq(cfg.mode, MatchConfig.Mode.FREE_PLAY, "default mode")
	assert_eq(cfg.board_id, &"classic_15x15", "default board_id")
	assert_eq(cfg.theme_id, &"jungle", "default theme_id")
	assert_eq(cfg.campaign_level_id, &"", "default campaign_level_id")
	assert_eq(cfg.level_modifiers.size(), 0, "default level_modifiers")
	assert_eq(cfg.pre_match_bonus.size(), 0, "default pre_match_bonus")
	assert_ne(cfg.rng_seed, 0, "липсващ rng_seed запазва авто-генерирания seed")


func test_from_dict_ignores_non_dictionary_seat_entries() -> void:
	var data := {
		"seats": [
			{"player_id": "p1", "controller_type": 0, "animal_id": "pig"},
			"not_a_dict",
			{"player_id": "p2", "controller_type": 1, "animal_id": "dog"},
		],
	}
	var cfg := MatchConfig.from_dict(data)
	assert_eq(cfg.seats.size(), 2, "не-речник записи в seats трябва да се пропускат")


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
