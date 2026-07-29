extends TestCase
## Business-critical тестове за прибиране на пионка (V1.1 — вижте FinishRules /
## docs/V1_ARCHITECTURE.md §4.1 / §12; docs/V1_GAME_DESIGN.md §3.1 / §3.2).
##
## Правилото е в FinishRules.resolve_home_stretch_completion (#99 redefined):
## играчът прибира ВСИЧКИТЕ си 4 пионки едновременно, веднага щом и четирите
## са влезли в home stretch — флаг-превключване на място, БЕЗ движение до
## централна клетка (safe/exit/finish zone — 4-те собствени цветни клетки).
## Движението вътре в home stretch (exact roll, без overshoot) остава
## непроменено — вижте exact_home_stretch_dice_test.gd.


var _finish: FinishRules
var _move: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_move = MoveRules.new(_finish)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## No-op докато не всичките 4 пионки са в home stretch.
func test_resolve_home_stretch_completion_noop_until_all_four_present() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	player.get_pawn_by_index(0).set_position(
			PawnZone.HOME_STRETCH, first_home, route[first_home])
	# pawns 1-3 остават в BASE.

	var events := _finish.resolve_home_stretch_completion(player, 5)

	assert_true(events.is_empty())
	assert_false(player.get_pawn_by_index(0).is_finished())
	assert_false(player.has_finished_all_pawns())


## Всичките 4 в home stretch (на различни клетки) → всяка става FINISHED на място.
func test_resolve_home_stretch_completion_marks_all_four_in_place() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var expected_cells: Array[StringName] = []
	for i in PlayerState.PAWNS_PER_PLAYER:
		var idx: int = first_home + i
		player.get_pawn_by_index(i).set_position(PawnZone.HOME_STRETCH, idx, route[idx])
		expected_cells.append(route[idx])

	var events := _finish.resolve_home_stretch_completion(player, 7)

	assert_eq(events.size(), PlayerState.PAWNS_PER_PLAYER)
	for i in PlayerState.PAWNS_PER_PLAYER:
		var pawn := player.get_pawn_by_index(i)
		assert_true(pawn.is_finished())
		assert_eq(pawn.cell_id, expected_cells[i],
				"V1.1: FINISHED остава на собствената home stretch клетка")
	for event in events:
		assert_true(event is PawnFinishedEvent)
		var finished := event as PawnFinishedEvent
		assert_eq(finished.from_cell_id, finished.final_cell_id)
	assert_true(player.has_finished_all_pawns())


## Вече класиран играч → no-op (без повторно маркиране / събития).
func test_resolve_home_stretch_completion_noop_when_already_ranked() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	for i in PlayerState.PAWNS_PER_PLAYER:
		var idx: int = first_home + i
		player.get_pawn_by_index(i).mark_finished(idx, route[idx])
	state.rank_player(player.player_id)

	var events := _finish.resolve_home_stretch_completion(player, 9)

	assert_true(events.is_empty())


## Engine: последната пионка влиза в home stretch → PawnMoved + 4×PawnFinished + PlayerRanked.
func test_engine_last_pawn_entering_home_stretch_finishes_whole_player() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		var idx: int = first_home + i
		player.get_pawn_by_index(i).set_position(PawnZone.HOME_STRETCH, idx, route[idx])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, first_home - 1, route[first_home - 1])
	state.turn.enter_awaiting_move(1, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 1)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var moved_pawn := result.state.get_player(player.player_id).get_pawn(mover.pawn_id)
	assert_true(moved_pawn.is_finished())
	assert_eq(moved_pawn.cell_id, route[first_home])
	assert_true(result.state.get_active_player().has_finished_all_pawns())
	assert_true(result.state.get_active_player().is_ranked())

	var finished_count := 0
	var ranked_count := 0
	for event in result.events:
		if event is PawnFinishedEvent:
			finished_count += 1
		if event is PlayerRankedEvent:
			ranked_count += 1
	assert_eq(finished_count, PlayerState.PAWNS_PER_PLAYER,
			"всичките 4 пионки минават HOME_STRETCH → FINISHED едновременно")
	assert_eq(ranked_count, 2,
			"2p: finisher-ът + auto-rank на единствения останал опонент")


## Engine: обикновено напредване в home stretch (не последна пионка) не прибира никого.
func test_engine_normal_home_stretch_advance_does_not_finish() -> void:
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var state := _setup_yellow_awaiting_move_from_path(first_home, 2)
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
	assert_false(_events_contain_pawn_finished(result.events))


## Engine: overshoot в home stretch → ILLEGAL_MOVE, без мутация (§12 / GAP-008).
func test_engine_overshoot_in_home_stretch_rejected_without_mutation() -> void:
	var last_index: int = Classic15x15Board.PLAYER_ROUTE_LENGTH - 1
	var state := _setup_yellow_awaiting_move_from_path(last_index, 3)
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


func _setup_yellow_in_home_stretch() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	return state


func _setup_yellow_awaiting_move_from_path(
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
