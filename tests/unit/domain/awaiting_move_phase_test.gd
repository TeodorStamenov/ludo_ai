extends TestCase
## Business-critical тестове за фазата AWAITING_MOVE (Task #87 /
## docs/V1_ARCHITECTURE.md §4.2 / §4.3 / §12; CURRENT_YELLOW_BEHAVIOR
## YEL-024 / YEL-030 / YEL-032).
##
## Покрива: MovePawnCommand accept/reject, illegal pawn, exit-base при 6,
## extra roll след излизане, §12 reject без мутация.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_move_rejected_wrong_phase_when_awaiting_roll() -> void:
	var state := _setup_in_progress()
	assert_true(state.turn.is_awaiting_roll())
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)
	assert_eq(result.event_count(), 0)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


func test_move_rejected_illegal_when_pawn_not_valid_yel_024() -> void:
	var state := _setup_awaiting_move_after_six()
	# Собствена пионка извън valid_pawn_ids (чужда би fail-нала is_valid()).
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	state.turn.set_valid_pawn_ids([
		state.get_active_player().get_pawn_by_index(1).pawn_id,
	])
	assert_false(state.turn.has_valid_pawn(pawn_id))
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_exit_base_on_six_enters_extra_roll_yel_030_032() -> void:
	var state := _setup_awaiting_move_after_six()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var from_cell: StringName = pawn.cell_id
	var spawn := Classic15x15Board.spawn_cell_for(player.player_id)
	assert_true(pawn.is_in_base())
	assert_ne(spawn, &"")
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_active_player().get_pawn(pawn.pawn_id)
	assert_true(moved.is_on_main_path())
	assert_eq(moved.path_index, PawnState.PATH_INDEX_AT_SPAWN)
	assert_eq(moved.cell_id, spawn)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_true(result.state.turn.allows_roll_dice())
	assert_eq(result.state.active_player_index, state.active_player_index)
	assert_eq(result.state.turn.turn_number, state.turn.turn_number)
	assert_false(result.state.turn.has_dice_result())
	assert_eq(result.event_count(), 1)
	var exited := result.events[0] as PawnExitedBaseEvent
	assert_true(exited is PawnExitedBaseEvent)
	assert_eq(exited.pawn_id, pawn.pawn_id)
	assert_eq(exited.from_cell_id, from_cell)
	assert_eq(exited.spawn_cell_id, spawn)
	assert_true(exited.is_valid())


func test_roll_then_exit_base_preserves_extra_roll_flow() -> void:
	var state := _setup_in_progress()
	var rng := _fixed_rng(6)
	var roll_cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(roll_cmd)
	var after_roll := _engine.validate_and_apply(state, roll_cmd, rng)
	assert_true(after_roll.accepted)
	assert_true(after_roll.state.turn.is_awaiting_move())

	var pawn_id: StringName = (
			after_roll.state.turn.valid_pawn_ids[0] as StringName)
	var move_cmd := MovePawnCommand.create_for_pawn(
			after_roll.state.get_active_player_id(), pawn_id)
	after_roll.state.stamp_command(move_cmd)
	var after_move := _engine.validate_and_apply(after_roll.state, move_cmd, rng)

	assert_true(after_move.accepted)
	assert_true(after_move.state.turn.is_awaiting_roll())
	assert_eq(after_move.state.get_active_player_id(), PlayerId.GREEN)
	assert_true(after_move.events[0] is PawnExitedBaseEvent)


func test_board_path_move_still_not_implemented() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.enter_awaiting_move(4, [pawn.pawn_id])
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_NOT_IMPLEMENTED)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


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
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state


func _setup_awaiting_move_after_six() -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn_ids: Array = []
	for entry in player.pawns:
		pawn_ids.append((entry as PawnState).pawn_id)
	state.turn.enter_awaiting_move(6, pawn_ids)
	state.turn.grant_extra_roll()
	state.dice.set_roll(player.player_id, 6)
	assert_true(state.turn.is_awaiting_move())
	assert_true(state.turn.allows_move_pawn())
	assert_true(state.turn.has_extra_roll_pending())
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
