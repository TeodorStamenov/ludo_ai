class_name SerializeDeserializeLosslessTest
extends TestCase
## Unit тестове за инварианта „serialize → deserialize без загуба“
## (Task #63 / docs/V1_ARCHITECTURE.md §4.1, §9 и §16.2).
##
## Критичен Definition of Done критерий:
##   state може да се serialize → deserialize без загуба на данни.
##
## Покрива production GameState persistence API (to_json/from_json,
## to_dict/from_dict, equals, compute_hash) върху пълно попълнен mid-match
## snapshot — вкл. nested pawn zones, shield, status_effects, turn valid_*,
## gifts, ranking, rng_state и command_sequence.
##
## Не тества Stub/Null/Adapter и не пише във файлова система (§9 wrapper).


const _JSON_ROUND_TRIPS := 3


# ── Архитектура ───────────────────────────────────────────────────────────────

func test_lossless_api_lives_on_domain_ref_counted() -> void:
	var state: Object = _setup_state()
	assert_true(state is RefCounted)
	assert_false(state is Node)
	assert_true(state.has_method("to_json"))
	assert_true(state.has_method("from_json"))
	assert_true(state.has_method("to_dict"))
	assert_true(state.has_method("from_dict"))
	assert_true(state.has_method("equals"))
	assert_true(state.has_method("compute_hash"))
	var path: String = (state as GameState).get_script().resource_path
	assert_true(path.contains("game/domain/model/"))


# ── Основен DoD §16.2 инвариант ───────────────────────────────────────────────

func test_json_serialize_deserialize_is_lossless() -> void:
	var original := _fully_populated_mid_match_state()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored, "from_json трябва да върне GameState")
	assert_true(original.equals(restored),
			"JSON serialize → deserialize трябва да е без загуба (§16.2)")
	assert_true(restored.is_valid())
	assert_eq(original.compute_hash(), restored.compute_hash(),
			"lossless round-trip трябва да запази state hash")


func test_dict_serialize_deserialize_is_lossless() -> void:
	var original := _fully_populated_mid_match_state()
	var restored := GameState.from_dict(original.to_dict())
	assert_true(original.equals(restored),
			"dict serialize → deserialize трябва да е без загуба")
	assert_eq(original.compute_hash(), restored.compute_hash())
	assert_true(restored.is_valid())


func test_repeated_json_round_trips_remain_lossless() -> void:
	## Идемпотентност: N × (to_json → from_json) не губи данни.
	var current := _fully_populated_mid_match_state()
	var reference_hash := current.compute_hash()
	for i in _JSON_ROUND_TRIPS:
		var next := GameState.from_json(current.to_json())
		assert_not_null(next, "round-trip #%d върна null" % (i + 1))
		assert_true(current.equals(next),
				"round-trip #%d трябва да е lossless" % (i + 1))
		assert_eq(next.compute_hash(), reference_hash)
		current = next
	assert_true(current.is_valid())


# ── Пълно полево покритие на §4.1 схемата ─────────────────────────────────────

func test_json_round_trip_preserves_every_schema_field() -> void:
	var original := _fully_populated_mid_match_state()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)

	assert_eq(restored.schema_version, GameState.SCHEMA_VERSION)
	assert_eq(restored.match_id, original.match_id)
	assert_eq(restored.board_id, Classic15x15Board.BOARD_ID)
	assert_eq(restored.phase, MatchPhase.IN_PROGRESS)
	assert_eq(restored.active_player_index, 0)
	assert_eq(restored.command_sequence, 17)
	assert_true(restored.match_config.equals(original.match_config))
	assert_true(restored.match_config.is_campaign())
	assert_eq(restored.match_config.campaign_level_id, &"jungle_lossless_01")
	assert_eq(restored.match_config.theme_id, ThemeId.JUNGLE)
	assert_eq(restored.match_config.rng_seed, 424242)

	assert_eq(restored.player_count(), 2)
	assert_eq(restored.gifts.size(), 2)
	assert_eq(restored.ranking.size(), 1)
	assert_eq(restored.get_ranked_player_ids()[0], PlayerId.GREEN)

	assert_true(restored.turn.equals(original.turn))
	assert_eq(restored.turn.phase, TurnPhase.AWAITING_MOVE)
	assert_eq(restored.turn.dice_value, 6)
	assert_eq(restored.turn.turn_number, 4)
	assert_true(restored.turn.extra_roll_pending)
	assert_eq(restored.turn.valid_pawn_ids.size(), 2)
	assert_eq(String(restored.turn.valid_pawn_ids[0]), "green_0")
	assert_eq(String(restored.turn.valid_command_kinds[0]), "move_pawn")

	assert_true(restored.dice.equals(original.dice))
	assert_eq(restored.dice.value, 6)
	assert_eq(restored.dice.player_id, PlayerId.GREEN)

	assert_eq(str(restored.rng_state[GameState.RNG_STATE_KEY_SEED]),
			str(original.rng_state[GameState.RNG_STATE_KEY_SEED]))
	assert_eq(str(restored.rng_state[GameState.RNG_STATE_KEY_STATE]),
			str(original.rng_state[GameState.RNG_STATE_KEY_STATE]))


func test_json_round_trip_preserves_nested_pawn_and_player_state() -> void:
	var original := _fully_populated_mid_match_state()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)

	var green := restored.get_player(PlayerId.GREEN)
	assert_not_null(green)
	assert_eq(green.rank, 1)
	assert_eq(green.animal_id, AnimalId.HEN)
	assert_true(green.has_status_effect(&"extra_turn_pending"))
	assert_eq(green.status_effects.size(), 1)
	assert_eq(int(green.status_effects[0]["turns_remaining"]), 2)

	var p0 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 0))
	assert_eq(p0.zone, PawnZone.MAIN_PATH)
	assert_eq(p0.path_index, 5)
	assert_eq(p0.shield_turns_remaining, 3)
	assert_true(p0.has_shield())

	var p1 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 1))
	assert_eq(p1.zone, PawnZone.HOME_STRETCH)
	assert_true(Classic15x15Board.is_home_stretch_cell_of(PlayerId.GREEN, p1.cell_id))

	var p2 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 2))
	assert_eq(p2.zone, PawnZone.FINISHED)
	assert_true(Classic15x15Board.is_home_stretch_cell_of(PlayerId.GREEN, p2.cell_id),
			"V1.1: FINISHED остава на собствената home stretch клетка, не CENTER")

	var p3 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 3))
	assert_eq(p3.zone, PawnZone.BASE)
	assert_eq(p3.path_index, PawnState.PATH_INDEX_IN_BASE)

	var yellow := restored.get_player(PlayerId.YELLOW)
	assert_eq(yellow.controller_type, MatchConfig.ControllerType.AI)
	assert_eq(yellow.rank, PlayerState.RANK_UNRANKED)
	var y0 := yellow.get_pawn(PawnId.for_player(PlayerId.YELLOW, 0))
	assert_eq(y0.zone, PawnZone.MAIN_PATH)
	assert_eq(y0.path_index, 0)
	assert_eq(y0.cell_id, Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))


func test_json_round_trip_preserves_gifts_order_and_ids() -> void:
	var original := _fully_populated_mid_match_state()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)
	assert_eq(restored.gifts.size(), 2)
	var g0 := restored.gifts[0] as GiftState
	var g1 := restored.gifts[1] as GiftState
	assert_eq(String(g0.gift_id), "g_4_0")
	assert_eq(String(g0.cell_id), "c_6_8")
	assert_eq(String(g1.gift_id), "g_4_1")
	assert_eq(String(g1.cell_id), "c_8_6")
	assert_true(original.gifts[0].equals(g0))
	assert_true(original.gifts[1].equals(g1))


# ── Seat counts + RNG поток ───────────────────────────────────────────────────

func test_json_round_trip_lossless_for_two_three_four_players() -> void:
	for seats in [
		MatchConfig.DEFAULT_SEATS_2P,
		MatchConfig.DEFAULT_SEATS_3P,
		MatchConfig.DEFAULT_SEATS_4P,
	]:
		var original := GameState.create_from_match_config(
				_config_with_seats(seats, 77))
		assert_true(original.is_valid())
		var restored := GameState.from_json(original.to_json())
		assert_not_null(restored)
		assert_true(original.equals(restored),
				"lossless JSON round-trip за %d играчи" % seats.size())
		assert_eq(original.compute_hash(), restored.compute_hash())
		assert_eq(restored.player_count(), seats.size())


func test_json_round_trip_preserves_rng_stream() -> void:
	var original := _setup_state()
	var rng := SeededRandomSource.new(original.match_config.rng_seed)
	for _i in 10:
		rng.next_int(1, 6)
	assert_true(original.capture_rng(rng))

	var expected: Array = []
	for _i in 16:
		expected.append(rng.next_int(1, 6))

	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)
	assert_true(original.equals(restored))
	var replay := restored.create_random_source_from_state()
	var actual: Array = []
	for _i in 16:
		actual.append(replay.next_int(1, 6))
	assert_eq(actual, expected,
			"serialize → deserialize трябва да запази RNG потока без загуба")


func test_restored_state_mutations_do_not_affect_original() -> void:
	## Round-trip трябва да даде независимо копие (няма споделени референции).
	var original := _fully_populated_mid_match_state()
	var snapshot_hash := original.compute_hash()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)

	restored.command_sequence = 999
	restored.gifts.clear()
	restored.get_player(PlayerId.GREEN).rank = 4
	var green_pawn := restored.get_player(PlayerId.GREEN).get_pawn(
			PawnId.for_player(PlayerId.GREEN, 0))
	green_pawn.apply_shield(0)
	restored.turn.turn_number = 99

	assert_eq(original.compute_hash(), snapshot_hash,
			"мутации по restored не трябва да пипат original")
	assert_eq(original.command_sequence, 17)
	assert_eq(original.gifts.size(), 2)
	assert_eq(original.get_player(PlayerId.GREEN).rank, 1)
	assert_eq(
			original.get_player(PlayerId.GREEN).get_pawn(
					PawnId.for_player(PlayerId.GREEN, 0)).shield_turns_remaining,
			3)
	assert_eq(original.turn.turn_number, 4)


# ── Helpers ───────────────────────────────────────────────────────────────────

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


func _campaign_two_player_config() -> MatchConfig:
	var cfg := MatchConfig.create_with_seat_count(2)
	cfg.configure_campaign(
			&"jungle_lossless_01",
			ThemeId.JUNGLE,
			[LevelModifierId.GIFTS_DOUBLE_FREQUENCY])
	cfg.pre_match_bonus = {"type": "shield", "pawn_index": 1}
	cfg.rng_seed = 424242
	cfg.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.RABBIT,
			AIDifficulty.HARD)
	assert_true(cfg.is_valid())
	assert_true(cfg.is_campaign())
	return cfg


func _setup_state() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_campaign_two_player_config())
	assert_true(state.is_valid())
	return state


## Mid-match snapshot с всички §4.1 полета и nested вариации (zones, shield,
## status_effects, turn valid_*, gifts, ranking, rng, command_sequence).
func _fully_populated_mid_match_state() -> GameState:
	var state := _setup_state()
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.active_player_index = 0
	state.command_sequence = 17

	var green_route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	assert_true(green_route.size() > 10, "green route fixture")
	var green := state.get_player(PlayerId.GREEN)
	green.apply_status_effect(&"extra_turn_pending", 2)

	var g0 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 0))
	g0.set_position(PawnZone.MAIN_PATH, 5, green_route[5])
	g0.apply_shield(3)

	var home_cells := Classic15x15Board.home_stretch_cells_for(PlayerId.GREEN)
	var home_path_index: int = green_route.size() - Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER
	var g1 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 1))
	g1.set_position(PawnZone.HOME_STRETCH, home_path_index, home_cells[0])

	var g2 := green.get_pawn(PawnId.for_player(PlayerId.GREEN, 2))
	g2.mark_finished(green_route.size() - 1, green_route[green_route.size() - 1])

	# green_3 остава в BASE от create_from_match_config.

	var yellow := state.get_player(PlayerId.YELLOW)
	var y0 := yellow.get_pawn(PawnId.for_player(PlayerId.YELLOW, 0))
	y0.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))

	state.turn = TurnState.create(
			TurnPhase.AWAITING_MOVE,
			6,
			0,
			true,
			[TurnState.COMMAND_MOVE_PAWN],
			[
				PawnId.for_player(PlayerId.GREEN, 0),
				PawnId.for_player(PlayerId.GREEN, 1),
			],
			4)
	state.dice.set_roll(PlayerId.GREEN, 6)
	state.add_gift(GiftState.create(&"g_4_0", &"c_6_8"))
	state.add_gift(GiftState.create(&"g_4_1", &"c_8_6"))
	state.rank_player(PlayerId.GREEN)

	var rng := SeededRandomSource.new(state.match_config.rng_seed)
	for _i in 6:
		rng.next_int(1, 6)
	assert_true(state.capture_rng(rng))

	assert_true(state.is_valid(), "fully populated helper трябва да е валиден")
	assert_true(state.is_in_progress())
	return state
