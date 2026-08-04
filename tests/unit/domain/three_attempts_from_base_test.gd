extends TestCase
## Business-critical тестове за трите опита при пионки в база (Task #103 /
## docs/V1_GAME_DESIGN.md §3.1; CURRENT_YELLOW_BEHAVIOR YEL-003 / YEL-004 /
## YEL-010–014; docs/V1_ARCHITECTURE.md §4.2 / §12 / §14).
##
## Правилото е в TurnRules (#94). Тук: поне 1 пионка в база (has_pawn_in_base,
## не строгото all-in-base) → 3 опита; всеки зар 1–5 без валиден ход → retry
## докато има опити; трети miss → TurnChanged; 6 на произволен опит → AWAITING_MOVE
## без консумация на опит; НИТО една пионка в база → 1 опит (bug report:
## обобщено от "всички в база" до "изобщо няма валиден ход").


var _rules: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_rules = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_base_roll_attempts_constant_is_three() -> void:
	assert_eq(TurnState.BASE_ROLL_ATTEMPTS, 3)
	assert_eq(TurnState.SINGLE_ROLL_ATTEMPTS, 1)


func test_all_pawns_in_base_true_only_when_every_pawn_is_base() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	assert_true(_rules.all_pawns_in_base(player))
	player.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(player.player_id))
	assert_false(_rules.all_pawns_in_base(player))


func test_all_pawns_in_base_false_when_any_pawn_finished() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_idx: int = route.size() - 1
	player.get_pawn_by_index(0).mark_finished(last_idx, route[last_idx])
	assert_false(_rules.all_pawns_in_base(player))
	# Bug report: 3 все още в база + 1 завършила пак трябва да получи
	# BASE_ROLL_ATTEMPTS — has_pawn_in_base (не строгото all_pawns_in_base)
	# решава броя опити.
	assert_true(_rules.has_pawn_in_base(player))
	assert_true(_rules.begin_player_turn(state, 0, 1))
	assert_eq(state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)


func test_begin_turn_all_in_base_gets_three_attempts_yel_003() -> void:
	var state := _setup_in_progress()
	assert_true(_rules.all_pawns_in_base(state.get_active_player()))
	assert_eq(state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_true(state.turn.is_awaiting_roll())
	assert_true(state.turn.allows_roll_dice())


## Bug report: пионка на дъската + още 3 в база пак получава BASE_ROLL_ATTEMPTS —
## само когато НИТО една пионка не е в база остава единствен опит (YEL-004).
func test_begin_turn_mixed_base_and_board_still_gets_three_attempts() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	player.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(player.player_id))
	assert_true(_rules.has_pawn_in_base(player))
	assert_true(_rules.begin_player_turn(state, 0, 1))
	assert_eq(state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)


func test_begin_turn_no_pawns_in_base_gets_single_attempt_yel_004() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_idx: int = route.size() - 1
	for i in PlayerState.PAWNS_PER_PLAYER:
		player.get_pawn_by_index(i).mark_finished(last_idx, route[last_idx])
	assert_false(_rules.has_pawn_in_base(player))
	assert_true(_rules.begin_player_turn(state, 0, 1))
	assert_eq(state.turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)


func test_first_base_miss_retries_with_two_left_yel_010() -> void:
	var state := _setup_in_progress()
	var rng := _fixed_rng(4)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.state.turn.base_attempts_remaining, 2)
	assert_true(result.state.turn.allows_roll_dice())
	assert_false(result.state.turn.has_dice_result())
	assert_eq(result.state.turn.valid_pawn_ids.size(), 0)
	assert_eq(result.event_count(), 1)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_eq((result.events[0] as DiceRolledEvent).value, 4)
	assert_false(_events_contain_valid_moves_changed(result.events))
	assert_false(_events_contain_turn_changed(result.events))


func test_every_face_one_to_five_retries_from_base() -> void:
	for face in range(DiceState.VALUE_MIN, DiceState.EXIT_BASE_VALUE):
		var state := _setup_in_progress()
		var rng := _fixed_rng(face)
		var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
		state.stamp_command(cmd)
		var result := _engine.validate_and_apply(state, cmd, rng)
		assert_true(result.accepted, "зар %d трябва да е приет" % face)
		assert_true(result.state.turn.is_awaiting_roll(),
				"зар %d трябва да остави AWAITING_ROLL" % face)
		assert_eq(result.state.turn.base_attempts_remaining, 2,
				"зар %d трябва да остави 2 опита" % face)
		assert_eq(result.state.turn.valid_pawn_ids.size(), 0)
		assert_eq(result.event_count(), 1)


func test_second_base_miss_retries_with_one_left_yel_011() -> void:
	var state := _setup_in_progress()
	var current := state
	for expected_remaining in [2, 1]:
		var rng := _fixed_rng(3)
		var cmd := RollDiceCommand.create_for_player(current.get_active_player_id())
		current.stamp_command(cmd)
		var result := _engine.validate_and_apply(current, cmd, rng)
		assert_true(result.accepted)
		assert_true(result.state.turn.is_awaiting_roll())
		assert_eq(result.state.turn.base_attempts_remaining, expected_remaining)
		assert_true(result.state.turn.allows_roll_dice())
		assert_eq(result.event_count(), 1)
		current = result.state


func test_third_base_miss_ends_turn_and_advances_yel_012() -> void:
	var state := _setup_in_progress()
	var active_before: int = state.active_player_index
	var player_before: StringName = state.get_active_player_id()
	var current := state
	var last: CommandResult = null
	for _i in TurnState.BASE_ROLL_ATTEMPTS:
		var rng := _fixed_rng(5)
		var cmd := RollDiceCommand.create_for_player(current.get_active_player_id())
		current.stamp_command(cmd)
		last = _engine.validate_and_apply(current, cmd, rng)
		assert_true(last.accepted)
		current = last.state

	assert_ne(current.active_player_index, active_before)
	assert_eq(current.get_active_player_id(), PlayerId.YELLOW)
	assert_true(current.turn.is_awaiting_roll())
	assert_eq(current.turn.turn_number, 2)
	assert_eq(current.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_true(_rules.all_pawns_in_base(current.get_active_player()))
	assert_true(last.events[0] is DiceRolledEvent)
	assert_true(last.events[1] is TurnChangedEvent)
	var changed := last.events[1] as TurnChangedEvent
	assert_eq(changed.previous_player_index, active_before)
	assert_eq(changed.previous_player_id, player_before)
	assert_eq(changed.new_player_index, current.active_player_index)
	assert_eq(changed.new_player_id, PlayerId.YELLOW)


## Bug report: 3 в база + 1 пионка заклещена в home stretch на последната клетка
## (само dice=1 я довършва, всичко друго overshoot-ва) — играчът пак трябва да
## получи BASE_ROLL_ATTEMPTS, не само 1 хвърляне.
func test_three_in_base_plus_stuck_home_stretch_pawn_gets_three_attempts() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_idx: int = route.size() - 1
	player.get_pawn_by_index(0).set_position(
			PawnZone.HOME_STRETCH, last_idx, route[last_idx])
	assert_true(_rules.begin_player_turn(state, 0, 1))
	assert_eq(state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)

	var current := state
	for expected_remaining in [2, 1]:
		var rng := _fixed_rng(3)
		var cmd := RollDiceCommand.create_for_player(current.get_active_player_id())
		current.stamp_command(cmd)
		var result := _engine.validate_and_apply(current, cmd, rng)
		assert_true(result.accepted)
		assert_true(result.state.turn.is_awaiting_roll(),
				"няма валиден ход (base пионки чакат 6, home stretch пионката overshoot-ва) → retry")
		assert_eq(result.state.turn.base_attempts_remaining, expected_remaining)
		assert_eq(result.state.turn.valid_pawn_ids.size(), 0)
		current = result.state

	var active_before: int = current.active_player_index
	var rng3 := _fixed_rng(4)
	var cmd3 := RollDiceCommand.create_for_player(current.get_active_player_id())
	current.stamp_command(cmd3)
	var result3 := _engine.validate_and_apply(current, cmd3, rng3)
	assert_true(result3.accepted)
	assert_ne(result3.state.active_player_index, active_before,
			"трети miss → TURN_END + смяна на играча")
	assert_true(result3.events[1] is TurnChangedEvent)


func test_six_on_first_attempt_offers_moves_yel_013() -> void:
	var result := _roll_six_after_misses(0)
	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_move())
	assert_true(result.state.turn.has_extra_roll_pending())
	assert_eq(result.state.turn.valid_pawn_ids.size(), PlayerState.PAWNS_PER_PLAYER)
	assert_eq(result.event_count(), 2)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(result.events[1] is ValidMovesChangedEvent)
	assert_false(_events_contain_turn_changed(result.events))


func test_six_on_second_attempt_offers_moves_yel_013() -> void:
	var result := _roll_six_after_misses(1)
	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_move())
	assert_true(result.state.turn.has_extra_roll_pending())
	assert_eq(result.state.turn.base_attempts_remaining, 2,
			"успешно 6 не консумира оставащите base attempts")
	assert_eq(result.state.turn.valid_pawn_ids.size(), PlayerState.PAWNS_PER_PLAYER)


func test_six_on_third_attempt_offers_moves_yel_013() -> void:
	var result := _roll_six_after_misses(2)
	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_move())
	assert_true(result.state.turn.has_extra_roll_pending())
	assert_eq(result.state.turn.base_attempts_remaining, 1)
	assert_eq(result.state.turn.valid_pawn_ids.size(), PlayerState.PAWNS_PER_PLAYER)
	assert_true(result.events[1] is ValidMovesChangedEvent)


func test_six_then_exit_grants_extra_roll_same_player_yel_013() -> void:
	var after_six := _roll_six_after_misses(0)
	assert_true(after_six.accepted)
	var player_id: StringName = after_six.state.get_active_player_id()
	var turn_before: int = after_six.state.turn.turn_number
	var pawn_id: StringName = after_six.state.turn.valid_pawn_ids[0] as StringName
	var move_cmd := MovePawnCommand.create_for_pawn(player_id, pawn_id)
	after_six.state.stamp_command(move_cmd)

	var after_move := _engine.validate_and_apply(
			after_six.state, move_cmd, _fixed_rng(6))

	assert_true(after_move.accepted)
	assert_eq(after_move.state.get_active_player_id(), player_id)
	assert_eq(after_move.state.turn.turn_number, turn_before)
	assert_true(after_move.state.turn.is_awaiting_roll())
	assert_true(after_move.state.turn.allows_roll_dice())
	assert_eq(
			after_move.state.turn.base_attempts_remaining,
			TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_false(after_move.state.turn.has_extra_roll_pending())
	assert_true(after_move.events[0] is PawnExitedBaseEvent)
	assert_false(_events_contain_turn_changed(after_move.events))


func test_roll_rejected_while_awaiting_move_after_six_yel_014() -> void:
	var after_six := _roll_six_after_misses(0)
	assert_true(after_six.state.turn.is_awaiting_move())
	var before := after_six.state.duplicate_state()
	var rng := _fixed_rng(3)
	var rng_before := rng.get_state()
	var cmd := RollDiceCommand.create_for_player(after_six.state.get_active_player_id())
	after_six.state.stamp_command(cmd)

	var result := _engine.validate_and_apply(after_six.state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)
	assert_eq(result.event_count(), 0)
	assert_true(after_six.state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


func test_move_pawn_rejected_during_base_retry() -> void:
	var state := _setup_in_progress()
	var miss := _engine.validate_and_apply(
			state,
			_stamped_roll(state),
			_fixed_rng(2))
	assert_true(miss.accepted)
	assert_true(miss.state.turn.is_awaiting_roll())
	assert_eq(miss.state.turn.base_attempts_remaining, 2)
	var before := miss.state.duplicate_state()
	var rng := _fixed_rng(6)
	var rng_before := rng.get_state()
	var pawn_id: StringName = miss.state.get_active_player().get_pawn_by_index(0).pawn_id
	var move_cmd := MovePawnCommand.create_for_pawn(
			miss.state.get_active_player_id(), pawn_id)
	miss.state.stamp_command(move_cmd)

	var result := _engine.validate_and_apply(miss.state, move_cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_WRONG_PHASE)
	assert_eq(result.event_count(), 0)
	assert_true(miss.state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_resolve_after_roll_miss_outcomes_match_yel_010_012() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	assert_eq(_rules.resolve_after_roll(turn, 2, []), TurnRules.OUTCOME_RETRY_ROLL)
	assert_eq(turn.base_attempts_remaining, 2)
	assert_eq(_rules.resolve_after_roll(turn, 3, []), TurnRules.OUTCOME_RETRY_ROLL)
	assert_eq(turn.base_attempts_remaining, 1)
	assert_eq(_rules.resolve_after_roll(turn, 4, []), TurnRules.OUTCOME_TURN_END)
	assert_true(turn.is_turn_end())


func test_resolve_after_roll_six_does_not_consume_base_attempt() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	assert_eq(turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	var outcome := _rules.resolve_after_roll(
			turn, 6, [&"green_0", &"green_1", &"green_2", &"green_3"])
	assert_eq(outcome, TurnRules.OUTCOME_AWAITING_MOVE)
	assert_eq(turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_true(turn.has_extra_roll_pending())


func test_resolve_after_roll_non_base_miss_ends_without_retry() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	assert_eq(turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	var outcome := _rules.resolve_after_roll(turn, 3, [])
	assert_eq(outcome, TurnRules.OUTCOME_TURN_END)
	assert_true(turn.is_turn_end())


func test_single_miss_on_board_advances_without_retry_yel_004() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	player.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(player.player_id))
	# Пионка на spawn + зар 1 е валиден ход — местяваме я в home stretch край,
	# за да няма валиден ход при 1–5 и да видим single-attempt край.
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_idx: int = route.size() - 1
	player.get_pawn_by_index(0).set_position(
			PawnZone.HOME_STRETCH, last_idx, route[last_idx])
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).set_position(
				PawnZone.HOME_STRETCH, last_idx, route[last_idx])
	state.turn.begin_player_turn(1, false)
	var active_before: int = state.active_player_index
	var rng := _fixed_rng(2)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_ne(result.state.active_player_index, active_before)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(result.events[1] is TurnChangedEvent)


## miss_count несполучливи 1–5, после 6. Връща CommandResult от шестицата.
func _roll_six_after_misses(miss_count: int) -> CommandResult:
	var current := _setup_in_progress()
	for _i in miss_count:
		var miss_rng := _fixed_rng(2)
		var miss_cmd := RollDiceCommand.create_for_player(
				current.get_active_player_id())
		current.stamp_command(miss_cmd)
		var miss_result := _engine.validate_and_apply(current, miss_cmd, miss_rng)
		assert_true(miss_result.accepted)
		assert_true(miss_result.state.turn.is_awaiting_roll())
		current = miss_result.state

	var six_rng := _fixed_rng(6)
	var six_cmd := RollDiceCommand.create_for_player(current.get_active_player_id())
	current.stamp_command(six_cmd)
	return _engine.validate_and_apply(current, six_cmd, six_rng)


func _stamped_roll(state: GameState) -> RollDiceCommand:
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)
	return cmd


func _events_contain_turn_changed(events: Array) -> bool:
	for entry in events:
		if entry is TurnChangedEvent:
			return true
	return false


func _events_contain_valid_moves_changed(events: Array) -> bool:
	for entry in events:
		if entry is ValidMovesChangedEvent:
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
