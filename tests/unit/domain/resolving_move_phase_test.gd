extends TestCase
## Business-critical тестове за фазата RESOLVING_MOVE (Task #88 /
## docs/V1_ARCHITECTURE.md §4.2 / §4.3 / §12; CURRENT_YELLOW_BEHAVIOR
## YEL-040–043 / YEL-052).
##
## Покрива: ход по маршрута + PawnMoved, TURN_END след 1–5, extra roll след 6,
## home-stretch overshoot reject без мутация.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_board_move_four_from_spawn_yel_041() -> void:
	var state := _setup_awaiting_move_on_spawn(4)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var from_cell: StringName = pawn.cell_id
	var expected_cell: StringName = route[4]
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_on_main_path())
	assert_eq(moved.path_index, 4)
	assert_eq(moved.cell_id, expected_cell)
	assert_eq(result.event_count(), 2)
	var moved_event := result.events[0] as PawnMovedEvent
	assert_true(moved_event is PawnMovedEvent)
	assert_eq(moved_event.pawn_id, pawn.pawn_id)
	assert_eq(moved_event.from_cell_id, from_cell)
	assert_eq(moved_event.to_cell_id, expected_cell)
	assert_eq(moved_event.zone, PawnZone.MAIN_PATH)
	assert_true(result.events[1] is TurnChangedEvent)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.state.get_active_player_id(), PlayerId.YELLOW)


func test_normal_move_ends_turn_yel_042() -> void:
	var state := _setup_awaiting_move_on_spawn(3)
	var active_before: int = state.active_player_index
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.active_player_index, active_before)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is TurnChangedEvent)


func test_six_on_board_grants_extra_roll_yel_043() -> void:
	var state := _setup_awaiting_move_on_spawn(6)
	state.turn.grant_extra_roll()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var active_before: int = state.active_player_index
	var turn_before: int = state.turn.turn_number
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_eq(moved.path_index, 6)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_true(result.state.turn.allows_roll_dice())
	assert_eq(result.state.active_player_index, active_before)
	assert_eq(result.state.turn.turn_number, turn_before)
	assert_false(result.state.turn.has_dice_result())
	assert_eq(result.event_count(), 1)
	assert_true(result.events[0] is PawnMovedEvent)


func test_home_stretch_overshoot_rejected_yel_052() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_home_index: int = route.size() - 1
	var from_index: int = last_home_index - 1
	pawn.set_position(PawnZone.HOME_STRETCH, from_index, route[from_index])
	state.turn.enter_awaiting_move(6, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, 6)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_roll_then_board_move_enters_resolving_then_advances() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	var rng := _fixed_rng(4)
	var roll_cmd := RollDiceCommand.create_for_player(player.player_id)
	state.stamp_command(roll_cmd)
	var after_roll := _engine.validate_and_apply(state, roll_cmd, rng)
	assert_true(after_roll.accepted)
	assert_true(after_roll.state.turn.is_awaiting_move())
	assert_true(after_roll.state.turn.has_valid_pawn(pawn.pawn_id))

	var move_cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	after_roll.state.stamp_command(move_cmd)
	var after_move := _engine.validate_and_apply(after_roll.state, move_cmd, rng)

	assert_true(after_move.accepted)
	assert_true(after_move.events[0] is PawnMovedEvent)
	assert_true(after_move.state.turn.is_awaiting_roll())
	assert_eq(after_move.state.get_active_player_id(), PlayerId.YELLOW)


func test_enter_home_stretch_from_main_path_yel_050() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home_index: int = Classic15x15Board.PLAYER_ROUTE_LENGTH - Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER
	var from_index: int = first_home_index - 2
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])
	state.turn.enter_awaiting_move(2, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, 2)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_in_home_stretch())
	assert_eq(moved.path_index, first_home_index)
	assert_eq(moved.cell_id, route[first_home_index])
	var moved_event := result.events[0] as PawnMovedEvent
	assert_eq(moved_event.zone, PawnZone.HOME_STRETCH)


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


func _setup_awaiting_move_on_spawn(dice_value: int) -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_true(state.turn.is_awaiting_move())
	assert_true(pawn.is_on_main_path())
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
