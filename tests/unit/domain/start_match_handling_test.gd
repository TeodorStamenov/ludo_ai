extends TestCase
## Business-critical тестове за StartMatchCommand handling (Task #84 /
## docs/V1_ARCHITECTURE.md, §4.2 / §4.3 / §4.4; CURRENT_YELLOW_BEHAVIOR YEL-001–003).
##
## Покрива:
##   - SETUP → IN_PROGRESS + първи ход AWAITING_ROLL с 3 base attempts.
##   - Events: MatchStarted → TurnChanged (initial activation).
##   - §12: reject при IN_PROGRESS; accept не консумира RNG.
##   - Restart от FINISHED е позволен.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_start_match_initializes_in_progress_and_awaiting_roll() -> void:
	var cfg := _two_player_config(42)
	var state := GameState.create_from_match_config(cfg)
	assert_true(state.is_setup())
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var rng_before := rng.get_state()
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted, "StartMatchCommand трябва да се приеме от SETUP")
	assert_true(result.is_valid())
	assert_true(result.state.is_in_progress())
	assert_eq(result.state.match_id, state.match_id)
	assert_eq(result.state.command_sequence, cmd.sequence)
	assert_eq(result.state.get_active_player_id(), PlayerId.GREEN)
	assert_eq(result.state.active_player_index, 0)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.state.turn.turn_number, 1)
	assert_eq(result.state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_true(result.state.turn.allows_roll_dice())
	assert_ne(rng.get_state(), rng_before,
			"#201: StartMatch планира първото появяване на подарък през rng")
	assert_true(state.is_setup(), "входният SETUP state не се мутира при rebuild")


func test_start_match_emits_match_started_then_turn_changed() -> void:
	var cfg := _two_player_config(7)
	var state := GameState.create_from_match_config(cfg)
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.event_count(), 2)
	var started := result.events[0] as MatchStartedEvent
	assert_true(started is MatchStartedEvent)
	assert_eq(started.match_id, result.state.match_id)
	assert_true(started.config.equals(cfg))
	assert_eq(started.command_sequence, cmd.sequence)
	assert_true(started.is_valid())

	var changed := result.events[1] as TurnChangedEvent
	assert_true(changed is TurnChangedEvent)
	assert_true(changed.is_initial_activation())
	assert_eq(changed.new_player_index, 0)
	assert_eq(changed.new_player_id, PlayerId.GREEN)
	assert_eq(changed.previous_player_id, &"")
	assert_eq(changed.command_sequence, cmd.sequence)
	assert_true(changed.is_valid())


func test_start_match_places_all_pawns_in_base() -> void:
	var cfg := _two_player_config(3)
	var state := GameState.create_from_match_config(cfg)
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	for player_entry in result.state.players:
		var player := player_entry as PlayerState
		assert_eq(player.pawns.size(), PlayerState.PAWNS_PER_PLAYER)
		for pawn_entry in player.pawns:
			var pawn := pawn_entry as PawnState
			assert_true(pawn.is_in_base(), "YEL-001: пионките стартират в база")


func test_start_match_rejected_while_in_progress_preserves_state_and_rng() -> void:
	var state := _setup_in_progress()
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := StartMatchCommand.create_with_config(state.match_config)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_INVALID_COMMAND)
	assert_eq(result.event_count(), 0)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_start_match_allowed_after_finished() -> void:
	var cfg := _two_player_config(11)
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.FINISHED)
	state.turn.enter_match_finished()
	state.command_sequence = 12
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)
	assert_eq(cmd.sequence, 13)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_in_progress())
	assert_eq(result.state.command_sequence, 13)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.event_count(), 2)


func test_start_match_dictionary_adapter_accepted() -> void:
	var cfg := _two_player_config(5)
	var state := GameState.create_from_match_config(cfg)
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)

	var result: Dictionary = _engine.apply_command(state, cmd, rng)

	assert_true(result["accepted"])
	assert_eq(result["error"], "")
	assert_eq((result["events"] as Array).size(), 2)
	assert_true((result["state"] as GameState).is_in_progress())


func _two_player_config(rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		if i == 0:
			seat.configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		else:
			seat.configure(
					MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	return cfg


func _setup_in_progress() -> GameState:
	var state := GameState.create_from_match_config(_two_player_config(42))
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	return state
