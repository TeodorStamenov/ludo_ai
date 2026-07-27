extends TestCase
## Business-critical тестове за GameEngine.get_legal_actions (Task #128 /
## docs/V1_ARCHITECTURE.md §4.2 / §5.3 / §12).
##
## Инварианти: Human/AI/Remote виждат един и същ набор; всяко върнато действие
## се приема от validate_and_apply; MoveRules филтрира stale valid_pawn_ids.


var _engine: GameEngine


func before_each() -> void:
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_legal_actions_roll_dice_when_awaiting_roll() -> void:
	var state := _setup_in_progress()
	var actions := _engine.get_legal_actions(state)
	assert_eq(actions.size(), 1)
	assert_true(actions[0] is RollDiceCommand)
	var roll := actions[0] as RollDiceCommand
	assert_eq(roll.player_id, PlayerId.GREEN)
	assert_eq(roll.match_id, state.match_id)
	assert_eq(roll.sequence, state.next_command_sequence())


func test_legal_actions_move_pawns_after_six_from_base() -> void:
	var state := _setup_awaiting_move_after_six()
	var actions := _engine.get_legal_actions(state)
	assert_eq(actions.size(), PlayerState.PAWNS_PER_PLAYER)
	var seen: Dictionary = {}
	for entry in actions:
		assert_true(entry is MovePawnCommand)
		var move := entry as MovePawnCommand
		assert_eq(move.player_id, PlayerId.GREEN)
		assert_eq(move.match_id, state.match_id)
		assert_eq(move.sequence, state.next_command_sequence())
		assert_false(seen.has(String(move.pawn_id)))
		seen[String(move.pawn_id)] = true
		assert_true(state.turn.has_valid_pawn(move.pawn_id))


func test_legal_actions_empty_when_not_accepting_commands() -> void:
	var state := GameState.create_from_match_config(_two_player_config())
	assert_eq(_engine.get_legal_actions(state).size(), 0,
			"SETUP → празен списък")

	state = _setup_in_progress()
	state.turn.enter_resolving_move()
	assert_eq(_engine.get_legal_actions(state).size(), 0,
			"RESOLVING_MOVE → празен списък")

	state = _setup_in_progress()
	state.set_phase(MatchPhase.FINISHED)
	state.turn.enter_match_finished()
	assert_eq(_engine.get_legal_actions(state).size(), 0,
			"FINISHED → празен списък")

	assert_eq(_engine.get_legal_actions(null).size(), 0)


func test_legal_actions_filters_unmovable_pawn_in_valid_ids() -> void:
	var state := _setup_awaiting_move_after_six()
	var player := state.get_active_player()
	var finished := player.get_pawn_by_index(0)
	finished.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH - 1)
	assert_true(state.turn.has_valid_pawn(finished.pawn_id))

	var actions := _engine.get_legal_actions(state)
	assert_eq(actions.size(), PlayerState.PAWNS_PER_PLAYER - 1)
	for entry in actions:
		var move := entry as MovePawnCommand
		assert_ne(move.pawn_id, finished.pawn_id,
				"FINISHED пионка не влиза в legal actions")


func test_each_legal_action_is_accepted_by_validate_and_apply() -> void:
	var state := _setup_in_progress()
	var roll_actions := _engine.get_legal_actions(state)
	assert_eq(roll_actions.size(), 1)
	var rng := _FixedFaceRandomSource.new(6)
	var roll_result := _engine.validate_and_apply(
			state, roll_actions[0] as GameCommand, rng)
	assert_true(roll_result.accepted,
			"RollDice от get_legal_actions трябва да се приеме")
	assert_true(roll_result.state.turn.is_awaiting_move())

	var move_state: GameState = roll_result.state
	var move_actions := _engine.get_legal_actions(move_state)
	assert_true(move_actions.size() > 0)
	var before_rng := rng.get_state()
	var move_result := _engine.validate_and_apply(
			move_state, move_actions[0] as GameCommand, rng)
	assert_true(move_result.accepted,
			"MovePawn от get_legal_actions трябва да се приеме")
	assert_eq(rng.get_state(), before_rng,
			"MovePawn не консумира RNG")


func test_legal_actions_do_not_mutate_state() -> void:
	var state := _setup_awaiting_move_after_six()
	var before := state.duplicate_state()
	var actions := _engine.get_legal_actions(state)
	assert_true(actions.size() > 0)
	assert_true(state.equals(before),
			"get_legal_actions не трябва да мутира GameState")


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
	return state


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
