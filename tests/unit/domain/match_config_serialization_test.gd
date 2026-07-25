class_name MatchConfigSerializationTest
extends TestCase
## Unit тестове за сериализация / десериализация на MatchConfig (Task #27 /
## docs/V1_ARCHITECTURE.md §5.1, §9 и §16.2).
##
## Покрива:
##   - JSON-safe to_dict() (StringName → String, независими копия).
##   - from_dict() възстановява StringName и int стойности (вкл. след JSON float).
##   - to_json() / from_json() без загуба на данни.
##   - equals() / duplicate_config() за round-trip критерия.
##   - SeatConfig сериализация и equals().
##   - Невалиден JSON → null; миграция на schema_version през JSON.


# ── Архитектура ───────────────────────────────────────────────────────────────

func test_serialization_api_lives_on_domain_ref_counted() -> void:
	var cfg: Object = MatchConfig.create_with_seat_count(2)
	assert_true(cfg is RefCounted)
	assert_false(cfg is Node)
	assert_true(cfg.has_method("to_dict"))
	assert_true(cfg.has_method("to_json"))
	assert_true(cfg.has_method("equals"))
	assert_true(cfg.has_method("duplicate_config"))
	assert_true(cfg.has_method("from_dict"),
			"from_dict е static, но е достъпен през инстанцията в GDScript")
	assert_true(cfg.has_method("from_json"))
	var restored := MatchConfig.from_json((cfg as MatchConfig).to_json())
	assert_not_null(restored)


# ── to_dict: JSON-примитиви ───────────────────────────────────────────────────

func test_to_dict_writes_string_ids_not_string_names() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.set_theme(ThemeId.DESERT)
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	var d := cfg.to_dict()
	assert_eq(typeof(d["board_id"]), TYPE_STRING, "board_id трябва да е String")
	assert_eq(typeof(d["theme_id"]), TYPE_STRING, "theme_id трябва да е String")
	assert_eq(typeof(d["campaign_level_id"]), TYPE_STRING)
	assert_eq(d["theme_id"], "desert")
	var seat0: Dictionary = d["seats"][0]
	assert_eq(typeof(seat0["player_id"]), TYPE_STRING)
	assert_eq(typeof(seat0["animal_id"]), TYPE_STRING)
	assert_eq(seat0["animal_id"], "hen")


func test_to_dict_level_modifiers_are_strings() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"jungle_01", ThemeId.JUNGLE, [LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	var d := cfg.to_dict()
	assert_eq(typeof(d["level_modifiers"][0]), TYPE_STRING)
	assert_eq(d["level_modifiers"][0], "gifts_double_frequency")


func test_to_dict_pre_match_bonus_is_deep_copy() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.pre_match_bonus = {"type": "shield", "nested": {"pawn": 1}}
	var d := cfg.to_dict()
	d["pre_match_bonus"]["nested"]["pawn"] = 99
	d["pre_match_bonus"]["injected"] = true
	assert_eq(cfg.pre_match_bonus["nested"]["pawn"], 1,
			"to_dict трябва да прави deep copy на pre_match_bonus")
	assert_false(cfg.pre_match_bonus.has("injected"))


# ── Dictionary round-trip ─────────────────────────────────────────────────────

func test_dict_round_trip_free_play_is_lossless() -> void:
	var cfg := MatchConfig.create_with_seat_count(3)
	cfg.set_theme(ThemeId.DESERT)
	cfg.rng_seed = 424242
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.configure_seat(
			PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.HARD)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.REMOTE, AnimalId.COW)
	var restored := MatchConfig.from_dict(cfg.to_dict())
	assert_true(cfg.equals(restored), "dict round-trip трябва да е без загуба")
	assert_true(restored.is_valid())
	assert_eq(restored.theme_id, ThemeId.DESERT)
	assert_eq(restored.rng_seed, 424242)
	assert_eq(restored.get_seat(PlayerId.ORANGE).ai_difficulty, AIDifficulty.HARD)
	assert_eq(restored.get_seat(PlayerId.YELLOW).controller_type,
			MatchConfig.ControllerType.REMOTE)


func test_dict_round_trip_campaign_is_lossless() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"desert_03", ThemeId.DESERT, [LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	cfg.pre_match_bonus = {"type": "extra_turn", "source": "rewarded_ad"}
	cfg.rng_seed = 7
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.RABBIT, AIDifficulty.MEDIUM)
	var restored := MatchConfig.from_dict(cfg.to_dict())
	assert_true(cfg.equals(restored))
	assert_true(restored.is_campaign())
	assert_eq(restored.campaign_level_id, &"desert_03")
	assert_eq(restored.pre_match_bonus.get("type"), "extra_turn")
	assert_true(restored.is_valid())


func test_from_dict_non_dictionary_pre_match_bonus_becomes_empty() -> void:
	var data := {
		"schema_version": MatchConfig.SCHEMA_VERSION,
		"seats": [
			{"player_id": "green", "controller_type": 0, "animal_id": "pig"},
			{"player_id": "yellow", "controller_type": 1, "animal_id": "dog"},
		],
		"pre_match_bonus": "not_a_dict",
	}
	var cfg := MatchConfig.from_dict(data)
	assert_eq(cfg.pre_match_bonus.size(), 0,
			"не-Dictionary pre_match_bonus трябва да стане празен речник")


# ── JSON round-trip (ключов критерий §16.2) ────────────────────────────────────

func test_to_json_returns_parseable_object() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	var text := cfg.to_json()
	assert_false(text.is_empty())
	var parsed = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["schema_version"]), MatchConfig.SCHEMA_VERSION)


func test_json_round_trip_is_lossless_for_all_schema_fields() -> void:
	var cfg := MatchConfig.create_with_seat_count(4)
	cfg.configure_campaign(
			&"jungle_02", ThemeId.JUNGLE, [LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	cfg.board_id = &"classic_15x15"
	cfg.pre_match_bonus = {"type": "shield", "pawn_index": 2}
	cfg.rng_seed = 99991
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.configure_seat(
			PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.HEN, AIDifficulty.EASY)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.HARD)
	cfg.configure_seat(PlayerId.CYAN, MatchConfig.ControllerType.REMOTE, AnimalId.COW)

	var restored := MatchConfig.from_json(cfg.to_json())
	assert_not_null(restored, "from_json трябва да върне MatchConfig")
	assert_true(cfg.equals(restored),
			"JSON serialize → deserialize трябва да е без загуба")
	assert_true(restored.is_valid())
	assert_eq(restored.mode, MatchConfig.Mode.CAMPAIGN)
	assert_eq(restored.campaign_level_id, &"jungle_02")
	assert_eq(restored.theme_id, ThemeId.JUNGLE)
	assert_eq(restored.rng_seed, 99991)
	assert_eq(int(restored.pre_match_bonus.get("pawn_index")), 2)
	assert_eq(restored.seats.size(), 4)
	assert_eq(restored.get_seat(PlayerId.YELLOW).ai_difficulty, AIDifficulty.HARD)
	assert_eq(restored.get_seat(PlayerId.CYAN).animal_id, AnimalId.COW)


func test_json_round_trip_preserves_explicit_zero_rng_seed() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.rng_seed = 0
	var restored := MatchConfig.from_json(cfg.to_json())
	assert_not_null(restored)
	assert_eq(restored.rng_seed, 0)
	assert_true(cfg.equals(restored))


func test_json_round_trip_handles_numeric_floats_from_json() -> void:
	# JSON.parse_string в Godot връща float за числа — from_dict трябва да ги каства.
	var text := JSON.stringify({
		"schema_version": 1.0,
		"mode": 1.0,
		"board_id": "classic_15x15",
		"theme_id": "desert",
		"campaign_level_id": "desert_01",
		"level_modifiers": ["gifts_double_frequency"],
		"pre_match_bonus": {"pawn_index": 0.0},
		"rng_seed": 42.0,
		"seats": [
			{
				"player_id": "green",
				"controller_type": 0.0,
				"ai_difficulty": 0.0,
				"animal_id": "pig",
			},
			{
				"player_id": "yellow",
				"controller_type": 1.0,
				"ai_difficulty": 2.0,
				"animal_id": "rabbit",
			},
		],
	})
	var cfg := MatchConfig.from_json(text)
	assert_not_null(cfg)
	assert_eq(cfg.schema_version, 1)
	assert_eq(cfg.mode, MatchConfig.Mode.CAMPAIGN)
	assert_eq(cfg.rng_seed, 42)
	assert_eq(cfg.seats[0].controller_type, MatchConfig.ControllerType.HUMAN)
	assert_eq(cfg.seats[1].controller_type, MatchConfig.ControllerType.AI)
	assert_eq(cfg.seats[1].ai_difficulty, AIDifficulty.HARD)
	assert_true(cfg.is_valid())


func test_from_json_invalid_text_returns_null() -> void:
	assert_null(MatchConfig.from_json(""))
	assert_null(MatchConfig.from_json("not-json"))
	assert_null(MatchConfig.from_json("[1, 2, 3]"),
			"JSON масив не е валиден MatchConfig корен")


func test_from_json_migrates_missing_schema_version() -> void:
	var text := JSON.stringify({
		"mode": 0,
		"seats": [
			{"player_id": "green", "controller_type": 0, "animal_id": "pig"},
			{"player_id": "yellow", "controller_type": 1, "animal_id": "dog"},
		],
		"rng_seed": 1,
	})
	var cfg := MatchConfig.from_json(text)
	assert_not_null(cfg)
	assert_eq(cfg.schema_version, MatchConfig.SCHEMA_VERSION)
	assert_true(cfg.is_valid())


# ── equals / duplicate_config ─────────────────────────────────────────────────

func test_equals_true_for_identical_configs() -> void:
	var a := MatchConfig.create_with_seat_count(2)
	a.rng_seed = 11
	var b := MatchConfig.from_dict(a.to_dict())
	assert_true(a.equals(b))
	assert_true(b.equals(a))


func test_equals_false_when_seed_differs() -> void:
	var a := MatchConfig.create_with_seat_count(2)
	a.rng_seed = 1
	var b := a.duplicate_config()
	b.rng_seed = 2
	assert_false(a.equals(b))


func test_equals_false_for_null() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	assert_false(cfg.equals(null))


func test_duplicate_config_is_independent() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.pre_match_bonus = {"type": "shield"}
	cfg.rng_seed = 55
	var copy := cfg.duplicate_config()
	assert_true(cfg.equals(copy))
	copy.pre_match_bonus["type"] = "extra_turn"
	copy.seats[0].animal_id = AnimalId.DOG
	assert_eq(cfg.pre_match_bonus["type"], "shield",
			"duplicate_config не трябва да споделя pre_match_bonus")
	assert_eq(cfg.seats[0].animal_id, AnimalId.DEFAULT,
			"duplicate_config не трябва да споделя SeatConfig инстанции")


# ── SeatConfig serialization ──────────────────────────────────────────────────

func test_seat_json_round_trip_via_parent() -> void:
	var seat := MatchConfig.SeatConfig.create(
			PlayerId.ORANGE, MatchConfig.ControllerType.AI, AnimalId.HEN, AIDifficulty.MEDIUM)
	var restored := MatchConfig.SeatConfig.from_dict(
			JSON.parse_string(JSON.stringify(seat.to_dict())))
	assert_true(seat.equals(restored))
	assert_eq(restored.player_id, PlayerId.ORANGE)
	assert_eq(restored.ai_difficulty, AIDifficulty.MEDIUM)


func test_seat_equals_false_for_null() -> void:
	var seat := MatchConfig.SeatConfig.create(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	assert_false(seat.equals(null))


# ── RNG детерминизъм след JSON restore ────────────────────────────────────────

func test_json_restored_config_rng_matches_original() -> void:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.rng_seed = 123456
	var restored := MatchConfig.from_json(cfg.to_json())
	var rng_a := cfg.create_random_source()
	var rng_b := restored.create_random_source()
	for _i in 20:
		assert_eq(rng_a.next_int(1, 6), rng_b.next_int(1, 6),
				"JSON-възстановен MatchConfig трябва да възпроизвежда същия RNG")
