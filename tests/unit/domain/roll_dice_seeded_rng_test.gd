extends TestCase
## Business-critical тестове за RollDiceCommand чрез seeded RNG (Task #91 /
## docs/V1_ARCHITECTURE.md §4.3 / §4.5 / §12).
##
## Инварианти: командата носи намерение (без value); лицето идва от
## SeededRandomSource; еднакъв seed + еднакви команди → еднакви DiceRolled /
## state hash; reject не пипа RNG; accept записва rng_state за replay.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_dice_value_comes_from_seeded_rng_not_command() -> void:
	const SEED := 4242
	var expected := SeededRandomSource.new(SEED).next_int(
			DiceState.VALUE_MIN, DiceState.VALUE_MAX)
	var state := _setup_in_progress(SEED)
	var rng := SeededRandomSource.new(SEED)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	assert_false(cmd.to_dict().has("value"))
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var rolled := result.events[0] as DiceRolledEvent
	assert_true(rolled is DiceRolledEvent)
	assert_eq(rolled.value, expected)
	assert_true(DiceState.is_face_value(rolled.value))


func test_same_seed_identical_roll_sequence_and_hashes() -> void:
	const SEED := 777001
	const ROLLS := 5
	var stream_a := _roll_stream(SEED, ROLLS)
	var stream_b := _roll_stream(SEED, ROLLS)
	assert_eq(stream_a["values"], stream_b["values"])
	assert_eq(stream_a["hashes"], stream_b["hashes"])
	assert_eq((stream_a["values"] as Array).size(), ROLLS)


func test_different_seeds_diverge_on_rolls() -> void:
	var a: Array = _roll_stream(1001, 8)["values"]
	var b: Array = _roll_stream(1002, 8)["values"]
	assert_false(a == b, "различни seed-ове трябва да дадат различна зар поредица")


func test_accept_captures_rng_state_for_replay() -> void:
	const SEED := 55
	var state := _setup_in_progress(SEED)
	var rng := SeededRandomSource.new(SEED)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.has_rng_state())
	assert_true(result.state.rng_matches(rng))
	var restored := result.state.create_random_source_from_state()
	var follow_live: int = rng.next_int(DiceState.VALUE_MIN, DiceState.VALUE_MAX)
	var follow_restored: int = restored.next_int(
			DiceState.VALUE_MIN, DiceState.VALUE_MAX)
	assert_eq(follow_restored, follow_live,
			"restore от rng_state трябва да продължи същия поток")


func test_mid_match_restore_continues_identical_rolls() -> void:
	const SEED := 314159
	var state := _setup_in_progress(SEED)
	var rng := SeededRandomSource.new(SEED)
	var first_cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(first_cmd)
	var after_first := _engine.validate_and_apply(state, first_cmd, rng)
	assert_true(after_first.accepted)

	var replay_rng := after_first.state.create_random_source_from_state()
	var live_values: Array = []
	var replay_values: Array = []
	var live_state: GameState = after_first.state
	var replay_state: GameState = after_first.state.duplicate_state()
	for _i in 3:
		if not live_state.turn.allows_roll_dice():
			break
		var live_cmd := RollDiceCommand.create_for_player(
				live_state.get_active_player_id())
		live_state.stamp_command(live_cmd)
		var live_result := _engine.validate_and_apply(live_state, live_cmd, rng)
		assert_true(live_result.accepted)
		live_values.append((live_result.events[0] as DiceRolledEvent).value)
		live_state = live_result.state

		var replay_cmd := RollDiceCommand.create_for_player(
				replay_state.get_active_player_id())
		replay_state.stamp_command(replay_cmd)
		var replay_result := _engine.validate_and_apply(
				replay_state, replay_cmd, replay_rng)
		assert_true(replay_result.accepted)
		replay_values.append((replay_result.events[0] as DiceRolledEvent).value)
		replay_state = replay_result.state

	assert_false(live_values.is_empty())
	assert_eq(live_values, replay_values)
	assert_eq(live_state.compute_hash(), replay_state.compute_hash())


func test_reject_does_not_consume_rng_or_mutate_state() -> void:
	var state := _setup_in_progress(42)
	state.turn.enter_awaiting_move(6, [&"green_0"])
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(42)
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)
	assert_eq(result.event_count(), 0)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)
	assert_eq(state.rng_state, before.rng_state)


func _roll_stream(rng_seed: int, rolls: int) -> Dictionary:
	MatchId._reset_counter_for_tests()
	var state := _setup_in_progress(rng_seed)
	var rng := SeededRandomSource.new(rng_seed)
	var values: Array = []
	var hashes: Array = []
	var current := state
	for _i in rolls:
		if not current.turn.allows_roll_dice():
			break
		var cmd := RollDiceCommand.create_for_player(current.get_active_player_id())
		current.stamp_command(cmd)
		var result := _engine.validate_and_apply(current, cmd, rng)
		assert_true(result.accepted)
		values.append((result.events[0] as DiceRolledEvent).value)
		hashes.append(result.state.compute_hash())
		current = result.state
	return {"values": values, "hashes": hashes}


func _setup_in_progress(rng_seed: int) -> GameState:
	MatchId._reset_counter_for_tests()
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = rng_seed
	# Фиксиран match_id — иначе ticks_msec в MatchId.generate() чупи hash сравнение.
	var state := GameState.create_from_match_config(cfg, &"m_91_seeded_0")
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	assert_true(state.turn.allows_roll_dice())
	return state
