extends TestCase
## Business-critical тестове за точен зар в home stretch (Task #98 /
## docs/V1_GAME_DESIGN.md §3.2; CURRENT_YELLOW_BEHAVIOR YEL-051–055;
## docs/V1_ARCHITECTURE.md §4.1 / §12; GAP-008 rejected).
##
## Инварианти: от HOME_STRETCH ходът е валиден само при steps ≤ remaining;
## overshoot → reject без clamp; заета крайна клетка блокира; междинните не;
## пионка на последната HOME: can_advance = false; finish с 1 → FinishRules (#99).


var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_rules = MoveRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## YEL-051: жълт на (7,11) с 1/2/3 → (7,10)/(7,9)/(7,8).
func test_yel_051_exact_steps_from_first_home_cell() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var expected: Array[Vector2i] = [
		Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
	]
	assert_eq(_rules.remaining_steps_to_route_end(first_home, route.size()), 3)

	for steps in range(1, 4):
		pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
		assert_eq(pawn.cell_id, CellId.from_grid(7, 11))
		assert_true(_rules.can_advance_in_home_stretch(state, player, pawn, steps))
		assert_false(_rules.would_overshoot_in_home_stretch(state, player, pawn, steps))
		assert_true(_rules.apply_board_move(state, player, pawn, steps))
		assert_true(pawn.is_in_home_stretch())
		assert_eq(pawn.path_index, first_home + steps)
		assert_eq(pawn.cell_id, CellId.from_grid(expected[steps - 1].x, expected[steps - 1].y))


## YEL-051 / YEL-052: от (7,11) зар 4–6 > remaining(3) → невалиден.
func test_yel_051_overshoot_from_first_home_rejected() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	var before := pawn.duplicate_state()

	for face in [4, 5, 6]:
		assert_true(_rules.would_overshoot_in_home_stretch(state, player, pawn, face))
		assert_false(_rules.can_advance_in_home_stretch(state, player, pawn, face))
		assert_false(_rules.apply_board_move(state, player, pawn, face))
		assert_true(pawn.equals(before), "overshoot не мутира при зар %d" % face)


## YEL-052: пионка вече в home stretch с зар > remaining → reject.
func test_yel_052_overshoot_from_mid_home_stretch() -> void:
	var state := _setup_green_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var from_index: int = route.size() - 2
	pawn.set_position(PawnZone.HOME_STRETCH, from_index, route[from_index])
	assert_eq(_rules.remaining_steps_to_route_end(from_index, route.size()), 1)
	var before := pawn.duplicate_state()

	assert_true(_rules.can_advance_in_home_stretch(state, player, pawn, 1))
	assert_true(_rules.would_overshoot_in_home_stretch(state, player, pawn, 2))
	assert_false(_rules.can_advance_in_home_stretch(state, player, pawn, 2))
	assert_false(_rules.apply_board_move(state, player, pawn, 6))
	assert_true(pawn.equals(before))


## YEL-053: заета крайна home клетка → ходът е невалиден.
func test_yel_053_occupied_destination_blocks_move() -> void:
	var state := _setup_green_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var mover := player.get_pawn_by_index(0)
	var blocker := player.get_pawn_by_index(1)
	mover.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	blocker.set_position(
			PawnZone.HOME_STRETCH, first_home + 2, route[first_home + 2])
	var before := mover.duplicate_state()

	assert_false(_rules.can_advance_in_home_stretch(state, player, mover, 2))
	assert_false(_rules.apply_board_move(state, player, mover, 2))
	assert_true(mover.equals(before))


## YEL-054: заета междинна клетка, свободна крайна → ходът е валиден.
func test_yel_054_intermediate_occupied_destination_free_allowed() -> void:
	var state := _setup_green_in_progress()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var mover := player.get_pawn_by_index(0)
	var mid := player.get_pawn_by_index(1)
	mover.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	mid.set_position(
			PawnZone.HOME_STRETCH, first_home + 1, route[first_home + 1])

	assert_true(_rules.can_advance_in_home_stretch(state, player, mover, 2))
	assert_true(_rules.apply_board_move(state, player, mover, 2))
	assert_eq(mover.path_index, first_home + 2)
	assert_eq(mover.cell_id, route[first_home + 2])
	assert_true(mover.is_in_home_stretch())


## YEL-055: пионка на последната HOME клетка — няма advance по маршрута.
## Finish с точен зар 1 е FinishRules (#99), не MoveRules.can_advance.
func test_yel_055_pawn_on_last_home_cell_never_movable() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	assert_eq(pawn.cell_id, CellId.from_grid(7, 8))
	assert_eq(_rules.remaining_steps_to_route_end(last_index, route.size()), 0)

	for face in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
		assert_false(_rules.can_advance_in_home_stretch(state, player, pawn, face),
				"YEL-055: зар %d не мести пионка по маршрута от последната клетка" % face)
		assert_eq(
				_rules.resolve_destination_index(last_index, face, route.size()),
				MoveRules.DESTINATION_NONE)


## Всички seats: от първа HOME с exact remaining → последна HOME клетка.
func test_all_seats_exact_roll_to_last_home_cell() -> void:
	var state := _setup_four_player_in_progress()
	var remaining: int = Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER - 1
	for player_id in PlayerId.ALL:
		var player := state.get_player(player_id)
		var pawn := player.get_pawn_by_index(0)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var first_home: int = Classic15x15Board.first_home_stretch_path_index()
		var homes := Classic15x15Board.home_stretch_cells_for(player_id)
		pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])

		assert_true(_rules.can_advance_in_home_stretch(
				state, player, pawn, remaining),
				"%s exact remaining трябва да е валиден" % player_id)
		assert_true(_rules.apply_board_move(state, player, pawn, remaining))
		assert_eq(pawn.cell_id, homes[homes.size() - 1])
		assert_true(pawn.is_in_home_stretch())
		assert_false(pawn.is_finished(), "FINISHED е #99 — още HOME_STRETCH")


## Engine: точен ход в home stretch → PawnMoved, остава HOME_STRETCH.
func test_engine_exact_home_stretch_move_yel_051() -> void:
	var state := _setup_yellow_awaiting_home_move(2)
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
	assert_eq(moved.cell_id, CellId.from_grid(7, 9))
	var moved_event := result.events[0] as PawnMovedEvent
	assert_true(moved_event is PawnMovedEvent)
	assert_eq(moved_event.from_cell_id, from_cell)
	assert_eq(moved_event.to_cell_id, CellId.from_grid(7, 9))
	assert_eq(moved_event.zone, PawnZone.HOME_STRETCH)


## Engine: overshoot в home stretch → ILLEGAL_MOVE, без мутация (YEL-052).
func test_engine_home_stretch_overshoot_rejected_yel_052() -> void:
	var state := _setup_yellow_awaiting_home_move(6)
	# valid_pawn_ids умишлено съдържа пионката — engine трябва да reject-не по правила.
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	assert_false(_rules.can_advance_in_home_stretch(state, player, pawn, 6))
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)


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


func _setup_green_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state


func _setup_yellow_in_home_stretch() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	return state


func _setup_yellow_awaiting_home_move(dice_value: int) -> GameState:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_eq(pawn.cell_id, CellId.from_grid(7, 11))
	return state


func _setup_four_player_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_four_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
