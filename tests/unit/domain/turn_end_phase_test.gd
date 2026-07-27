extends TestCase
## Business-critical тестове за фазата TURN_END (Task #89 /
## docs/V1_ARCHITECTURE.md §4.2 / §4.3 / §12; docs/V1_GAME_DESIGN.md §3.1 / §4.3;
## CURRENT_YELLOW_BEHAVIOR YEL-042 / YEL-043 / YEL-045).
##
## Покрива: advance + TurnChanged, без TurnChanged при extra roll, skip на
## класирани, опити на следващия играч, изтичане на щит при нов ход на owner.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_normal_move_emits_turn_changed_and_advances_yel_042() -> void:
	var state := _setup_awaiting_move_on_spawn(3)
	var previous_index: int = state.active_player_index
	var previous_id: StringName = state.get_active_player_id()
	var turn_before: int = state.turn.turn_number
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(previous_id, pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_true(result.state.turn.allows_roll_dice())
	assert_ne(result.state.active_player_index, previous_index)
	assert_eq(result.state.turn.turn_number, turn_before + 1)
	assert_false(result.state.turn.has_dice_result())
	assert_false(result.state.dice.has_result())
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is TurnChangedEvent)
	var changed := result.events[1] as TurnChangedEvent
	assert_eq(changed.previous_player_index, previous_index)
	assert_eq(changed.new_player_index, result.state.active_player_index)
	assert_eq(changed.previous_player_id, previous_id)
	assert_eq(changed.new_player_id, result.state.get_active_player_id())
	assert_true(changed.is_valid())


func test_six_extra_roll_keeps_same_player_without_turn_changed_yel_043() -> void:
	var state := _setup_awaiting_move_on_spawn(6)
	state.turn.grant_extra_roll()
	var previous_index: int = state.active_player_index
	var turn_before: int = state.turn.turn_number
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.active_player_index, previous_index)
	assert_eq(result.state.turn.turn_number, turn_before)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_true(result.state.turn.allows_roll_dice())
	assert_eq(result.event_count(), 1)
	assert_true(result.events[0] is PawnMovedEvent)


func test_no_valid_board_move_ends_turn_yel_045() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_home_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_home_index, route[last_home_index])
	state.turn.begin_player_turn(1, false)
	var previous_index: int = state.active_player_index
	var rng := _fixed_rng(3)
	var cmd := RollDiceCommand.create_for_player(player.player_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(result.events[1] is TurnChangedEvent)
	assert_ne(result.state.active_player_index, previous_index)
	assert_true(result.state.turn.is_awaiting_roll())


func test_advance_skips_ranked_player_through_engine() -> void:
	var state := _setup_four_player_awaiting_move(2)
	var ranked := state.get_player_by_index(1)
	state.rank_player(ranked.player_id)
	assert_true(ranked.is_ranked())
	var previous_index: int = state.active_player_index
	assert_eq(previous_index, 0)
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.active_player_index, 2)
	var changed := result.events[1] as TurnChangedEvent
	assert_eq(changed.previous_player_index, 0)
	assert_eq(changed.new_player_index, 2)


func test_next_player_gets_base_attempts_when_all_in_base_yel_003() -> void:
	var state := _setup_awaiting_move_on_spawn(4)
	var next_player := state.get_player_by_index(1)
	assert_true(TurnRules.new().all_pawns_in_base(next_player))
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.active_player_index, 1)
	assert_eq(result.state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)


func test_next_player_single_attempt_when_pawn_on_board_yel_004() -> void:
	var state := _setup_awaiting_move_on_spawn(4)
	var next_player := state.get_player_by_index(1)
	next_player.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(next_player.player_id))
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.active_player_index, 1)
	assert_eq(result.state.turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)


func test_shield_expires_when_owner_becomes_active_again() -> void:
	var state := _setup_awaiting_move_on_spawn(3)
	var owner := state.get_active_player()
	var shielded := owner.get_pawn_by_index(0)
	shielded.apply_shield(1)
	assert_true(shielded.has_shield())
	var rng := SeededRandomSource.new(state.get_rng_seed())

	var first_move := MovePawnCommand.create_for_pawn(owner.player_id, shielded.pawn_id)
	state.stamp_command(first_move)
	var after_owner := _engine.validate_and_apply(state, first_move, rng)
	assert_true(after_owner.accepted)
	assert_true(after_owner.state.get_player(owner.player_id).get_pawn(shielded.pawn_id).has_shield())
	assert_eq(after_owner.state.get_active_player_id(), PlayerId.YELLOW)

	var yellow := after_owner.state.get_active_player()
	var yellow_pawn := yellow.get_pawn_by_index(0)
	yellow_pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(yellow.player_id))
	after_owner.state.turn.enter_awaiting_move(2, [yellow_pawn.pawn_id])
	after_owner.state.dice.set_roll(yellow.player_id, 2)
	var yellow_move := MovePawnCommand.create_for_pawn(yellow.player_id, yellow_pawn.pawn_id)
	after_owner.state.stamp_command(yellow_move)
	var after_yellow := _engine.validate_and_apply(after_owner.state, yellow_move, rng)

	assert_true(after_yellow.accepted)
	assert_eq(after_yellow.state.get_active_player_id(), owner.player_id)
	assert_false(
			after_yellow.state.get_player(owner.player_id).get_pawn(shielded.pawn_id).has_shield(),
			"щитът изтича в началото на следващия ход на притежателя")


func test_commands_rejected_while_match_turn_machine_finished() -> void:
	var rules := TurnRules.new()
	var state := _setup_in_progress()
	rules.begin_player_turn(state, 0, 1)
	state.rank_player(state.get_player_by_index(0).player_id)
	state.rank_player(state.get_player_by_index(1).player_id)
	state.turn.enter_turn_end()
	var advance: Dictionary = rules.advance_from_turn_end(state, 1)
	assert_eq(advance["outcome"], TurnRules.OUTCOME_MATCH_FINISHED)
	assert_true(state.turn.is_match_finished())
	assert_false(TurnPhase.accepts_command(state.turn.phase))
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := RollDiceCommand.create_for_player(PlayerId.GREEN)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)


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


func _four_player_config(rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = rng_seed
	return cfg


func _setup_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state


func _setup_awaiting_move_on_spawn(dice_value: int) -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_true(state.turn.is_awaiting_move())
	return state


func _setup_four_player_awaiting_move(dice_value: int) -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_four_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(0)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	return state


## Test double: винаги връща фиксирано лице на зара.
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
