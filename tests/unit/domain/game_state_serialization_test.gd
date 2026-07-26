class_name GameStateSerializationTest
extends TestCase
## Unit тестове за сериализация / десериализация на GameState (Task #61 /
## docs/V1_ARCHITECTURE.md §4.1, §9 и §16.2).
##
## Покрива:
##   - JSON-safe to_dict() (StringName → String, nested модели, независими копия).
##   - from_dict() възстановява StringName и int стойности (вкл. след JSON float).
##   - to_json() / from_json() без загуба на данни (§16.2).
##   - equals() / duplicate_state() за round-trip критерия.
##   - Невалиден JSON → null; миграция на schema_version през JSON.
##   - RNG потокът се запазва след JSON restore (64-bit state като String).


# ── Архитектура ───────────────────────────────────────────────────────────────

func test_serialization_api_lives_on_domain_ref_counted() -> void:
	var state: Object = _valid_two_player_setup()
	assert_true(state is RefCounted)
	assert_false(state is Node)
	assert_true(state.has_method("to_dict"))
	assert_true(state.has_method("to_json"))
	assert_true(state.has_method("equals"))
	assert_true(state.has_method("duplicate_state"))
	assert_true(state.has_method("from_dict"),
			"from_dict е static, но е достъпен през инстанцията в GDScript")
	assert_true(state.has_method("from_json"))
	var restored := GameState.from_json((state as GameState).to_json())
	assert_not_null(restored)


# ── to_dict: JSON-примитиви ───────────────────────────────────────────────────

func test_to_dict_writes_string_ids_not_string_names() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	assert_eq(typeof(d["match_id"]), TYPE_STRING, "match_id трябва да е String")
	assert_eq(typeof(d["board_id"]), TYPE_STRING, "board_id трябва да е String")
	assert_eq(d["board_id"], "classic_15x15")
	var player0: Dictionary = d["players"][0]
	assert_eq(typeof(player0["player_id"]), TYPE_STRING)
	assert_eq(player0["player_id"], "green")
	var pawn0: Dictionary = player0["pawns"][0]
	assert_eq(typeof(pawn0["pawn_id"]), TYPE_STRING)
	assert_eq(typeof(pawn0["cell_id"]), TYPE_STRING)


func test_to_dict_has_no_presentation_fields() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	assert_false(d.has("position"))
	assert_false(d.has("global_position"))
	assert_false(d.has("node_path"))
	assert_false(d.has("texture"))
	assert_false(d.has("sprite"))


func test_to_dict_nested_copies_are_independent() -> void:
	var state := _valid_two_player_setup()
	state.add_gift(GiftState.create(&"g_1_0", &"c_6_8"))
	state.rng_state = {"seed": "7", "state": "11"}
	var d := state.to_dict()
	d["rng_state"]["seed"] = "99"
	d["gifts"][0]["cell_id"] = "injected"
	d["match_config"]["rng_seed"] = 0
	assert_eq(str(state.rng_state["seed"]), "7",
			"to_dict трябва да прави независимо копие на rng_state")
	assert_eq(String((state.gifts[0] as GiftState).cell_id), "c_6_8")
	assert_eq(state.match_config.rng_seed, 42)


func test_to_dict_contains_all_schema_keys() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	for key in [
		"schema_version", "match_id", "match_config", "board_id", "phase",
		"players", "active_player_index", "turn", "dice", "gifts", "ranking",
		"rng_state", "command_sequence",
	]:
		assert_true(d.has(key), "липсва ключ %s" % key)
	assert_eq(d["schema_version"], GameState.SCHEMA_VERSION)
	assert_true(d["match_config"] is Dictionary)
	assert_true(d["players"] is Array)
	assert_eq((d["players"] as Array).size(), 2)


# ── Dictionary round-trip ─────────────────────────────────────────────────────

func test_dict_round_trip_setup_is_lossless() -> void:
	var original := _valid_two_player_setup()
	var restored := GameState.from_dict(original.to_dict())
	assert_true(original.equals(restored), "dict round-trip трябва да е без загуба")
	assert_true(restored.is_valid())
	assert_eq(restored.player_count(), 2)
	assert_eq(restored.get_active_player_id(), PlayerId.GREEN)


func test_dict_round_trip_in_progress_with_nested_state_is_lossless() -> void:
	var original := _rich_in_progress_state()
	var restored := GameState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_true(restored.is_in_progress())
	assert_eq(restored.command_sequence, 5)
	assert_eq(restored.gifts.size(), 1)
	assert_eq(restored.ranking.size(), 1)
	assert_eq(restored.dice.value, 4)
	assert_eq(restored.turn.turn_number, 2)
	assert_eq(restored.get_ranked_player_ids()[0], PlayerId.GREEN)


# ── JSON round-trip (ключов критерий §16.2) ────────────────────────────────────

func test_to_json_returns_parseable_object() -> void:
	var state := _valid_two_player_setup()
	var text := state.to_json()
	assert_false(text.is_empty())
	var parsed = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["schema_version"]), GameState.SCHEMA_VERSION)
	assert_true(parsed.has("match_id"))
	assert_true(parsed.has("rng_state"))
	assert_true(parsed.has("command_sequence"))


func test_json_round_trip_is_lossless_for_all_schema_fields() -> void:
	var original := _rich_in_progress_state()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored, "from_json трябва да върне GameState")
	assert_true(original.equals(restored),
			"JSON serialize → deserialize трябва да е без загуба")
	assert_true(restored.is_valid())
	assert_eq(restored.match_id, original.match_id)
	assert_eq(restored.board_id, Classic15x15Board.BOARD_ID)
	assert_eq(restored.phase, MatchPhase.IN_PROGRESS)
	assert_eq(restored.command_sequence, 5)
	assert_eq(restored.active_player_index, 0)
	assert_eq(restored.gifts.size(), 1)
	assert_eq(String((restored.gifts[0] as GiftState).gift_id), "g_2_0")
	assert_eq(restored.ranking.size(), 1)
	assert_eq(restored.get_player(PlayerId.GREEN).rank, 1)
	assert_eq(restored.dice.value, 4)
	assert_eq(restored.turn.turn_number, 2)
	assert_true(restored.match_config.equals(original.match_config))


func test_json_round_trip_two_three_four_players() -> void:
	for seats in [
		MatchConfig.DEFAULT_SEATS_2P,
		MatchConfig.DEFAULT_SEATS_3P,
		MatchConfig.DEFAULT_SEATS_4P,
	]:
		var original := GameState.create_from_match_config(
				_config_with_seats(seats, 11))
		assert_true(original.is_valid())
		var restored := GameState.from_json(original.to_json())
		assert_not_null(restored)
		assert_true(original.equals(restored),
				"JSON round-trip трябва да е lossless за %d играчи" % seats.size())
		assert_true(restored.is_valid())
		assert_eq(restored.player_count(), seats.size())


func test_json_round_trip_handles_numeric_floats_from_json() -> void:
	# JSON.parse в Godot връща float за числа — from_dict трябва да ги каства.
	var base := _valid_two_player_setup()
	var payload := base.to_dict()
	payload["schema_version"] = 1.0
	payload["phase"] = float(MatchPhase.IN_PROGRESS)
	payload["active_player_index"] = 0.0
	payload["command_sequence"] = 3.0
	payload["turn"] = {
		"phase": float(TurnPhase.AWAITING_ROLL),
		"dice_value": 0.0,
		"base_attempts_remaining": 2.0,
		"extra_roll_pending": false,
		"valid_command_kinds": ["roll_dice"],
		"valid_pawn_ids": [],
		"turn_number": 1.0,
	}
	payload["dice"] = {
		"player_id": "green",
		"value": 6.0,
	}
	var text := JSON.stringify(payload)
	var restored := GameState.from_json(text)
	assert_not_null(restored)
	assert_eq(restored.schema_version, 1)
	assert_eq(restored.phase, MatchPhase.IN_PROGRESS)
	assert_eq(restored.active_player_index, 0)
	assert_eq(restored.command_sequence, 3)
	assert_eq(restored.turn.phase, TurnPhase.AWAITING_ROLL)
	assert_eq(restored.turn.turn_number, 1)
	assert_eq(restored.turn.base_attempts_remaining, 2)
	assert_eq(restored.dice.value, 6)
	assert_true(restored.is_valid())


func test_json_round_trip_preserves_rng_stream_and_64bit_state() -> void:
	var original := _valid_two_player_setup()
	var rng := SeededRandomSource.new(424242)
	for _i in 8:
		rng.next_int(1, 6)
	original.capture_rng(rng)
	var state_int: int = str(original.rng_state[GameState.RNG_STATE_KEY_STATE]).to_int()
	assert_true(absi(state_int) > 9007199254740992,
			"fixture state трябва да е > 2^53")

	var expected: Array = []
	for _i in 12:
		expected.append(rng.next_int(1, 6))

	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)
	assert_true(original.equals(restored))
	assert_eq(typeof(restored.rng_state[GameState.RNG_STATE_KEY_STATE]), TYPE_STRING)
	var replay := restored.create_random_source_from_state()
	var actual: Array = []
	for _i in 12:
		actual.append(replay.next_int(1, 6))
	assert_eq(actual, expected,
			"to_json → from_json трябва да запази 64-bit RNG потока")


func test_from_json_invalid_text_returns_null() -> void:
	assert_null(GameState.from_json(""))
	assert_null(GameState.from_json("not-json"))
	assert_null(GameState.from_json("[1, 2, 3]"),
			"JSON масив не е валиден GameState корен")


func test_from_json_migrates_missing_schema_version() -> void:
	var original := _valid_two_player_setup()
	var data := original.to_dict()
	data.erase("schema_version")
	var restored := GameState.from_json(JSON.stringify(data))
	assert_not_null(restored)
	assert_eq(restored.schema_version, GameState.SCHEMA_VERSION)
	assert_true(restored.is_valid())
	assert_eq(restored.match_id, original.match_id)


func test_from_json_migrates_schema_version_zero() -> void:
	var original := _valid_two_player_setup()
	var data := original.to_dict()
	data["schema_version"] = 0
	var restored := GameState.from_json(JSON.stringify(data))
	assert_not_null(restored)
	assert_eq(restored.schema_version, GameState.SCHEMA_VERSION)
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())


func test_from_json_future_schema_version_preserved_but_invalid() -> void:
	var future := GameState.SCHEMA_VERSION + 1
	var original := _valid_two_player_setup()
	var data := original.to_dict()
	data["schema_version"] = future
	var restored := GameState.from_json(JSON.stringify(data))
	assert_not_null(restored)
	assert_eq(restored.schema_version, future)
	assert_false(restored.is_valid())


# ── equals / duplicate_state ──────────────────────────────────────────────────

func test_equals_true_for_json_identical_states() -> void:
	var a := _rich_in_progress_state()
	var b := GameState.from_json(a.to_json())
	assert_true(a.equals(b))
	assert_true(b.equals(a))


func test_equals_false_when_command_sequence_differs() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.command_sequence = 1
	assert_false(a.equals(b))


func test_equals_false_for_null() -> void:
	var state := _valid_two_player_setup()
	assert_false(state.equals(null))


func test_duplicate_state_is_independent() -> void:
	var original := _valid_two_player_setup()
	original.add_gift(GiftState.create(&"g_3_0", &"c_6_8"))
	var copy := original.duplicate_state()
	assert_true(original.equals(copy))
	copy.command_sequence = 10
	(copy.players[0] as PlayerState).rank = 1
	copy.gifts.clear()
	copy.turn.begin_player_turn(1, true)
	assert_false(original.equals(copy))
	assert_eq(original.command_sequence, GameState.COMMAND_SEQUENCE_START)
	assert_eq(original.get_player(PlayerId.GREEN).rank, PlayerState.RANK_UNRANKED)
	assert_eq(original.gifts.size(), 1)
	assert_true(original.turn.is_match_start())


# ── Helpers ───────────────────────────────────────────────────────────────────

func _two_player_config(rng_seed: int = 42) -> MatchConfig:
	return _config_with_seats(MatchConfig.DEFAULT_SEATS_2P, rng_seed)


func _config_with_seats(seats: Array, rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(seats)
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		if i == 0:
			seat.configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		else:
			seat.configure(
					MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	assert_true(cfg.is_valid(), "helper MatchConfig трябва да е валиден")
	return cfg


func _valid_two_player_setup() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	assert_true(state.is_valid(), "helper GameState трябва да е валиден")
	return state


func _rich_in_progress_state() -> GameState:
	var state := _valid_two_player_setup()
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(2, false)
	state.dice.set_roll(PlayerId.GREEN, 4)
	state.add_gift(GiftState.create(&"g_2_0", &"c_8_6"))
	state.rank_player(PlayerId.GREEN)
	state.command_sequence = 5
	assert_true(state.is_valid(), "rich helper GameState трябва да е валиден")
	return state
