extends TestCase
## Business-critical тестове за GiftRules.free_spawn_cells — подарък не трябва
## да се появи на клетка, вече заета от пионка (bug report: "появи се подарък
## на квадратче къде имаше вече пионка").


var _rules: GiftRules


func before_each() -> void:
	_rules = GiftRules.new()
	MatchId._reset_counter_for_tests()


func test_free_spawn_cells_excludes_cell_with_pawn() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	assert_true(Classic15x15Board.is_main_loop_cell(cell))
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)

	var free := _rules.free_spawn_cells(state)
	assert_false(free.has(cell),
			"клетка със стояща пионка не трябва да е свободна за появяване на подарък")


func test_free_spawn_cells_excludes_cell_with_gift() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	state.add_gift(GiftState.create_on_cell(cell, 1))

	var free := _rules.free_spawn_cells(state)
	assert_false(free.has(cell),
			"клетка с вече стоящ подарък не трябва да е свободна отново")


func test_free_spawn_cells_includes_unoccupied_cell() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)

	var free := _rules.free_spawn_cells(state)
	assert_true(free.has(cell),
			"празна main_loop клетка трябва да е сред свободните")


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
