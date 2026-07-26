class_name GameStateHashTest
extends TestCase
## Unit тестове за стабилен GameState hash (Task #62 /
## docs/V1_ARCHITECTURE.md §4.1, §11 и §16.3).
##
## Покрива:
##   - compute_hash() / compute_hash_from_dict() на domain RefCounted.
##   - Еднакви equals() състояния → еднакъв hash.
##   - JSON / dict round-trip запазва hash (§16.3 replay критерий).
##   - Hash независим от реда на Dictionary ключовете.
##   - Промяна в schema поле (command_sequence, phase, rng, pawn…) → друг hash.
##   - to_view() полетата не са единственият вход — hash ползва пълния snapshot.


# ── Архитектура ───────────────────────────────────────────────────────────────

func test_hash_api_lives_on_domain_ref_counted() -> void:
	var state: Object = _valid_two_player_setup()
	assert_true(state is RefCounted)
	assert_false(state is Node)
	assert_true(state.has_method("compute_hash"))
	assert_true(state.has_method("compute_hash_from_dict"),
			"compute_hash_from_dict е static, но е достъпен през инстанцията")
	var h: int = (state as GameState).compute_hash()
	assert_eq(typeof(h), TYPE_INT)


func test_game_state_script_path_is_in_domain_model() -> void:
	var state := GameState.new()
	var path: String = state.get_script().resource_path
	assert_true(path.contains("game/domain/model/"))


# ── Стабилност / equals ───────────────────────────────────────────────────────

func test_equal_states_have_same_hash() -> void:
	var a := _rich_in_progress_state()
	var b := a.duplicate_state()
	assert_true(a.equals(b))
	assert_eq(a.compute_hash(), b.compute_hash(),
			"equals() състояния трябва да имат еднакъв compute_hash()")


func test_hash_is_stable_across_repeated_calls() -> void:
	var state := _rich_in_progress_state()
	var first := state.compute_hash()
	assert_eq(state.compute_hash(), first)
	assert_eq(state.compute_hash(), first)


func test_dict_round_trip_preserves_hash() -> void:
	var original := _rich_in_progress_state()
	var restored := GameState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_eq(original.compute_hash(), restored.compute_hash(),
			"to_dict → from_dict трябва да запази hash")


func test_json_round_trip_preserves_hash() -> void:
	var original := _rich_in_progress_state()
	var restored := GameState.from_json(original.to_json())
	assert_not_null(restored)
	assert_true(original.equals(restored))
	assert_eq(original.compute_hash(), restored.compute_hash(),
			"to_json → from_json трябва да запази hash (§16.3)")


func test_json_round_trip_preserves_hash_for_2_3_4_players() -> void:
	for seats in [
		MatchConfig.DEFAULT_SEATS_2P,
		MatchConfig.DEFAULT_SEATS_3P,
		MatchConfig.DEFAULT_SEATS_4P,
	]:
		var original := GameState.create_from_match_config(
				_config_with_seats(seats, 99))
		var restored := GameState.from_json(original.to_json())
		assert_not_null(restored)
		assert_eq(original.compute_hash(), restored.compute_hash(),
				"hash round-trip за %d играчи" % seats.size())


func test_create_from_match_config_same_inputs_same_hash() -> void:
	MatchId._reset_counter_for_tests()
	var cfg := _two_player_config(7)
	var a := GameState.create_from_match_config(cfg, &"m_hash_fixed_0")
	MatchId._reset_counter_for_tests()
	var b := GameState.create_from_match_config(
			cfg.duplicate_config(), &"m_hash_fixed_0")
	assert_true(a.equals(b))
	assert_eq(a.compute_hash(), b.compute_hash())


# ── Каноничен ред на ключовете ────────────────────────────────────────────────

func test_hash_independent_of_top_level_key_order() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	var reordered: Dictionary = {}
	var keys: Array = d.keys()
	keys.reverse()
	for key in keys:
		reordered[key] = d[key]
	assert_eq(
			GameState.compute_hash_from_dict(d),
			GameState.compute_hash_from_dict(reordered),
			"hash трябва да е независим от реда на ключовете")


func test_hash_independent_of_nested_key_order() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	var rng: Dictionary = d["rng_state"]
	var flipped: Dictionary = {}
	# Обратен ред на seed/state.
	if rng.has("state"):
		flipped["state"] = rng["state"]
	if rng.has("seed"):
		flipped["seed"] = rng["seed"]
	d["rng_state"] = flipped
	assert_eq(
			state.compute_hash(),
			GameState.compute_hash_from_dict(d),
			"nested key order не трябва да променя hash")


func test_hash_normalizes_json_float_integers() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	d["schema_version"] = 1.0
	d["phase"] = float(MatchPhase.SETUP)
	d["command_sequence"] = 0.0
	d["active_player_index"] = 0.0
	assert_eq(
			state.compute_hash(),
			GameState.compute_hash_from_dict(d),
			"цели float от JSON.parse трябва да дават същия hash")


# ── Чувствителност към промени ────────────────────────────────────────────────

func test_hash_changes_when_command_sequence_changes() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.command_sequence = 1
	assert_false(a.equals(b))
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_changes_when_phase_changes() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.set_phase(MatchPhase.IN_PROGRESS)
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_changes_when_rng_state_changes() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	var rng := SeededRandomSource.new(a.get_rng_seed())
	rng.next_int(1, 6)
	b.capture_rng(rng)
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_changes_when_pawn_moves() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	var pawn := b.get_player(PlayerId.GREEN).pawns[0] as PawnState
	pawn.zone = PawnZone.MAIN_PATH
	pawn.path_index = 0
	pawn.cell_id = Classic15x15Board.spawn_cell_for(PlayerId.GREEN)
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_changes_when_gift_added() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.add_gift(GiftState.create(&"g_hash_0", &"c_6_8"))
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_changes_when_ranking_changes() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.rank_player(PlayerId.GREEN)
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_changes_when_match_id_changes() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.match_id = &"m_other_hash_0"
	assert_ne(a.compute_hash(), b.compute_hash())


func test_hash_includes_rng_and_command_sequence_unlike_to_view() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	b.command_sequence = 3
	var rng := SeededRandomSource.new(99)
	b.capture_rng(rng)
	# to_view() умишлено няма rng_state / command_sequence — hash ги включва.
	assert_false(a.to_view().has("rng_state"))
	assert_false(a.to_view().has("command_sequence"))
	assert_true(a.to_dict().has("rng_state"))
	assert_true(a.to_dict().has("command_sequence"))
	assert_ne(a.compute_hash(), b.compute_hash())


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
