extends TestCase
## Business-critical тестове за точен зар при завършване (Task #106 /
## docs/V1_GAME_DESIGN.md §3.1 / §3.2; docs/V1_ARCHITECTURE.md §4.1 / §12;
## CURRENT_YELLOW_BEHAVIOR GAP-007 / GAP-008 rejected).
##
## Правилото е в FinishRules (#99) + MoveRules.can_move_pawn. Тук: от
## HOME_STRETCH само exact remaining_to_finish → FINISHED / CENTER; overshoot
## и undershoot (≠ remaining) → reject без clamp; MovePawnCommand ↔
## PawnFinished при точен зар.


var _finish: FinishRules
var _move: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_move = MoveRules.new(_finish)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## remaining_to_finish = remaining_to_last_home + 1 на всяка HOME клетка.
func test_remaining_to_finish_is_one_past_last_home() -> void:
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var route_len: int = Classic15x15Board.PLAYER_ROUTE_LENGTH
	for offset in Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER:
		var path_index: int = first_home + offset
		var to_last: int = _move.remaining_steps_to_route_end(path_index, route_len)
		var to_finish: int = _finish.remaining_steps_to_finish(path_index, route_len)
		assert_eq(to_finish, to_last + 1,
				"path_index %d: finish = last_home + 1" % path_index)
		assert_eq(to_finish, route_len - path_index)


## От всяка HOME клетка: само exact remaining_to_finish finish-ва; другите лица — не.
func test_only_exact_remaining_finishes_from_each_home_cell() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()

	for offset in Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER:
		var path_index: int = first_home + offset
		var exact: int = _finish.remaining_steps_to_finish(path_index, route.size())
		assert_true(DiceState.is_face_value(exact),
				"remaining %d трябва да е валиден зар" % exact)

		for face in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
			pawn.set_position(PawnZone.HOME_STRETCH, path_index, route[path_index])
			var before := pawn.duplicate_state()
			if face == exact:
				assert_true(_finish.can_finish_pawn(state, player, pawn, face),
						"offset %d exact %d" % [offset, face])
				assert_true(_move.can_move_pawn(state, player, pawn, face))
				assert_true(_finish.apply_finish_pawn(state, player, pawn, face))
				assert_true(pawn.is_finished())
				assert_eq(pawn.cell_id, CellId.CENTER)
			else:
				assert_false(_finish.can_finish_pawn(state, player, pawn, face),
						"offset %d face %d ≠ exact %d" % [offset, face, exact])
				assert_false(_finish.apply_finish_pawn(state, player, pawn, face))
				assert_true(pawn.equals(before),
						"non-exact не мутира при face %d" % face)


## Undershoot в home: ход по маршрута (не finish); exact finish; overshoot reject.
func test_undershoot_moves_exact_finishes_overshoot_rejects() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	assert_eq(_finish.remaining_steps_to_finish(first_home, route.size()), 4)

	assert_true(_move.can_advance_in_home_stretch(state, player, pawn, 2))
	assert_false(_finish.can_finish_pawn(state, player, pawn, 2))
	assert_true(_move.apply_board_move(state, player, pawn, 2))
	assert_true(pawn.is_in_home_stretch())
	assert_false(pawn.is_finished())
	assert_eq(pawn.path_index, first_home + 2)

	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	assert_true(_finish.can_finish_pawn(state, player, pawn, 4))
	assert_false(_move.can_advance_in_home_stretch(state, player, pawn, 4))
	assert_true(_finish.apply_finish_pawn(state, player, pawn, 4))
	assert_true(pawn.is_finished())

	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	var before := pawn.duplicate_state()
	assert_false(_finish.can_finish_pawn(state, player, pawn, 5))
	assert_false(_move.can_move_pawn(state, player, pawn, 5))
	assert_false(_finish.apply_finish_pawn(state, player, pawn, 5))
	assert_true(pawn.equals(before))


## От последна HOME: само exact finish (1) е в collect; 2–6 → празно.
func test_collect_includes_only_on_exact_finish_roll() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var last_index: int = route.size() - 1
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size())
	assert_eq(_finish.remaining_steps_to_finish(last_index, route.size()), 1)

	assert_eq(_move.collect_valid_pawn_ids(state, player, 1).size(), 1)
	assert_true(_move.collect_valid_pawn_ids(state, player, 1).has(pawn.pawn_id))
	for face in range(2, DiceState.VALUE_MAX + 1):
		assert_eq(_move.collect_valid_pawn_ids(state, player, face).size(), 0,
				"overshoot face %d от последна HOME → няма ход" % face)


## От mid HOME: undershoot advance + exact finish са валидни; overshoot — не.
func test_collect_mid_home_allows_advance_and_exact_finish_only() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index: int = Classic15x15Board.first_home_stretch_path_index() + 1
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.HOME_STRETCH, mid_index, route[mid_index])
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size())
	var exact_finish: int = _finish.remaining_steps_to_finish(mid_index, route.size())
	assert_eq(exact_finish, 3)
	assert_eq(_move.remaining_steps_to_route_end(mid_index, route.size()), 2)

	for face in [1, 2, exact_finish]:
		assert_true(_move.collect_valid_pawn_ids(state, player, face).has(pawn.pawn_id),
				"face %d: advance или exact finish" % face)
	for face in range(exact_finish + 1, DiceState.VALUE_MAX + 1):
		assert_eq(_move.collect_valid_pawn_ids(state, player, face).size(), 0,
				"overshoot face %d" % face)


## Всички seats: от всяка HOME с exact remaining → FINISHED / CENTER.
func test_all_seats_exact_finish_from_each_home_cell() -> void:
	var state := _setup_four_player_in_progress()
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	for player_id in PlayerId.ALL:
		var player := state.get_player(player_id)
		var pawn := player.get_pawn_by_index(0)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		for offset in Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER:
			var path_index: int = first_home + offset
			var exact: int = _finish.remaining_steps_to_finish(path_index, route.size())
			pawn.set_position(PawnZone.HOME_STRETCH, path_index, route[path_index])
			assert_true(_finish.apply_finish_pawn(state, player, pawn, exact),
					"%s offset %d exact %d" % [player_id, offset, exact])
			assert_true(pawn.is_finished())
			assert_eq(pawn.cell_id, CellId.CENTER)


## Engine: точен finish от първа HOME с 4 → FINISHED + PawnFinished.
func test_engine_exact_finish_from_first_home() -> void:
	var state := _setup_yellow_awaiting_finish_from_path(
			Classic15x15Board.first_home_stretch_path_index(), 4)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var from_cell: StringName = pawn.cell_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var finished := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(finished.is_finished())
	assert_eq(finished.cell_id, CellId.CENTER)
	assert_true(result.events[0] is PawnMovedEvent)
	var moved := result.events[0] as PawnMovedEvent
	assert_eq(moved.from_cell_id, from_cell)
	assert_eq(moved.to_cell_id, CellId.CENTER)
	assert_eq(moved.zone, PawnZone.FINISHED)
	assert_true(result.events[1] is PawnFinishedEvent)


## Engine: точен finish от последна HOME с 1 → FINISHED.
func test_engine_exact_finish_from_last_home() -> void:
	var last_index: int = Classic15x15Board.PLAYER_ROUTE_LENGTH - 1
	var state := _setup_yellow_awaiting_finish_from_path(last_index, 1)
	var player := state.get_active_player()
	var pawn_id: StringName = player.get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var finished := result.state.get_player(player.player_id).get_pawn(pawn_id)
	assert_true(finished.is_finished())
	assert_eq(finished.cell_id, CellId.CENTER)
	assert_true(result.events[1] is PawnFinishedEvent)


## Engine: non-exact (overshoot) → ILLEGAL_MOVE, без мутация (§12 / GAP-008).
func test_engine_non_exact_finish_rejected_without_mutation() -> void:
	var mid_index: int = Classic15x15Board.first_home_stretch_path_index() + 1
	var state := _setup_yellow_awaiting_finish_from_path(mid_index, 5)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(
			state.get_active_player_id(),
			state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


## Engine: undershoot (2 от първа HOME) мести в stretch, не finish-ва.
func test_engine_undershoot_advances_in_stretch_not_finish() -> void:
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var state := _setup_yellow_awaiting_finish_from_path(first_home, 2)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved := result.state.get_player(player.player_id).get_pawn(pawn.pawn_id)
	assert_true(moved.is_in_home_stretch())
	assert_false(moved.is_finished())
	assert_eq(moved.path_index, first_home + 2)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_false(_events_contain_pawn_finished(result.events))


func _events_contain_pawn_finished(events: Array) -> bool:
	for entry in events:
		if entry is PawnFinishedEvent:
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


func _setup_yellow_in_home_stretch() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	return state


func _setup_yellow_awaiting_finish_from_path(
		path_index: int,
		dice_value: int
) -> GameState:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	pawn.set_position(PawnZone.HOME_STRETCH, path_index, route[path_index])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_true(pawn.is_in_home_stretch())
	return state


func _setup_four_player_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_four_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
