extends TestCase
## Business-critical тестове за базовия GameEngine (Task #83 /
## docs/V1_ARCHITECTURE.md, §3 / §4.3 / §12).
##
## Покрива:
##   - Domain: RefCounted, път game/domain/rules/.
##   - validate_and_apply → CommandResult; apply_command → Dictionary адаптер.
##   - §12: невалидна / отхвърлена команда не променя state или RNG.
##   - Envelope reject: wrong player, match finished, sequence mismatch.
##   - MovePawn извън AWAITING_MOVE → wrong_phase (без RNG).


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()


func test_game_engine_extends_ref_counted() -> void:
	assert_true(_engine is RefCounted,
			"GameEngine трябва да extends RefCounted — domain слой без Node")
	var as_object: Object = _engine
	assert_false(as_object is Node,
			"GameEngine не трябва да extends Node")


func test_game_engine_script_is_in_domain_rules() -> void:
	var path: String = _engine.get_script().resource_path
	assert_true(path.contains("game/domain/rules/"),
			"GameEngine трябва да е в game/domain/rules/")
	assert_false(path.contains("application/"),
			"GameEngine не трябва да е в application/")
	assert_false(path.contains("presentation/"),
			"GameEngine не трябва да е в presentation/")


func test_validate_and_apply_returns_command_result() -> void:
	var state := GameState.new()
	var rng := SeededRandomSource.new(42)
	var result := _engine.validate_and_apply(state, GameCommand.new(), rng)
	assert_true(result is CommandResult,
			"validate_and_apply трябва да връща CommandResult")
	assert_true(result.is_valid(),
			"reject резултатът трябва да удовлетворява CommandResult.is_valid()")


func test_apply_command_dictionary_adapter_matches_session_contract() -> void:
	var state := GameState.new()
	var rng := SeededRandomSource.new(42)
	var result: Dictionary = _engine.apply_command(state, GameCommand.new(), rng)
	assert_has(result, "accepted")
	assert_has(result, "state")
	assert_has(result, "events")
	assert_has(result, "error")
	assert_typeof(result["accepted"], TYPE_BOOL)
	assert_typeof(result["events"], TYPE_ARRAY)
	assert_typeof(result["error"], TYPE_STRING)
	assert_false(result["accepted"])
	assert_eq(result["state"], state)
	assert_eq((result["events"] as Array).size(), 0)
	assert_eq(result["error"], String(CommandError.CODE_INVALID_COMMAND))


func test_invalid_command_does_not_mutate_state_or_rng() -> void:
	var state := _setup_in_progress()
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(100)
	var rng_before := rng.get_state()

	var result := _engine.validate_and_apply(state, GameCommand.new(), rng)

	assert_false(result.accepted)
	assert_eq(result.error.code, CommandError.CODE_INVALID_COMMAND)
	assert_eq(result.event_count(), 0)
	assert_eq(result.state, state)
	assert_true(state.equals(before),
			"§12: reject не трябва да променя GameState")
	assert_eq(rng.get_state(), rng_before,
			"§12: reject не трябва да консумира RNG")


func test_null_command_is_rejected_without_rng_use() -> void:
	var state := GameState.new()
	var rng := SeededRandomSource.new(7)
	var rng_before := rng.get_state()
	var result := _engine.validate_and_apply(state, null, rng)
	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_INVALID_COMMAND)
	assert_eq(rng.get_state(), rng_before)


func test_start_match_accepted_from_setup_schedules_gift_spawn_via_rng() -> void:
	var cfg := _two_player_config(11)
	var state := GameState.create_from_match_config(cfg)
	assert_true(state.is_setup())
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var rng_before := rng.get_state()
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_in_progress())
	assert_eq(result.event_count(), 2)
	assert_ne(rng.get_state(), rng_before,
			"#201: StartMatch планира първото появяване на подарък през rng")
	assert_eq(result.state.rng_state, rng.get_state(),
			"§12: rng_state трябва да е captured след консумацията")
	assert_true(state.is_setup(),
			"входният SETUP state остава непроменен при rebuild")


func test_start_match_rejected_when_match_already_in_progress() -> void:
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


func test_roll_dice_accepted_in_awaiting_roll() -> void:
	var state := _setup_in_progress()
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(state.equals(before), "входният state не се мутира")
	assert_false(rng.get_state() == rng_before, "приетият roll консумира RNG")


func test_move_pawn_wrong_phase_when_awaiting_roll() -> void:
	var state := _setup_in_progress()
	var active := state.get_active_player()
	var pawn_id: StringName = (active.pawns[0] as PawnState).pawn_id
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(active.player_id, pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_wrong_player_is_rejected_before_handler() -> void:
	var state := _setup_in_progress()
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(PlayerId.YELLOW)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PLAYER)
	assert_eq(result.event_count(), 0)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_finished_match_rejects_player_commands() -> void:
	var state := _setup_in_progress()
	state.set_phase(MatchPhase.FINISHED)
	state.turn.enter_match_finished()
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_MATCH_FINISHED)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_sequence_mismatch_is_rejected() -> void:
	var state := _setup_in_progress()
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	cmd.match_id = state.match_id
	cmd.sequence = state.next_command_sequence() + 5

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_SEQUENCE_MISMATCH)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_wrong_match_is_rejected_without_rng_use() -> void:
	var state := _setup_in_progress()
	assert_true(state.match_id != &"")
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	cmd.match_id = &"m_9999999999999_0"
	cmd.sequence = state.next_command_sequence()

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_MATCH)
	assert_eq(result.event_count(), 0)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_roll_dice_rejected_when_match_not_active() -> void:
	var state := GameState.create_from_match_config(_two_player_config(3))
	assert_true(state.is_setup())
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_MATCH_NOT_ACTIVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


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
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config(42))
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state
