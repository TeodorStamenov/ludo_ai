extends TestCase
## Business-critical тестове за влизане в home stretch (Task #97 /
## docs/V1_GAME_DESIGN.md §3.2; CURRENT_YELLOW_BEHAVIOR YEL-050 / YEL-053;
## docs/V1_ARCHITECTURE.md §4.1 / §12).
##
## Инварианти: MAIN_PATH → HOME_STRETCH при дестинация на собствена HOME клетка;
## маршрутът не обикаля отново общото трасе; заета крайна HOME клетка блокира.


var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_rules = MoveRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## YEL-050: жълт от home_entry (7,12) с 1 → (7,11), zone = HOME_STRETCH.
func test_yel_050_yellow_enters_from_home_entry_with_one() -> void:
	var state := _setup_yellow_at_home_entry_awaiting_move(1)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	assert_eq(pawn.cell_id, CellId.from_grid(7, 12))
	assert_true(pawn.is_on_main_path())
	assert_true(_rules.would_enter_home_stretch(state, player, pawn, 1))

	assert_true(_rules.apply_board_move(state, player, pawn, 1))
	assert_true(pawn.is_in_home_stretch())
	assert_false(pawn.is_on_main_path())
	assert_eq(pawn.path_index, Classic15x15Board.first_home_stretch_path_index())
	assert_eq(pawn.cell_id, CellId.from_grid(7, 11))
	assert_true(Classic15x15Board.is_home_stretch_cell_of(PlayerId.YELLOW, pawn.cell_id))


## YEL-050: от home_entry със 1–4 → съответната HOME клетка; без повторна обиколка.
func test_yel_050_yellow_home_entry_steps_land_on_home_cells() -> void:
	var state := _setup_yellow_on_main_path()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	var expected_homes: Array[Vector2i] = [
		Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
	]
	for steps in range(1, Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER + 1):
		pawn.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])
		assert_true(_rules.would_enter_home_stretch(state, player, pawn, steps))
		assert_true(_rules.apply_board_move(state, player, pawn, steps))
		assert_true(pawn.is_in_home_stretch())
		assert_eq(pawn.path_index, home_entry + steps)
		assert_eq(pawn.cell_id, CellId.from_grid(
				expected_homes[steps - 1].x, expected_homes[steps - 1].y))
		assert_false(Classic15x15Board.is_main_loop_cell(pawn.cell_id),
				"YEL-050: след влизане не продължава по общото трасе")


## От клетка преди home_entry с точен зар → първа HOME клетка.
func test_enter_from_two_before_home_entry() -> void:
	var state := _setup_green_on_main_path()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var from_index: int = first_home - 2
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])

	assert_true(_rules.would_enter_home_stretch(state, player, pawn, 2))
	var traversed := _rules.resolve_traversed_cell_ids(from_index, 2, route)
	assert_eq(traversed.size(), 2)
	assert_eq(traversed[0], route[from_index + 1])
	assert_eq(traversed[1], route[first_home])
	assert_true(_rules.apply_board_move(state, player, pawn, 2))
	assert_true(pawn.is_in_home_stretch())
	assert_eq(pawn.path_index, first_home)
	assert_eq(pawn.cell_id, route[first_home])


## Всички seats: от home_entry с 1 → собствена първа HOME клетка.
func test_all_seats_enter_own_home_stretch_from_home_entry() -> void:
	var state := _setup_four_player_in_progress()
	for player_id in PlayerId.ALL:
		var player := state.get_player(player_id)
		var pawn := player.get_pawn_by_index(0)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var home_entry: int = Classic15x15Board.home_entry_path_index()
		var first_home: int = Classic15x15Board.first_home_stretch_path_index()
		pawn.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])
		assert_eq(route[home_entry], Classic15x15Board.home_entry_cell_for(player_id))

		assert_true(_rules.apply_board_move(state, player, pawn, 1))
		assert_true(pawn.is_in_home_stretch(),
				"%s трябва да влезе в HOME_STRETCH" % player_id)
		assert_eq(pawn.path_index, first_home)
		assert_eq(pawn.cell_id, Classic15x15Board.home_stretch_cells_for(player_id)[0])
		assert_false(Classic15x15Board.is_home_stretch_cell_of(
				_other_seat(player_id), pawn.cell_id))


## Ход, който не достига HOME, остава MAIN_PATH (контраст към YEL-050).
func test_short_of_home_stretch_stays_on_main_path() -> void:
	var state := _setup_green_on_main_path()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	var from_index: int = home_entry - 3
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])

	assert_false(_rules.would_enter_home_stretch(state, player, pawn, 2))
	assert_true(_rules.apply_board_move(state, player, pawn, 2))
	assert_true(pawn.is_on_main_path())
	assert_eq(pawn.path_index, from_index + 2)
	assert_true(Classic15x15Board.is_main_loop_cell(pawn.cell_id))


## YEL-053 при влизане: заета първа HOME клетка → ходът е невалиден.
func test_occupied_first_home_blocks_entry_yel_053() -> void:
	var state := _setup_green_on_main_path()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var mover := player.get_pawn_by_index(0)
	var blocker := player.get_pawn_by_index(1)
	mover.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])
	blocker.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	var before := mover.duplicate_state()

	assert_false(_rules.would_enter_home_stretch(state, player, mover, 1))
	assert_false(_rules.can_advance_on_board(state, player, mover, 1))
	assert_false(_rules.apply_board_move(state, player, mover, 1))
	assert_true(mover.equals(before), "reject не мутира пионката")


## Overshoot от home_entry с 5 (> 4 HOME клетки) → reject без clamp.
func test_overshoot_past_home_stretch_from_entry_rejected() -> void:
	var state := _setup_green_on_main_path()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	pawn.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])
	var before := pawn.duplicate_state()
	var overshoot: int = Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER + 1

	assert_false(_rules.would_enter_home_stretch(state, player, pawn, overshoot))
	assert_false(_rules.can_advance_on_board(state, player, pawn, overshoot))
	assert_false(_rules.apply_board_move(state, player, pawn, overshoot))
	assert_true(pawn.equals(before))


## Engine: MovePawnCommand от yellow home_entry с 1 → PawnMoved + HOME_STRETCH.
func test_engine_enter_home_stretch_emits_pawn_moved_yel_050() -> void:
	var state := _setup_yellow_at_home_entry_awaiting_move(1)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var from_cell: StringName = pawn.cell_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_in_home_stretch())
	assert_eq(moved.cell_id, CellId.from_grid(7, 11))
	var moved_event := result.events[0] as PawnMovedEvent
	assert_true(moved_event is PawnMovedEvent)
	assert_eq(moved_event.from_cell_id, from_cell)
	assert_eq(moved_event.to_cell_id, CellId.from_grid(7, 11))
	assert_eq(moved_event.zone, PawnZone.HOME_STRETCH)


## Engine: влизане с 3 (не 6) → TURN_END / следващ играч.
func test_engine_enter_home_stretch_ends_turn_when_not_six() -> void:
	var state := _setup_yellow_at_home_entry_awaiting_move(3)
	var active_before: int = state.active_player_index
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(PlayerId.YELLOW).get_pawn(pawn_id)
	assert_true(moved.is_in_home_stretch())
	assert_eq(moved.cell_id, CellId.from_grid(7, 9))
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.active_player_index, active_before)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is TurnChangedEvent)


func _other_seat(player_id: StringName) -> StringName:
	for other in PlayerId.ALL:
		if other != player_id:
			return other
	return &""


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


func _four_player_config(rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_4P)
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		if i == 0:
			seat.configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		else:
			seat.configure(
					MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	return cfg


func _setup_green_on_main_path() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state


func _setup_yellow_on_main_path() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	return state


func _setup_yellow_at_home_entry_awaiting_move(dice_value: int) -> GameState:
	var state := _setup_yellow_on_main_path()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	pawn.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_eq(pawn.cell_id, CellId.from_grid(7, 12))
	return state


func _setup_four_player_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_four_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
