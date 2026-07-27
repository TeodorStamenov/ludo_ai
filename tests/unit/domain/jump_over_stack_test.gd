extends TestCase
## Business-critical тестове за прескачане на купчини (Task #117 /
## docs/V1_GAME_DESIGN.md §3.2; docs/V1_ARCHITECTURE.md §4.4 / §12;
## #112 имплементация).
##
## Купчина от 2 не е стена — междинните клетки не блокират преминаване.
## Кацане върху имунна купчина остава забранено (#111). Прескачането не взима
## купчината; кацане върху единична противникова след прескачане → capture (#113).


var _rules: MoveRules
var _stacks: StackRules
var _capture: CaptureRules
var _engine: GameEngine


func before_each() -> void:
	_stacks = StackRules.new()
	_capture = CaptureRules.new(_stacks)
	_rules = MoveRules.new(null, _stacks, _capture)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## §3.2 / #112: blocks_passage винаги false — купчините не са стена.
func test_blocks_passage_never_blocks_stacks() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, cell)
	assert_true(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, cell, PlayerId.YELLOW))
	assert_false(_capture.blocks_passage(state, cell, PlayerId.YELLOW))
	assert_false(_capture.blocks_passage(state, cell, PlayerId.GREEN))
	assert_false(_capture.blocks_passage(null, &"", &""))


## Междинна противникова купчина: ходът е валиден; купчината остава; без capture.
func test_intermediate_enemy_stack_allows_passage_without_capture() -> void:
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
	assert_true(_rules.can_move_pawn(state, player, mover, 4))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 4).has(mover.pawn_id))
	assert_true(_rules.apply_board_move(state, player, mover, 4))
	assert_eq(mover.cell_id, route[4])
	assert_true(_stacks.is_enemy_stack(state, mid_cell, PlayerId.YELLOW))
	assert_eq(
			_stacks.occupancy_of(state).count_of_player_at(mid_cell, PlayerId.GREEN),
			2)


## Междинна своя купчина също не блокира — само крайната клетка брои (#108).
func test_intermediate_friendly_stack_allows_passage() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, mid_index, route[mid_index])
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, mid_index, route[mid_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])

	assert_true(_stacks.is_friendly_stack(state, route[mid_index], PlayerId.YELLOW))
	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 4))
	assert_true(_rules.can_advance_on_board(state, player, mover, 4))
	assert_true(_rules.apply_board_move(state, player, mover, 4))
	assert_eq(mover.cell_id, route[4])
	assert_true(_stacks.is_friendly_stack(state, route[mid_index], PlayerId.YELLOW))


## Контраст #111/#112: кацане върху купчината е невалидно; прескачането — валидно.
func test_landing_on_stack_illegal_but_jumping_past_is_legal() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var stack_index := 3
	var stack_cell: StringName = route[stack_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, stack_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, stack_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.would_land_on_enemy_stack(state, player, mover, 2))
	assert_false(_rules.can_move_pawn(state, player, mover, 2))
	assert_false(_rules.collect_valid_pawn_ids(state, player, 2).has(mover.pawn_id))

	assert_false(_rules.would_land_on_enemy_stack(state, player, mover, 4))
	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 4))
	assert_true(_rules.can_move_pawn(state, player, mover, 4))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 4).has(mover.pawn_id))


## Две междинни купчини по пътя — нито една не блокира преминаване.
func test_two_intermediate_enemy_stacks_do_not_block() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, route[2])
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, route[2])
	green.get_pawn_by_index(2).set_position(PawnZone.MAIN_PATH, 21, route[3])
	green.get_pawn_by_index(3).set_position(PawnZone.MAIN_PATH, 21, route[3])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])

	assert_true(_stacks.is_enemy_stack(state, route[2], PlayerId.YELLOW))
	assert_true(_stacks.is_enemy_stack(state, route[3], PlayerId.YELLOW))
	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 5))
	assert_true(_rules.can_move_pawn(state, player, mover, 5))
	assert_true(_rules.apply_board_move(state, player, mover, 5))
	assert_eq(mover.cell_id, route[5])
	assert_true(_stacks.is_enemy_stack(state, route[2], PlayerId.YELLOW))
	assert_true(_stacks.is_enemy_stack(state, route[3], PlayerId.YELLOW))


## Engine: MovePawn прескача противникова купчина; без PawnCaptured; купчината стои.
func test_engine_jump_over_enemy_stack_without_capture() -> void:
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
	var g0 := green.get_pawn_by_index(0)
	var g1 := green.get_pawn_by_index(1)
	g0.set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	g1.set_position(PawnZone.MAIN_PATH, 20, mid_cell)
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
	assert_eq(
			result.state.get_player(PlayerId.GREEN).get_pawn(g0.pawn_id).cell_id,
			mid_cell)
	assert_eq(
			result.state.get_player(PlayerId.GREEN).get_pawn(g1.pawn_id).cell_id,
			mid_cell)
	for entry in result.events:
		assert_false(entry is PawnCapturedEvent,
				"прескачането не взима купчината")
		assert_false(entry is PawnSentHomeEvent,
				"прескачането не връща никого в база")


## Engine: прескачане на своя купчина е валидно; купчината остава.
func test_engine_jump_over_friendly_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	var mid_cell: StringName = route[mid_index]
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, mid_index, mid_cell)
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, mid_index, mid_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])
	state.turn.enter_awaiting_move(4, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 4)
	var rng := SeededRandomSource.new(7)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(
			result.state.get_player(PlayerId.YELLOW).get_pawn(mover.pawn_id).cell_id,
			route[4])
	assert_true(_stacks.is_friendly_stack(result.state, mid_cell, PlayerId.YELLOW))


## Прескачане на купчина + кацане върху единична противникова → capture на дестинацията.
func test_engine_jump_over_stack_then_capture_single_enemy() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_cell: StringName = route[2]
	var dest_cell: StringName = route[4]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	var victim := green.get_pawn_by_index(2)
	victim.set_position(PawnZone.MAIN_PATH, 22, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])
	state.turn.enter_awaiting_move(4, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 4)
	var rng := SeededRandomSource.new(11)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is PawnCapturedEvent)
	assert_true(result.events[2] is PawnSentHomeEvent)
	var after_mover := result.state.get_player(PlayerId.YELLOW).get_pawn(mover.pawn_id)
	assert_eq(after_mover.cell_id, dest_cell)
	assert_true(_stacks.is_enemy_stack(result.state, mid_cell, PlayerId.YELLOW),
			"междинната купчина не е взета")
	var after_victim := result.state.get_player(PlayerId.GREEN).get_pawn(victim.pawn_id)
	assert_true(after_victim.is_in_base())
	assert_true(Classic15x15Board.is_base_cell_of(PlayerId.GREEN, after_victim.cell_id))
	var sent := result.events[2] as PawnSentHomeEvent
	assert_eq(sent.base_cell_id, after_victim.cell_id)


## Всички seats могат да прескачат противникова купчина по собствения route (§12).
func test_all_seats_can_jump_over_enemy_stack() -> void:
	for player_id in PlayerId.ALL:
		var state := _four_player_in_progress()
		var player := state.get_player(player_id)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var mid_cell: StringName = route[2]
		var blocker_id: StringName = _first_other_seat(player_id)
		var blocker := state.get_player(blocker_id)
		blocker.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 10, mid_cell)
		blocker.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 10, mid_cell)
		var mover := player.get_pawn_by_index(0)
		mover.set_position(PawnZone.MAIN_PATH, 0, route[0])

		assert_true(_stacks.is_enemy_stack(state, mid_cell, player_id),
				"%s: mid е enemy stack" % player_id)
		assert_false(_rules.would_be_blocked_en_route(state, player, mover, 4),
				"%s: купчината не блокира" % player_id)
		assert_true(_rules.can_move_pawn(state, player, mover, 4),
				"%s: прескачането е валидно" % player_id)
		assert_true(_rules.apply_board_move(state, player, mover, 4),
				"%s: apply прескача" % player_id)
		assert_eq(mover.cell_id, route[4], "%s дестинация" % player_id)
		assert_true(_stacks.is_enemy_stack(state, mid_cell, player_id),
				"%s: купчината остава" % player_id)


func _first_other_seat(player_id: StringName) -> StringName:
	for other in PlayerId.ALL:
		if other != player_id:
			return other
	return &""


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


func _four_player_in_progress(rng_seed: int = 42) -> GameState:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_4P)
	var animals: Array[StringName] = [
		AnimalId.PIG, AnimalId.RABBIT, AnimalId.DOG, AnimalId.COW,
	]
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		var ctrl: int = (
				MatchConfig.ControllerType.HUMAN if i == 0
				else MatchConfig.ControllerType.AI)
		seat.configure(ctrl, animals[i], AIDifficulty.EASY)
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(0, true)
	return state
