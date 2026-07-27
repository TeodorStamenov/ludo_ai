extends TestCase
## Business-critical тестове: ход, който би сложил трета своя пионка, е невалиден
## (Task #109 / docs/V1_GAME_DESIGN.md §3.2; docs/V1_ARCHITECTURE.md §12;
## GAP-004 / GAP-006).
##
## Инварианти: would_place_third_own_pawn / collect_valid_pawn_ids изключват
## пионката; MovePawnCommand → CODE_ILLEGAL_MOVE дори при tampered valid list;
## state и RNG непроменени (§12). Капацитет max-2 → stack_rules_test (#108).


var _rules: MoveRules
var _stacks: StackRules
var _engine: GameEngine


func before_each() -> void:
	_stacks = StackRules.new()
	_rules = MoveRules.new(null, _stacks)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## Кацане върху 2 свои на MAIN_PATH → would_place_third; не е в valid list.
func test_board_landing_on_full_stack_is_illegal_and_excluded() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	var before := mover.duplicate_state()

	assert_true(_rules.would_place_third_own_pawn(state, player, mover, 3))
	assert_false(_rules.can_move_pawn(state, player, mover, 3))
	assert_false(_rules.apply_board_move(state, player, mover, 3))
	assert_true(mover.equals(before))
	assert_false(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


## Spawn с 2 свои → излизане от база е трета своя (#109 / GAP-006).
func test_exit_base_onto_full_spawn_is_illegal_and_excluded() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	player.get_pawn_by_index(0).exit_base_to_spawn(spawn)
	player.get_pawn_by_index(1).exit_base_to_spawn(spawn)
	var in_base := player.get_pawn_by_index(2)

	assert_true(_rules.would_place_third_own_pawn(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.can_move_pawn(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.apply_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_true(in_base.is_in_base())
	assert_false(_rules.collect_valid_pawn_ids(
			state, player, DiceState.EXIT_BASE_VALUE).has(in_base.pawn_id))


## Engine: MovePawn към клетка с 2 свои (tampered valid list) → ILLEGAL_MOVE.
func test_engine_rejects_board_move_onto_full_stack_without_mutation() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	# Невалиден клиент: пионката е в valid_pawn_ids въпреки пълната купчина.
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(99)
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "cannot place third own pawn on cell")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


## Engine: ExitBase към spawn с 2 свои (tampered valid list) → ILLEGAL_MOVE.
func test_engine_rejects_exit_base_onto_full_spawn_without_mutation() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	player.get_pawn_by_index(0).exit_base_to_spawn(spawn)
	player.get_pawn_by_index(1).exit_base_to_spawn(spawn)
	var in_base := player.get_pawn_by_index(2)
	state.turn.enter_awaiting_move(DiceState.EXIT_BASE_VALUE, [in_base.pawn_id])
	state.dice.set_roll(player.player_id, DiceState.EXIT_BASE_VALUE)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(77)
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, in_base.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "cannot place third own pawn on cell")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")
	assert_true(state.get_active_player().get_pawn(in_base.pawn_id).is_in_base())


## Кацане върху една своя не е „трета" — ходът е валиден (купчина от 2).
func test_landing_on_single_own_is_not_third_pawn_illegal() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_false(_rules.would_place_third_own_pawn(state, player, mover, 3))
	assert_true(_rules.can_move_pawn(state, player, mover, 3))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


func _two_player_in_progress(rng_seed: int = 42) -> GameState:
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
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
