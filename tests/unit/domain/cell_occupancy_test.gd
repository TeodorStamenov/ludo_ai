extends TestCase
## Business-critical тестове за CellOccupancy (#107 /
## docs/V1_GAME_DESIGN.md §3.2; docs/V1_ARCHITECTURE.md §12;
## GAP-004 / GAP-006).
##
## Derived index от GameState — не отделен source of truth.
## MoveRules прилага max-2 на MAIN_PATH / spawn (#108).


func before_each() -> void:
	MatchId._reset_counter_for_tests()


func test_cell_occupancy_extends_ref_counted() -> void:
	var occupancy := CellOccupancy.new()
	assert_not_null(occupancy)
	assert_true(occupancy is RefCounted)
	var as_object: Object = occupancy
	assert_false(as_object is Node)
	var path: String = occupancy.get_script().resource_path
	assert_true(path.contains("game/domain/model/"))


## §12 / §3.2: максимум 2 собствени пионки на обща клетка.
func test_max_own_pawns_per_cell_invariant() -> void:
	assert_eq(CellOccupancy.MAX_OWN_PAWNS_PER_CELL, 2)
	assert_eq(StackRules.MAX_OWN_PAWNS_PER_CELL, CellOccupancy.MAX_OWN_PAWNS_PER_CELL)


## Празна дъска → няма occupants; BASE пионки не влизат в board occupancy.
func test_base_pawns_are_not_board_occupants() -> void:
	var state := _two_player_in_progress()
	var occupancy := CellOccupancy.from_state(state)
	assert_eq(occupancy.occupied_cell_ids().size(), 0)
	var yellow_base: StringName = Classic15x15Board.base_cells_for(PlayerId.YELLOW)[0]
	assert_true(occupancy.is_empty(yellow_base))
	assert_eq(occupancy.count_at(yellow_base), 0)


## FINISHED пионка на CENTER не е board occupant.
func test_finished_pawns_are_not_board_occupants() -> void:
	var state := _two_player_in_progress()
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).mark_finished(52)
	var occupancy := CellOccupancy.from_state(state)
	assert_true(occupancy.is_empty(CellId.CENTER))
	assert_eq(occupancy.count_at(CellId.CENTER), 0)


## Една пионка на MAIN_PATH → count 1, не е stack.
func test_single_pawn_occupies_main_path_cell() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	state.get_player(PlayerId.YELLOW).get_pawn_by_index(0).exit_base_to_spawn(cell)

	var occupancy := CellOccupancy.from_state(state)
	assert_eq(occupancy.count_at(cell), 1)
	assert_eq(occupancy.count_of_player_at(cell, PlayerId.YELLOW), 1)
	assert_eq(occupancy.count_opponents_at(cell, PlayerId.YELLOW), 0)
	assert_false(occupancy.has_friendly_stack(cell, PlayerId.YELLOW))
	assert_true(occupancy.can_accept_own_pawn(cell, PlayerId.YELLOW))
	assert_eq(occupancy.get_pawns_at(cell)[0].pawn_id, PawnId.for_player(PlayerId.YELLOW, 0))


## Две собствени на една клетка → friendly stack; трета не може.
func test_two_own_pawns_form_friendly_stack_blocks_third() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, cell)

	var occupancy := CellOccupancy.from_state(state)
	assert_eq(occupancy.count_at(cell), 2)
	assert_true(occupancy.has_friendly_stack(cell, PlayerId.YELLOW))
	assert_false(occupancy.can_accept_own_pawn(cell, PlayerId.YELLOW))
	assert_false(occupancy.can_accept_own_pawn(
			cell, PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 2)))
	# Движеща се пионка, вече на клетката, не брои двойно за себе си.
	assert_true(occupancy.can_accept_own_pawn(
			cell, PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0)))


## Една собствена + една противникова → не е friendly/enemy stack; single opponent.
func test_mixed_occupancy_reports_single_opponent() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	state.get_player(PlayerId.YELLOW).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 4, cell)
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, cell)

	var occupancy := CellOccupancy.from_state(state)
	assert_eq(occupancy.count_at(cell), 2)
	assert_eq(occupancy.count_of_player_at(cell, PlayerId.YELLOW), 1)
	assert_eq(occupancy.count_opponents_at(cell, PlayerId.YELLOW), 1)
	assert_false(occupancy.has_friendly_stack(cell, PlayerId.YELLOW))
	assert_false(occupancy.has_enemy_stack(cell, PlayerId.YELLOW))
	assert_true(occupancy.can_accept_own_pawn(cell, PlayerId.YELLOW))
	var opponent := occupancy.get_single_opponent_at(cell, PlayerId.YELLOW)
	assert_not_null(opponent)
	assert_eq(opponent.pawn_id, PawnId.for_player(PlayerId.GREEN, 0))


## Две противникови на клетка → enemy stack; няма single opponent.
func test_two_opponent_pawns_form_enemy_stack() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, cell)

	var occupancy := CellOccupancy.from_state(state)
	assert_true(occupancy.has_enemy_stack(cell, PlayerId.YELLOW))
	assert_false(occupancy.has_friendly_stack(cell, PlayerId.YELLOW))
	assert_null(occupancy.get_single_opponent_at(cell, PlayerId.YELLOW))
	assert_eq(occupancy.count_opponents_at(cell, PlayerId.YELLOW), 2)


## exclude_pawn_id при count_own — landing check за пионка, която напуска клетката.
func test_count_own_excluding_moving_pawn() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 10)
	var yellow := state.get_player(PlayerId.YELLOW)
	var moving := yellow.get_pawn_by_index(0)
	moving.set_position(PawnZone.MAIN_PATH, 2, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 2, cell)

	var occupancy := CellOccupancy.from_state(state)
	assert_eq(occupancy.count_own_excluding(cell, PlayerId.YELLOW, moving.pawn_id), 1)
	assert_eq(occupancy.count_own_excluding(cell, PlayerId.YELLOW, &""), 2)


## Свободни BASE клетки след като някои пионки са излезли.
func test_free_base_cells_exclude_occupied_base_slots() -> void:
	var state := _two_player_in_progress()
	var yellow := state.get_player(PlayerId.YELLOW)
	var bases: Array = Classic15x15Board.base_cells_for(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	yellow.get_pawn_by_index(1).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))

	var free := CellOccupancy.free_base_cells(state, PlayerId.YELLOW, bases)
	assert_eq(free.size(), 2)
	# Пионки 0 и 1 са напуснали своите базови клетки → те са свободни.
	assert_true(free.has(bases[0]))
	assert_true(free.has(bases[1]))
	assert_false(free.has(bases[2]))
	assert_false(free.has(bases[3]))


## StackRules query wrappers ползват същия occupancy модел.
func test_stack_rules_query_wrappers_use_occupancy() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, cell)

	var rules := StackRules.new()
	assert_true(rules.is_friendly_stack(state, cell, PlayerId.YELLOW))
	assert_false(rules.can_place_own_pawn(state, cell, PlayerId.YELLOW))
	assert_true(rules.can_place_own_pawn(
			state, cell, PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0)))


## MoveRules home-stretch блок (YEL-053) минава през CellOccupancy.
func test_move_rules_home_stretch_blocks_via_occupancy() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	var first_home: StringName = route[home_entry + 1]
	player.get_pawn_by_index(1).set_position(
			PawnZone.HOME_STRETCH, home_entry + 1, first_home)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])

	var rules := MoveRules.new()
	assert_false(rules.can_advance_on_board(state, player, mover, 1))
	assert_false(rules.would_enter_home_stretch(state, player, mover, 1))


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
