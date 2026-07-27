extends TestCase
## Business-critical тестове за фазата AWAITING_ROLL (Task #86 /
## docs/V1_ARCHITECTURE.md §4.2 / §4.3 / §12; CURRENT_YELLOW_BEHAVIOR
## YEL-010–014 / YEL-045).
##
## Покрива: RollDiceCommand accept/reject, retry при база, три misses →
## следващ играч, 6 → AWAITING_MOVE + ValidMovesChanged, детерминизъм.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_roll_rejected_wrong_phase_when_awaiting_move() -> void:
	var state := _setup_in_progress()
	state.turn.enter_awaiting_move(6, [&"green_0"])
	var before := state.duplicate_state()
	var rng := _fixed_rng(4)
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)
	assert_eq(result.event_count(), 0)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


func test_base_miss_retries_and_stays_awaiting_roll_yel_010() -> void:
	var state := _setup_in_progress()
	assert_eq(state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	var rng := _fixed_rng(3)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.state.turn.base_attempts_remaining, 2)
	assert_true(result.state.turn.allows_roll_dice())
	assert_false(result.state.turn.has_dice_result())
	assert_false(result.state.dice.has_result())
	assert_eq(result.event_count(), 1)
	var rolled := result.events[0] as DiceRolledEvent
	assert_eq(rolled.value, 3)
	assert_eq(rolled.player_id, PlayerId.GREEN)


func test_three_base_misses_advance_to_next_player_yel_012() -> void:
	var state := _setup_in_progress()
	var rng := _fixed_rng(2)
	var current := state
	var last: CommandResult = null
	for _i in TurnState.BASE_ROLL_ATTEMPTS:
		var cmd := RollDiceCommand.create_for_player(current.get_active_player_id())
		current.stamp_command(cmd)
		last = _engine.validate_and_apply(current, cmd, rng)
		assert_true(last.accepted)
		current = last.state

	assert_true(current.turn.is_awaiting_roll())
	assert_eq(current.active_player_index, 1)
	assert_eq(current.get_active_player_id(), PlayerId.YELLOW)
	assert_eq(current.turn.turn_number, 2)
	assert_eq(current.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_true(last.events[0] is DiceRolledEvent)
	assert_true(last.events[1] is TurnChangedEvent)
	var changed := last.events[1] as TurnChangedEvent
	assert_eq(changed.previous_player_index, 0)
	assert_eq(changed.new_player_index, 1)


func test_six_from_base_enters_awaiting_move_yel_013() -> void:
	var state := _setup_in_progress()
	var rng := _fixed_rng(6)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_move())
	assert_true(result.state.turn.has_extra_roll_pending())
	assert_true(result.state.turn.allows_move_pawn())
	assert_eq(result.state.turn.dice_value, 6)
	assert_eq(result.state.dice.value, 6)
	assert_eq(result.state.turn.valid_pawn_ids.size(), PlayerState.PAWNS_PER_PLAYER)
	assert_eq(result.event_count(), 2)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true((result.events[0] as DiceRolledEvent).is_six())
	var moves := result.events[1] as ValidMovesChangedEvent
	assert_true(moves is ValidMovesChangedEvent)
	assert_eq(moves.valid_pawn_ids.size(), PlayerState.PAWNS_PER_PLAYER)
	assert_true(moves.is_valid())


func test_same_seed_same_dice_sequence() -> void:
	var seed := 99
	var a := _roll_once(seed)
	var b := _roll_once(seed)
	assert_true(a.accepted and b.accepted)
	assert_eq(
			(a.events[0] as DiceRolledEvent).value,
			(b.events[0] as DiceRolledEvent).value)
	assert_eq(a.state.turn.phase, b.state.turn.phase)
	assert_eq(a.state.turn.base_attempts_remaining, b.state.turn.base_attempts_remaining)


func test_roll_with_pawn_on_board_uses_single_attempt_yel_004() -> void:
	var state := _setup_in_progress()
	_place_pawn_on_main_path(state.get_active_player(), 0)
	state.turn.begin_player_turn(1, false)
	assert_eq(state.turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	var rng := _fixed_rng(4)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	# Няма валиден ход (YEL-045 / overshoot) → TURN_END → следващ играч.
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.state.active_player_index, 1)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(result.events[1] is TurnChangedEvent)


func _roll_once(rng_seed: int) -> CommandResult:
	MatchId._reset_counter_for_tests()
	var state := _setup_in_progress_with_seed(rng_seed)
	var rng := SeededRandomSource.new(rng_seed)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)
	return _engine.validate_and_apply(state, cmd, rng)


func _fixed_rng(face: int) -> RandomSource:
	return _FixedFaceRandomSource.new(face)


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
	return _setup_in_progress_with_seed(42)


func _setup_in_progress_with_seed(rng_seed: int) -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config(rng_seed))
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state


func _place_pawn_on_main_path(player: PlayerState, pawn_index: int) -> void:
	var pawn := player.get_pawn_by_index(pawn_index)
	assert_not_null(pawn)
	pawn.exit_base_to_spawn(CellId.from_grid(6, 7))


## Test double: винаги връща фиксирано лице на зара (за YEL сценарии).
class _FixedFaceRandomSource extends RandomSource:
	var _face: int = DiceState.VALUE_MIN

	func _init(face: int) -> void:
		_face = face

	func next_int(min_val: int, max_val: int) -> int:
		return clampi(_face, min_val, max_val)

	func get_state() -> Dictionary:
		return {"seed": str(_face), "state": "0"}

	func set_state(state: Dictionary) -> void:
		_face = str(state.get("seed", _face)).to_int()
