extends TestCase
## Business-critical тестове за излизане от база само при 6 (Task #92 /
## docs/V1_GAME_DESIGN.md §3; CURRENT_YELLOW_BEHAVIOR YEL-030 / YEL-031;
## docs/V1_ARCHITECTURE.md §4 / §12).
##
## Инварианти: зар 1–5 → базовите пионки не са валиден ход; зар 6 → излизане
## на spawn (path_index=0); незаконен MovePawn от база при 1–5 се reject-ва
## без мутация на state/RNG.


var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_rules = MoveRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_allows_exit_base_only_on_six() -> void:
	assert_true(_rules.allows_exit_base(DiceState.EXIT_BASE_VALUE))
	for face in range(DiceState.VALUE_MIN, DiceState.EXIT_BASE_VALUE):
		assert_false(_rules.allows_exit_base(face),
				"зар %d не позволява излизане от база" % face)
	assert_false(_rules.allows_exit_base(DiceState.VALUE_NONE))
	assert_false(_rules.allows_exit_base(7))


func test_collect_valid_excludes_base_pawns_on_one_to_five_yel_031() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	assert_true(TurnRules.new().all_pawns_in_base(player))
	for face in range(DiceState.VALUE_MIN, DiceState.EXIT_BASE_VALUE):
		var valid: Array = _rules.collect_valid_pawn_ids(state, player, face)
		assert_eq(valid.size(), 0,
				"YEL-031: при зар %d няма валидни пионки в база" % face)


func test_collect_valid_includes_all_base_pawns_on_six_yel_030() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var valid: Array = _rules.collect_valid_pawn_ids(
			state, player, DiceState.EXIT_BASE_VALUE)
	assert_eq(valid.size(), PlayerState.PAWNS_PER_PLAYER)
	for entry in player.pawns:
		var pawn := entry as PawnState
		assert_true(valid.has(pawn.pawn_id))


func test_apply_exit_base_on_six_moves_to_spawn_yel_030() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var spawn := Classic15x15Board.spawn_cell_for(player.player_id)
	assert_true(pawn.is_in_base())

	var ok := _rules.apply_exit_base(
			state, player, pawn, DiceState.EXIT_BASE_VALUE)

	assert_true(ok)
	assert_true(pawn.is_on_main_path())
	assert_eq(pawn.path_index, PawnState.PATH_INDEX_AT_SPAWN)
	assert_eq(pawn.cell_id, spawn)
	assert_eq(spawn, CellId.from_grid(8, 2),
			"green spawn за активния seat при DEFAULT_SEATS_2P")


func test_apply_exit_base_rejects_one_to_five_without_mutation() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var before_cell: StringName = pawn.cell_id
	for face in range(DiceState.VALUE_MIN, DiceState.EXIT_BASE_VALUE):
		var ok := _rules.apply_exit_base(state, player, pawn, face)
		assert_false(ok, "apply_exit_base(%d) трябва да е false" % face)
		assert_true(pawn.is_in_base())
		assert_eq(pawn.cell_id, before_cell)
		assert_eq(pawn.path_index, PawnState.PATH_INDEX_IN_BASE)


func test_mixed_board_and_base_roll_four_excludes_base_pawns() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var on_board := player.get_pawn_by_index(0)
	on_board.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	var valid: Array = _rules.collect_valid_pawn_ids(state, player, 4)
	assert_true(valid.has(on_board.pawn_id))
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		var base_pawn := player.get_pawn_by_index(i)
		assert_true(base_pawn.is_in_base())
		assert_false(valid.has(base_pawn.pawn_id),
				"YEL-031: пионка в база не е валидна при зар 4")


func test_engine_rejects_forced_base_exit_on_four_yel_031() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	# Симулираме невалиден клиентски опит: dice 4, но pawn_id е в valid list.
	state.turn.enter_awaiting_move(4, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, 4)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")
	assert_true(state.get_active_player().get_pawn(pawn.pawn_id).is_in_base())


func test_engine_exit_base_on_six_to_spawn_yel_030() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var from_cell: StringName = pawn.cell_id
	var spawn := Classic15x15Board.spawn_cell_for(player.player_id)
	state.turn.enter_awaiting_move(6, [pawn.pawn_id])
	state.turn.grant_extra_roll()
	state.dice.set_roll(player.player_id, 6)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_on_main_path())
	assert_eq(moved.path_index, PawnState.PATH_INDEX_AT_SPAWN)
	assert_eq(moved.cell_id, spawn)
	assert_eq(result.event_count(), 1)
	var exited := result.events[0] as PawnExitedBaseEvent
	assert_true(exited is PawnExitedBaseEvent)
	assert_eq(exited.from_cell_id, from_cell)
	assert_eq(exited.spawn_cell_id, spawn)


func test_yellow_exit_lands_on_yel_030_spawn_cell() -> void:
	var state := _setup_yellow_awaiting_exit()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	assert_eq(spawn, CellId.from_grid(6, 12))
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(PlayerId.YELLOW).get_pawn(pawn.pawn_id)
	assert_eq(moved.cell_id, CellId.from_grid(6, 12))
	assert_eq(moved.path_index, PawnState.PATH_INDEX_AT_SPAWN)


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


func _setup_yellow_awaiting_exit() -> GameState:
	var state := _setup_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(2, true)
	var player := state.get_active_player()
	assert_eq(player.player_id, PlayerId.YELLOW)
	var pawn := player.get_pawn_by_index(0)
	state.turn.enter_awaiting_move(6, [pawn.pawn_id])
	state.turn.grant_extra_roll()
	state.dice.set_roll(player.player_id, 6)
	return state
