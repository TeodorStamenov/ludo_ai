extends TestCase
## Business-critical тестове за допълнително хвърляне при 6 (Task #102 /
## docs/V1_GAME_DESIGN.md §3.1; CURRENT_YELLOW_BEHAVIOR YEL-013 / YEL-032 /
## YEL-042 / YEL-043 / YEL-045; docs/V1_ARCHITECTURE.md §4.2 / §12 / §14).
##
## Правилото е в TurnRules (#93). Тук: зар 6 → grant_extra_roll; след ход →
## AWAITING_ROLL на същия играч без TurnChanged и с 1 опит; при 6 без валиден
## ход → пак extra roll; 1–5 → край / TurnChanged; поредица от 6-ци се трупа.


var _rules: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_rules = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_grants_extra_roll_only_on_six() -> void:
	assert_eq(TurnRules.EXTRA_ROLL_VALUE, DiceState.EXTRA_TURN_VALUE)
	assert_true(_rules.grants_extra_roll(DiceState.EXTRA_TURN_VALUE))
	for face in range(DiceState.VALUE_MIN, DiceState.EXTRA_TURN_VALUE):
		assert_false(_rules.grants_extra_roll(face),
				"зар %d не дава допълнителен ход" % face)


func test_complete_turn_action_extra_roll_keeps_turn_number_and_single_attempt() -> void:
	var turn := TurnState.create_for_player_turn(3, true)
	assert_eq(turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	turn.grant_extra_roll()
	turn.enter_resolving_move()

	var outcome := _rules.complete_turn_action(turn)

	assert_eq(outcome, TurnRules.OUTCOME_EXTRA_ROLL)
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.turn_number, 3)
	assert_false(turn.has_extra_roll_pending())
	assert_false(turn.has_dice_result())
	assert_eq(turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_true(turn.allows_roll_dice())


func test_resolve_after_move_on_six_enters_extra_roll() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	_rules.resolve_after_roll(turn, 6, [&"green_0"])
	assert_true(turn.has_extra_roll_pending())

	var outcome := _rules.resolve_after_move(turn, false)

	assert_eq(outcome, TurnRules.OUTCOME_EXTRA_ROLL)
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.turn_number, 1)
	assert_eq(turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_false(turn.has_extra_roll_pending())


func test_resolve_after_move_on_non_six_ends_turn_yel_042() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	_rules.resolve_after_roll(turn, 4, [&"green_0"])
	assert_false(turn.has_extra_roll_pending())

	var outcome := _rules.resolve_after_move(turn, false)

	assert_eq(outcome, TurnRules.OUTCOME_TURN_END)
	assert_true(turn.is_turn_end())


func test_roll_six_from_base_grants_pending_extra_yel_013() -> void:
	var state := _setup_in_progress()
	var rng := _fixed_rng(6)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_move())
	assert_true(result.state.turn.has_extra_roll_pending())
	assert_eq(result.state.turn.dice_value, 6)
	assert_true((result.events[0] as DiceRolledEvent).is_six())
	assert_false(_events_contain_turn_changed(result.events))


func test_exit_base_after_six_enters_extra_roll_same_player_yel_032() -> void:
	var state := _setup_in_progress()
	var player_id: StringName = state.get_active_player_id()
	var turn_before: int = state.turn.turn_number
	var rng := _fixed_rng(6)
	var roll_cmd := RollDiceCommand.create_for_player(player_id)
	state.stamp_command(roll_cmd)
	var after_roll := _engine.validate_and_apply(state, roll_cmd, rng)
	assert_true(after_roll.accepted)
	assert_true(after_roll.state.turn.has_extra_roll_pending())

	var pawn_id: StringName = after_roll.state.turn.valid_pawn_ids[0] as StringName
	var move_cmd := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_roll.state.stamp_command(move_cmd)
	var after_move := _engine.validate_and_apply(after_roll.state, move_cmd, rng)

	assert_true(after_move.accepted)
	assert_eq(after_move.state.get_active_player_id(), player_id)
	assert_eq(after_move.state.turn.turn_number, turn_before)
	assert_true(after_move.state.turn.is_awaiting_roll())
	assert_true(after_move.state.turn.allows_roll_dice())
	assert_eq(
			after_move.state.turn.base_attempts_remaining,
			TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_false(after_move.state.turn.has_extra_roll_pending())
	assert_false(after_move.state.turn.has_dice_result())
	assert_false(after_move.state.dice.has_result())
	assert_eq(after_move.event_count(), 1)
	assert_true(after_move.events[0] is PawnExitedBaseEvent)
	assert_false(_events_contain_turn_changed(after_move.events))


func test_board_move_on_six_keeps_player_without_turn_changed_yel_043() -> void:
	var state := _setup_pawn_on_spawn_awaiting_roll()
	var player_id: StringName = state.get_active_player_id()
	var active_before: int = state.active_player_index
	var turn_before: int = state.turn.turn_number
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := _fixed_rng(6)

	var roll_cmd := RollDiceCommand.create_for_player(player_id)
	state.stamp_command(roll_cmd)
	var after_roll := _engine.validate_and_apply(state, roll_cmd, rng)
	assert_true(after_roll.accepted)
	assert_true(after_roll.state.turn.has_extra_roll_pending())
	assert_true(after_roll.state.turn.has_valid_pawn(pawn_id))

	var move_cmd := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_roll.state.stamp_command(move_cmd)
	var after_move := _engine.validate_and_apply(after_roll.state, move_cmd, rng)

	assert_true(after_move.accepted)
	assert_eq(after_move.state.active_player_index, active_before)
	assert_eq(after_move.state.turn.turn_number, turn_before)
	assert_true(after_move.state.turn.is_awaiting_roll())
	assert_true(after_move.state.turn.allows_roll_dice())
	assert_eq(
			after_move.state.turn.base_attempts_remaining,
			TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_eq(after_move.event_count(), 1)
	assert_true(after_move.events[0] is PawnMovedEvent)
	assert_false(_events_contain_turn_changed(after_move.events))
	assert_eq(
			after_move.state.get_player(player_id).get_pawn(pawn_id).path_index, 6)


func test_board_move_on_non_six_advances_turn_yel_042() -> void:
	var state := _setup_pawn_on_spawn_awaiting_roll()
	var player_id: StringName = state.get_active_player_id()
	var active_before: int = state.active_player_index
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := _fixed_rng(4)

	var roll_cmd := RollDiceCommand.create_for_player(player_id)
	state.stamp_command(roll_cmd)
	var after_roll := _engine.validate_and_apply(state, roll_cmd, rng)
	assert_true(after_roll.accepted)
	assert_false(after_roll.state.turn.has_extra_roll_pending())

	var move_cmd := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_roll.state.stamp_command(move_cmd)
	var after_move := _engine.validate_and_apply(after_roll.state, move_cmd, rng)

	assert_true(after_move.accepted)
	assert_ne(after_move.state.active_player_index, active_before)
	assert_true(after_move.events[0] is PawnMovedEvent)
	assert_true(after_move.events[1] is TurnChangedEvent)


func test_six_with_no_valid_move_still_grants_extra_roll_yel_045() -> void:
	var state := _setup_pawn_blocked_in_home_stretch()
	var player_id: StringName = state.get_active_player_id()
	var active_before: int = state.active_player_index
	var turn_before: int = state.turn.turn_number
	var rng := _fixed_rng(6)
	var cmd := RollDiceCommand.create_for_player(player_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.active_player_index, active_before)
	assert_eq(result.state.turn.turn_number, turn_before)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_true(result.state.turn.allows_roll_dice())
	assert_eq(
			result.state.turn.base_attempts_remaining,
			TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_false(result.state.turn.has_extra_roll_pending())
	assert_false(result.state.turn.has_dice_result())
	assert_eq(result.event_count(), 1)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true((result.events[0] as DiceRolledEvent).is_six())
	assert_false(_events_contain_turn_changed(result.events))


func test_non_six_with_no_valid_move_ends_turn_yel_045() -> void:
	var state := _setup_pawn_blocked_in_home_stretch()
	var active_before: int = state.active_player_index
	var rng := _fixed_rng(3)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_ne(result.state.active_player_index, active_before)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(result.events[1] is TurnChangedEvent)


func test_consecutive_sixes_grant_another_extra_roll() -> void:
	var state := _setup_pawn_on_spawn_awaiting_roll()
	var player_id: StringName = state.get_active_player_id()
	var turn_before: int = state.turn.turn_number
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := _fixed_rng(6)

	var roll1 := RollDiceCommand.create_for_player(player_id)
	state.stamp_command(roll1)
	var after_roll1 := _engine.validate_and_apply(state, roll1, rng)
	assert_true(after_roll1.accepted)

	var move1 := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_roll1.state.stamp_command(move1)
	var after_move1 := _engine.validate_and_apply(after_roll1.state, move1, rng)
	assert_true(after_move1.accepted)
	assert_true(after_move1.state.turn.is_awaiting_roll())
	assert_eq(after_move1.state.get_active_player_id(), player_id)
	assert_eq(
			after_move1.state.turn.base_attempts_remaining,
			TurnState.SINGLE_ROLL_ATTEMPTS)

	var roll2 := RollDiceCommand.create_for_player(player_id)
	after_move1.state.stamp_command(roll2)
	var after_roll2 := _engine.validate_and_apply(after_move1.state, roll2, rng)
	assert_true(after_roll2.accepted)
	assert_true(after_roll2.state.turn.is_awaiting_move())
	assert_true(after_roll2.state.turn.has_extra_roll_pending())
	assert_true(after_roll2.state.turn.has_valid_pawn(pawn_id))

	var move2 := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_roll2.state.stamp_command(move2)
	var after_move2 := _engine.validate_and_apply(after_roll2.state, move2, rng)

	assert_true(after_move2.accepted)
	assert_eq(after_move2.state.get_active_player_id(), player_id)
	assert_eq(after_move2.state.turn.turn_number, turn_before)
	assert_true(after_move2.state.turn.is_awaiting_roll())
	assert_true(after_move2.state.turn.allows_roll_dice())
	assert_eq(after_move2.event_count(), 1)
	assert_true(after_move2.events[0] is PawnMovedEvent)
	assert_false(_events_contain_turn_changed(after_move2.events))


func test_extra_roll_then_non_six_move_advances_to_next_player() -> void:
	var state := _setup_pawn_on_spawn_awaiting_roll()
	var player_id: StringName = state.get_active_player_id()
	var active_before: int = state.active_player_index
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var six_rng := _fixed_rng(6)

	var roll_six := RollDiceCommand.create_for_player(player_id)
	state.stamp_command(roll_six)
	var after_six := _engine.validate_and_apply(state, roll_six, six_rng)
	var move_six := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_six.state.stamp_command(move_six)
	var after_extra := _engine.validate_and_apply(after_six.state, move_six, six_rng)
	assert_true(after_extra.state.turn.is_awaiting_roll())
	assert_eq(after_extra.state.active_player_index, active_before)

	var four_rng := _fixed_rng(4)
	var roll_four := RollDiceCommand.create_for_player(player_id)
	after_extra.state.stamp_command(roll_four)
	var after_four := _engine.validate_and_apply(after_extra.state, roll_four, four_rng)
	assert_true(after_four.accepted)
	assert_true(after_four.state.turn.is_awaiting_move())
	assert_false(after_four.state.turn.has_extra_roll_pending())

	var move_four := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_four.state.stamp_command(move_four)
	var after_done := _engine.validate_and_apply(after_four.state, move_four, four_rng)

	assert_true(after_done.accepted)
	assert_ne(after_done.state.active_player_index, active_before)
	assert_true(after_done.events[0] is PawnMovedEvent)
	assert_true(after_done.events[1] is TurnChangedEvent)


func _events_contain_turn_changed(events: Array) -> bool:
	for entry in events:
		if entry is TurnChangedEvent:
			return true
	return false


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


func _setup_pawn_on_spawn_awaiting_roll() -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	player.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.begin_player_turn(1, false)
	assert_eq(state.turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	return state


## Всички пионки в края на home stretch — зар 6/3 е overshoot (няма валиден ход).
## Базовите пионки биха излезли при 6, затова нито една не остава в база.
func _setup_pawn_blocked_in_home_stretch() -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_home_index: int = route.size() - 1
	var last_cell: StringName = route[last_home_index]
	for entry in player.pawns:
		(entry as PawnState).set_position(
				PawnZone.HOME_STRETCH, last_home_index, last_cell)
	state.turn.begin_player_turn(1, false)
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
