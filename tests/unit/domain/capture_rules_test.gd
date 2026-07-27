extends TestCase
## Business-critical тестове за CaptureRules — имунитет на купчина (#111) и
## инварианти за взимане (docs/V1_ARCHITECTURE.md §12; V1_GAME_DESIGN.md §3.2).
##
## Пълно взимане на единична пионка → #113–#115.


var _capture: CaptureRules
var _stacks: StackRules
var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_stacks = StackRules.new()
	_capture = CaptureRules.new(_stacks)
	_rules = MoveRules.new(null, _stacks, _capture)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_capture_rules_extends_ref_counted() -> void:
	assert_not_null(_capture)
	assert_true(_capture is RefCounted)
	var as_object: Object = _capture
	assert_false(as_object is Node)
	var path: String = _capture.get_script().resource_path
	assert_true(path.contains("game/domain/"))


## #111: две противникови на клетка → имунна купчина; blocks_landing.
func test_enemy_stack_of_two_is_immune_and_blocks_landing() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, cell)

	assert_true(_stacks.is_enemy_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, cell, PlayerId.YELLOW))


## Една противникова → не е имунна (кацането за взимане е #113).
func test_single_enemy_pawn_is_not_immune_stack() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, cell)

	assert_false(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_false(_capture.blocks_landing(state, cell, PlayerId.YELLOW))


## #111: кацане върху enemy stack → невалиден ход; изключен от valid list.
func test_landing_on_enemy_stack_is_illegal_and_excluded() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	var before := mover.duplicate_state()

	assert_true(_rules.would_land_on_enemy_stack(state, player, mover, 3))
	assert_false(_rules.can_advance_on_board(state, player, mover, 3))
	assert_false(_rules.can_move_pawn(state, player, mover, 3))
	assert_false(_rules.apply_board_move(state, player, mover, 3))
	assert_true(mover.equals(before))
	assert_false(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


## #111: единична противникова на дестинацията не блокира (взимане → #113).
func test_landing_on_single_enemy_is_not_blocked_by_stack_immunity() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_false(_rules.would_land_on_enemy_stack(state, player, mover, 3))
	assert_true(_rules.can_advance_on_board(state, player, mover, 3))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


## #111: exit-base върху spawn с противникова купчина → блокиран.
func test_exit_base_blocked_when_spawn_has_enemy_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 0, spawn)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 0, spawn)
	var in_base := player.get_pawn_by_index(0)

	assert_true(_capture.blocks_landing(state, spawn, PlayerId.YELLOW))
	assert_true(_rules.would_land_on_enemy_stack(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.can_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.can_move_pawn(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.apply_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_true(in_base.is_in_base())


## Engine #111: MovePawn към immune stack (tampered valid list) → ILLEGAL_MOVE.
func test_engine_rejects_landing_on_enemy_stack_without_mutation() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
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
	assert_eq(result.error.message, "cannot land on immune enemy stack")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


## Engine #111: exit-base върху spawn с enemy stack → ILLEGAL_MOVE.
func test_engine_rejects_exit_base_onto_enemy_stack_without_mutation() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 0, spawn)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 0, spawn)
	var in_base := player.get_pawn_by_index(0)
	state.turn.enter_awaiting_move(DiceState.EXIT_BASE_VALUE, [in_base.pawn_id])
	state.dice.set_roll(player.player_id, DiceState.EXIT_BASE_VALUE)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(55)
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, in_base.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "cannot land on immune enemy stack")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)
	assert_true(state.get_active_player().get_pawn(in_base.pawn_id).is_in_base())


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
