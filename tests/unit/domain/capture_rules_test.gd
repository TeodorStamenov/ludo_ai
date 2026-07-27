extends TestCase
## Business-critical тестове за CaptureRules — имунитет на купчина (#111),
## прескачане на противникови купчини (#112) и инварианти за взимане
## (docs/V1_ARCHITECTURE.md §12; V1_GAME_DESIGN.md §3.2).
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


## #112: имунна купчина не блокира преминаване — само кацане (#111).
func test_enemy_stack_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, cell)

	assert_true(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, cell, PlayerId.YELLOW))
	assert_false(_capture.blocks_passage(state, cell, PlayerId.YELLOW))


## #112: междинна противникова купчина не блокира ход; дестинацията се достига.
func test_intermediate_enemy_stack_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	var mid_cell: StringName = route[mid_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])

	assert_true(_stacks.is_enemy_stack(state, mid_cell, PlayerId.YELLOW))
	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 4))
	assert_false(_rules.would_land_on_enemy_stack(state, player, mover, 4))
	assert_true(_rules.can_advance_on_board(state, player, mover, 4))
	assert_true(_rules.can_move_pawn(state, player, mover, 4))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 4).has(mover.pawn_id))
	assert_true(_rules.apply_board_move(state, player, mover, 4))
	assert_eq(mover.cell_id, route[4])
	assert_true(_stacks.is_enemy_stack(state, mid_cell, PlayerId.YELLOW))


## #112: единична противникова на междинна клетка също не блокира преминаване.
func test_intermediate_single_enemy_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 3
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, route[mid_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 3))
	assert_true(_rules.can_advance_on_board(state, player, mover, 3))
	assert_true(_rules.apply_board_move(state, player, mover, 3))
	assert_eq(mover.cell_id, route[4])


## Engine #112: MovePawn прескача противникова купчина и каца след нея.
func test_engine_accepts_jump_over_enemy_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	var mid_cell: StringName = route[mid_index]
	var dest_index := 4
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])
	state.turn.enter_awaiting_move(4, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 4)
	var rng := SeededRandomSource.new(99)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	var after := result.state.get_player(PlayerId.YELLOW).get_pawn(mover.pawn_id)
	assert_eq(after.cell_id, route[dest_index])
	assert_eq(after.path_index, dest_index)
	assert_true(_stacks.is_enemy_stack(result.state, mid_cell, PlayerId.YELLOW))
	for entry in result.events:
		assert_false(entry is PawnCapturedEvent,
				"прескачането не взима купчината")


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
