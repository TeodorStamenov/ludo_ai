extends TestCase
## Business-critical тестове за изчисляване на валидни пионки след зар (Task #95 /
## docs/V1_GAME_DESIGN.md §3; CURRENT_YELLOW_BEHAVIOR YEL-020 / YEL-044 / YEL-045 /
## YEL-052 / YEL-053 / YEL-055; docs/V1_ARCHITECTURE.md §4.2 / §4.3).
##
## Инварианти: collect_valid_pawn_ids е source of truth след RollDice;
## база само при 6; дъска само при точен път без overshoot; заета home-stretch
## дестинация / последна клетка → невалидна; FINISHED изключени.


var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_rules = MoveRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_collect_empty_when_all_in_base_and_not_six_yel_031() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	for face in range(DiceState.VALUE_MIN, DiceState.EXIT_BASE_VALUE):
		assert_eq(_rules.collect_valid_pawn_ids(state, player, face).size(), 0)


func test_collect_all_base_pawns_on_six_yel_030() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var valid: Array = _rules.collect_valid_pawn_ids(
			state, player, DiceState.EXIT_BASE_VALUE)
	assert_eq(valid.size(), PlayerState.PAWNS_PER_PLAYER)
	for entry in player.pawns:
		assert_true(valid.has((entry as PawnState).pawn_id))


func test_collect_mixed_base_and_board_on_six_yel_044() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var on_board := player.get_pawn_by_index(0)
	_place_on_spawn(player, on_board)
	var valid: Array = _rules.collect_valid_pawn_ids(state, player, 6)
	assert_true(valid.has(on_board.pawn_id), "пионка на дъската е валидна при 6")
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		assert_true(valid.has(player.get_pawn_by_index(i).pawn_id),
				"базова пионка е валидна при 6 (YEL-044)")
	assert_eq(valid.size(), PlayerState.PAWNS_PER_PLAYER)


func test_collect_board_only_excludes_base_on_four() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var on_board := player.get_pawn_by_index(0)
	_place_on_spawn(player, on_board)
	var valid: Array = _rules.collect_valid_pawn_ids(state, player, 4)
	assert_eq(valid.size(), 1)
	assert_eq(valid[0], on_board.pawn_id)


func test_collect_excludes_finished_pawns() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var finished := player.get_pawn_by_index(0)
	finished.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH - 1)
	var on_board := player.get_pawn_by_index(1)
	_place_on_spawn(player, on_board)
	var valid: Array = _rules.collect_valid_pawn_ids(state, player, 3)
	assert_false(valid.has(finished.pawn_id))
	assert_true(valid.has(on_board.pawn_id))


func test_collect_overshoot_in_home_stretch_excluded_yel_052() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var from_index: int = route.size() - 2
	pawn.set_position(PawnZone.HOME_STRETCH, from_index, route[from_index])
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size() - 1)
	assert_eq(_rules.collect_valid_pawn_ids(state, player, 1).size(), 1)
	assert_eq(_rules.collect_valid_pawn_ids(state, player, 6).size(), 0,
			"YEL-052: overshoot → няма валидна пионка")


func test_collect_occupied_home_dest_excluded_yel_053() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = (
			Classic15x15Board.PLAYER_ROUTE_LENGTH
			- Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
	var mover := player.get_pawn_by_index(0)
	var blocker := player.get_pawn_by_index(1)
	mover.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	blocker.set_position(
			PawnZone.HOME_STRETCH, first_home + 2, route[first_home + 2])
	for i in range(2, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size() - 1)
	var valid: Array = _rules.collect_valid_pawn_ids(state, player, 2)
	assert_false(valid.has(mover.pawn_id),
			"YEL-053: заета крайна home клетка → невалиден ход")
	assert_eq(valid.size(), 0)


func test_collect_pawn_on_last_cell_never_valid_yel_055() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_index: int = route.size() - 1
	for entry in player.pawns:
		(entry as PawnState).set_position(
				PawnZone.HOME_STRETCH, last_index, route[last_index])
	for face in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
		assert_eq(_rules.collect_valid_pawn_ids(state, player, face).size(), 0,
				"YEL-055: пионка на последната клетка не е валидна при зар %d" % face)


func test_engine_roll_four_on_spawn_emits_valid_moves() -> void:
	var state := _setup_pawn_on_spawn_awaiting_roll()
	var player := state.get_active_player()
	var pawn_id: StringName = player.get_pawn_by_index(0).pawn_id
	var rng := _fixed_rng(4)
	var cmd := RollDiceCommand.create_for_player(player.player_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_move())
	assert_eq(result.state.turn.valid_pawn_ids.size(), 1)
	assert_eq(result.state.turn.valid_pawn_ids[0], pawn_id)
	assert_eq(result.event_count(), 2)
	assert_true(result.events[0] is DiceRolledEvent)
	var moves := result.events[1] as ValidMovesChangedEvent
	assert_true(moves is ValidMovesChangedEvent)
	assert_true(moves.contains_pawn(pawn_id))
	assert_true(moves.is_valid())


func test_engine_roll_no_valid_move_ends_turn_yel_045() -> void:
	var state := _setup_all_on_last_home_cell()
	var active_before: int = state.active_player_index
	var rng := _fixed_rng(3)
	var cmd := RollDiceCommand.create_for_player(state.get_active_player_id())
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.turn.valid_pawn_ids.size(), 0)
	assert_ne(result.state.active_player_index, active_before)
	assert_true(result.events[0] is DiceRolledEvent)
	assert_true(result.events[1] is TurnChangedEvent)


func test_can_move_pawn_matches_collect() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var on_board := player.get_pawn_by_index(0)
	_place_on_spawn(player, on_board)
	for face in [1, 4, 6]:
		var valid: Array = _rules.collect_valid_pawn_ids(state, player, face)
		for entry in player.pawns:
			var pawn := entry as PawnState
			var expected: bool = valid.has(pawn.pawn_id)
			assert_eq(
					_rules.can_move_pawn(state, player, pawn, face),
					expected,
					"can_move_pawn трябва да съвпада с collect при зар %d" % face)


func _place_on_spawn(player: PlayerState, pawn: PawnState) -> void:
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))


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
	_place_on_spawn(player, player.get_pawn_by_index(0))
	state.turn.begin_player_turn(1, false)
	assert_eq(state.turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)
	return state


func _setup_all_on_last_home_cell() -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_index: int = route.size() - 1
	for entry in player.pawns:
		(entry as PawnState).set_position(
				PawnZone.HOME_STRETCH, last_index, route[last_index])
	state.turn.begin_player_turn(1, false)
	return state


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


func _fixed_rng(face: int) -> RandomSource:
	return _FixedFaceRandomSource.new(face)


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
