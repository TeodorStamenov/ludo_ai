extends TestCase
## Business-critical тестове за движение по маршрута (Task #104 /
## docs/V1_GAME_DESIGN.md §3; CURRENT_YELLOW_BEHAVIOR YEL-040–043;
## docs/V1_ARCHITECTURE.md §4.3 / §12 / §14; GAP-008 rejected).
##
## Правилото е в MoveRules (#96). Тук: точен брой клетки по player route;
## MAIN_PATH дестинация остава MAIN_PATH; последователни ходове; без clamp
## при overshoot; MovePawnCommand ↔ PawnMoved / TurnChanged.


var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_rules = MoveRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## YEL-041: от yellow spawn (6,12) с 4 → (6,8) през (6,11)/(6,10)/(6,9).
func test_yel_041_four_from_yellow_spawn() -> void:
	var state := _setup_yellow_on_spawn_awaiting_move(4)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	assert_eq(pawn.cell_id, CellId.from_grid(6, 12))
	assert_eq(pawn.path_index, 0)

	var traversed := _rules.resolve_traversed_cell_ids(0, 4, route)
	assert_eq(traversed.size(), 4)
	assert_eq(traversed[0], CellId.from_grid(6, 11))
	assert_eq(traversed[1], CellId.from_grid(6, 10))
	assert_eq(traversed[2], CellId.from_grid(6, 9))
	assert_eq(traversed[3], CellId.from_grid(6, 8))

	assert_true(_rules.apply_board_move(state, player, pawn, 4))
	assert_true(pawn.is_on_main_path())
	assert_false(pawn.is_in_home_stretch())
	assert_eq(pawn.path_index, 4)
	assert_eq(pawn.cell_id, CellId.from_grid(6, 8))
	assert_true(Classic15x15Board.is_main_loop_cell(pawn.cell_id))


## YEL-040: пионка се мести с точно N клетки; path_index += N; zone = MAIN_PATH.
func test_exact_steps_on_main_path_yel_040() -> void:
	var state := _setup_green_on_spawn()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	for steps in [1, 2, 3, 5, 6]:
		pawn.set_position(PawnZone.MAIN_PATH, 0, route[0])
		assert_true(_rules.can_advance_on_board(state, player, pawn, steps))
		assert_true(_rules.apply_board_move(state, player, pawn, steps))
		assert_true(pawn.is_on_main_path())
		assert_eq(pawn.path_index, steps)
		assert_eq(pawn.cell_id, route[steps])


## YEL-040: resolve_traversed_cell_ids от mid-path дава точно N последователни клетки.
func test_mid_path_traversed_cells_are_sequential_yel_040() -> void:
	var state := _setup_green_on_spawn()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var from_index: int = 8
	var steps: int = 5
	assert_lt(from_index + steps, Classic15x15Board.first_home_stretch_path_index())
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])

	var traversed := _rules.resolve_traversed_cell_ids(from_index, steps, route)
	assert_eq(traversed.size(), steps)
	for i in steps:
		assert_eq(traversed[i], route[from_index + 1 + i])
	assert_eq(
			_rules.resolve_destination_index(from_index, steps, route.size()),
			from_index + steps)

	assert_true(_rules.apply_board_move(state, player, pawn, steps))
	assert_eq(pawn.path_index, from_index + steps)
	assert_eq(pawn.cell_id, route[from_index + steps])
	assert_eq(pawn.cell_id, traversed[steps - 1])


## Последователни ходове по MAIN_PATH: path_index се трупа без да влиза в home.
func test_consecutive_main_path_moves_accumulate_path_index() -> void:
	var state := _setup_green_on_spawn()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	assert_true(_rules.apply_board_move(state, player, pawn, 3))
	assert_eq(pawn.path_index, 3)
	assert_eq(pawn.cell_id, route[3])

	assert_true(_rules.apply_board_move(state, player, pawn, 5))
	assert_true(pawn.is_on_main_path())
	assert_eq(pawn.path_index, 8)
	assert_eq(pawn.cell_id, route[8])
	assert_false(Classic15x15Board.is_home_stretch_cell_of(
			player.player_id, pawn.cell_id))


## Ход по средата на общото трасе — остава MAIN_PATH, не влиза в home.
func test_mid_loop_move_stays_on_main_path() -> void:
	var state := _setup_green_on_spawn()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var from_index: int = 12
	assert_lt(from_index + 6, first_home, "ходът не трябва да достига home stretch")
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])

	assert_true(_rules.apply_board_move(state, player, pawn, 6))
	assert_true(pawn.is_on_main_path())
	assert_eq(pawn.path_index, from_index + 6)
	assert_eq(pawn.cell_id, route[from_index + 6])
	assert_false(Classic15x15Board.is_home_stretch_cell_of(
			player.player_id, pawn.cell_id))


## Всички seats: spawn + 3 остава на MAIN_PATH с коректен cell_id.
func test_all_seats_advance_three_from_spawn() -> void:
	var state := _setup_four_player_in_progress()
	for player_id in PlayerId.ALL:
		var player := state.get_player(player_id)
		var pawn := player.get_pawn_by_index(0)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player_id))
		assert_true(_rules.apply_board_move(state, player, pawn, 3))
		assert_true(pawn.is_on_main_path())
		assert_eq(pawn.path_index, 3)
		assert_eq(pawn.cell_id, route[3])


## Всички seats: mid-path ход с 4 следва собствения route cell_id.
func test_all_seats_mid_path_advance_follows_own_route() -> void:
	var state := _setup_four_player_in_progress()
	var from_index: int = 10
	var steps: int = 4
	assert_lt(from_index + steps, Classic15x15Board.first_home_stretch_path_index())
	for player_id in PlayerId.ALL:
		var player := state.get_player(player_id)
		var pawn := player.get_pawn_by_index(0)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])
		assert_true(_rules.apply_board_move(state, player, pawn, steps),
				"%s: mid-path ход с %d" % [player_id, steps])
		assert_true(pawn.is_on_main_path())
		assert_eq(pawn.path_index, from_index + steps)
		assert_eq(pawn.cell_id, route[from_index + steps])


## GAP-008 rejected: от home_entry с зар > оставащите клетки → няма clamp.
func test_overshoot_from_home_entry_rejected_without_clamp_gap_008() -> void:
	var state := _setup_green_on_spawn()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var home_entry_index: int = Classic15x15Board.home_entry_path_index()
	pawn.set_position(PawnZone.MAIN_PATH, home_entry_index, route[home_entry_index])
	assert_true(Classic15x15Board.is_main_loop_cell(pawn.cell_id))
	var before := pawn.duplicate_state()
	var overshoot: int = Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER + 1

	assert_eq(
			_rules.remaining_steps_to_route_end(home_entry_index, route.size()),
			Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
	assert_eq(
			_rules.resolve_destination_index(
					home_entry_index, overshoot, route.size()),
			MoveRules.DESTINATION_NONE)
	assert_eq(
			_rules.resolve_traversed_cell_ids(
					home_entry_index, overshoot, route).size(),
			0)
	assert_false(_rules.can_advance_on_board(state, player, pawn, overshoot))
	assert_false(_rules.apply_board_move(state, player, pawn, overshoot))
	assert_true(pawn.equals(before), "apply_board_move не мутира при reject")


## Несъгласуван cell_id / path_index → ходът е невалиден.
func test_mismatched_cell_rejects_advance() -> void:
	var state := _setup_green_on_spawn()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	pawn.set_position(PawnZone.MAIN_PATH, 2, route[5])
	assert_false(_rules.can_advance_on_board(state, player, pawn, 1))
	assert_false(_rules.apply_board_move(state, player, pawn, 1))


## Engine: MovePawnCommand с 4 от yellow spawn → PawnMoved + MAIN_PATH (YEL-041).
func test_engine_board_move_four_from_yellow_spawn_yel_041() -> void:
	var state := _setup_yellow_on_spawn_awaiting_move(4)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var from_cell: StringName = pawn.cell_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_on_main_path())
	assert_eq(moved.path_index, 4)
	assert_eq(moved.cell_id, CellId.from_grid(6, 8))
	var moved_event := result.events[0] as PawnMovedEvent
	assert_true(moved_event is PawnMovedEvent)
	assert_eq(moved_event.from_cell_id, from_cell)
	assert_eq(moved_event.to_cell_id, CellId.from_grid(6, 8))
	assert_eq(moved_event.zone, PawnZone.MAIN_PATH)
	assert_true(moved_event.is_on_main_path())


## YEL-042: ход 1–5 по MAIN_PATH → TURN_END / следващ играч.
func test_engine_normal_main_path_move_ends_turn_yel_042() -> void:
	var state := _setup_yellow_on_spawn_awaiting_move(3)
	var active_before: int = state.active_player_index
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.active_player_index, active_before)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is TurnChangedEvent)
	assert_eq(result.event_count(), 2)


## YEL-043: ход с 6 по MAIN_PATH → extra roll, същият играч.
func test_engine_six_on_main_path_grants_extra_roll_yel_043() -> void:
	var state := _setup_yellow_on_spawn_awaiting_move(6)
	state.turn.grant_extra_roll()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var active_before: int = state.active_player_index
	var turn_before: int = state.turn.turn_number
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_eq(moved.path_index, 6)
	assert_true(moved.is_on_main_path())
	assert_true(result.state.turn.is_awaiting_roll())
	assert_true(result.state.turn.allows_roll_dice())
	assert_eq(
			result.state.turn.base_attempts_remaining,
			TurnState.SINGLE_ROLL_ATTEMPTS)
	assert_eq(result.state.active_player_index, active_before)
	assert_eq(result.state.turn.turn_number, turn_before)
	assert_eq(result.event_count(), 1)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_false(_events_contain_turn_changed(result.events))


## Engine: mid-path ход с 2 → PawnMoved from/to по route, зона MAIN_PATH.
func test_engine_mid_path_move_emits_pawn_moved_on_main_path() -> void:
	var state := _setup_yellow_on_spawn_awaiting_move(2)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var from_index: int = 15
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])
	var from_cell: StringName = pawn.cell_id
	var to_cell: StringName = route[from_index + 2]
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_on_main_path())
	assert_eq(moved.path_index, from_index + 2)
	assert_eq(moved.cell_id, to_cell)
	var moved_event := result.events[0] as PawnMovedEvent
	assert_true(moved_event is PawnMovedEvent)
	assert_eq(moved_event.from_cell_id, from_cell)
	assert_eq(moved_event.to_cell_id, to_cell)
	assert_eq(moved_event.zone, PawnZone.MAIN_PATH)


## Engine: GAP-008 overshoot от home_entry → ILLEGAL_MOVE, без мутация на state/RNG.
func test_engine_overshoot_from_home_entry_rejected_gap_008() -> void:
	var overshoot: int = Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER + 1
	var state := _setup_yellow_on_home_entry_awaiting_move(overshoot)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	assert_false(_rules.can_advance_on_board(state, player, pawn, overshoot))
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
	assert_eq(
			state.get_player(player.player_id).get_pawn(pawn.pawn_id).path_index,
			Classic15x15Board.home_entry_path_index())


func _events_contain_turn_changed(events: Array) -> bool:
	for entry in events:
		if entry is TurnChangedEvent:
			return true
	return false


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


func _setup_green_on_spawn() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	var player := state.get_active_player()
	player.get_pawn_by_index(0).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(player.player_id))
	return state


func _setup_yellow_on_spawn_awaiting_move(dice_value: int) -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(PlayerId.YELLOW))
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_true(pawn.is_on_main_path())
	assert_eq(pawn.cell_id, CellId.from_grid(6, 12))
	return state


func _setup_yellow_on_home_entry_awaiting_move(dice_value: int) -> GameState:
	var state := _setup_yellow_on_spawn_awaiting_move(dice_value)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var home_entry_index: int = Classic15x15Board.home_entry_path_index()
	pawn.set_position(PawnZone.MAIN_PATH, home_entry_index, route[home_entry_index])
	return state


func _setup_four_player_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_four_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
