extends TestCase
## Business-critical тестове за завършване на пионка (Task #99 /
## docs/V1_GAME_DESIGN.md §3.1 / §3.2; docs/V1_ARCHITECTURE.md §4.1 / §12;
## CURRENT_YELLOW_BEHAVIOR GAP-007).
##
## Инварианти: от HOME_STRETCH точен зар (remaining_to_last_home + 1) → FINISHED
## на CellId.CENTER; overshoot reject; PawnMoved → PawnFinished; 4-та пионка →
## PlayerRanked.


var _finish: FinishRules
var _move: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_move = MoveRules.new(_finish)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## От последна HOME с 1 → FINISHED / CENTER (GAP-007).
func test_finish_from_last_home_with_one() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	assert_eq(_finish.remaining_steps_to_finish(last_index, route.size()), 1)

	assert_true(_finish.can_finish_pawn(state, player, pawn, 1))
	assert_true(_move.can_move_pawn(state, player, pawn, 1))
	assert_true(_finish.apply_finish_pawn(state, player, pawn, 1))
	assert_true(pawn.is_finished())
	assert_eq(pawn.cell_id, CellId.CENTER)
	assert_eq(pawn.path_index, route.size())
	assert_eq(pawn.shield_turns_remaining, 0)


## От последна HOME с 2–6 → reject без мутация.
func test_finish_from_last_home_overshoot_rejected() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	var before := pawn.duplicate_state()

	for face in range(2, DiceState.VALUE_MAX + 1):
		assert_false(_finish.can_finish_pawn(state, player, pawn, face))
		assert_false(_move.can_move_pawn(state, player, pawn, face))
		assert_false(_finish.apply_finish_pawn(state, player, pawn, face))
		assert_true(pawn.equals(before), "overshoot не мутира при зар %d" % face)


## От първа HOME: 3 → последна HOME; 4 → finish; 5 → reject.
func test_finish_exact_from_first_home_cell() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	assert_eq(_finish.remaining_steps_to_finish(first_home, route.size()), 4)

	assert_true(_move.can_advance_in_home_stretch(state, player, pawn, 3))
	assert_false(_finish.can_finish_pawn(state, player, pawn, 3))
	assert_true(_move.apply_board_move(state, player, pawn, 3))
	assert_true(pawn.is_in_home_stretch())
	assert_false(pawn.is_finished())

	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	assert_true(_finish.can_finish_pawn(state, player, pawn, 4))
	assert_false(_move.can_advance_in_home_stretch(state, player, pawn, 4))
	assert_true(_finish.apply_finish_pawn(state, player, pawn, 4))
	assert_true(pawn.is_finished())
	assert_eq(pawn.cell_id, CellId.CENTER)

	pawn.set_position(PawnZone.HOME_STRETCH, first_home, route[first_home])
	assert_false(_finish.can_finish_pawn(state, player, pawn, 5))
	assert_false(_move.can_move_pawn(state, player, pawn, 5))


## MAIN_PATH не може да finish — PawnFinished изисква before в HOME_STRETCH.
func test_finish_rejected_from_main_path() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var home_entry: int = Classic15x15Board.home_entry_path_index()
	pawn.set_position(PawnZone.MAIN_PATH, home_entry, route[home_entry])
	assert_eq(_finish.remaining_steps_to_finish(home_entry, route.size()), 5)
	assert_false(_finish.can_finish_pawn(state, player, pawn, 5))
	assert_true(_move.can_advance_on_board(state, player, pawn, 4),
			"до последна HOME още е валиден ход")


## Всички seats: от последна HOME с 1 → FINISHED.
func test_all_seats_finish_from_last_home() -> void:
	var state := _setup_four_player_in_progress()
	for player_id in PlayerId.ALL:
		var player := state.get_player(player_id)
		var pawn := player.get_pawn_by_index(0)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var last_index: int = route.size() - 1
		pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
		assert_true(_finish.apply_finish_pawn(state, player, pawn, 1),
				"%s трябва да finish с 1" % player_id)
		assert_true(pawn.is_finished())
		assert_eq(pawn.cell_id, CellId.CENTER)


## Engine: finish → PawnMoved + PawnFinished, zone FINISHED.
func test_engine_finish_emits_moved_and_finished() -> void:
	var state := _setup_yellow_awaiting_finish_move(1)
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
	assert_true(moved.is_finished())
	assert_true(result.events[1] is PawnFinishedEvent)
	var finished_event := result.events[1] as PawnFinishedEvent
	assert_true(finished_event.is_valid())
	assert_eq(finished_event.pawn_id, pawn.pawn_id)
	assert_eq(finished_event.from_cell_id, from_cell)
	assert_eq(finished_event.center_cell_id, CellId.CENTER)


## Engine: overshoot finish → ILLEGAL_MOVE, без мутация.
func test_engine_finish_overshoot_rejected() -> void:
	var state := _setup_yellow_awaiting_finish_move(3)
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
	assert_eq(rng.get_state(), rng_before)


## 4-та прибрана пионка → PlayerRanked (+ auto-rank последен при 2p).
func test_engine_fourth_finish_ranks_player() -> void:
	var state := _setup_yellow_awaiting_finish_move(1)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size())
	assert_eq(player.count_finished_pawns(), 3)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			player.player_id, player.get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var after_player := result.state.get_player(player.player_id)
	assert_true(after_player.has_finished_all_pawns())
	assert_true(after_player.is_ranked())
	assert_eq(after_player.rank, PlayerState.RANK_FIRST)
	var ranked := false
	var match_finished := false
	for entry in result.events:
		if entry is PlayerRankedEvent:
			var ev := entry as PlayerRankedEvent
			if ev.player_id == player.player_id:
				assert_eq(ev.rank, 1)
				ranked = true
		elif entry is MatchFinishedEvent:
			match_finished = true
	assert_true(ranked, "4 прибрани → PlayerRanked")
	assert_true(match_finished, "2p: auto-rank последен → MatchFinished")
	assert_true(result.state.is_finished())


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


func _setup_yellow_awaiting_finish_move(dice_value: int) -> GameState:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_eq(pawn.cell_id, CellId.from_grid(7, 8))
	return state


func _setup_four_player_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_four_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
