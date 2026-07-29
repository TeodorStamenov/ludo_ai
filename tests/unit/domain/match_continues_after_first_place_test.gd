extends TestCase
## Business-critical тестове за продължаване на мача след 1-во място (Task #122 /
## docs/V1_GAME_DESIGN.md §3.1; docs/V1_ARCHITECTURE.md §12).
##
## Инварианти: при 3–4p след победител мачът остава IN_PROGRESS; останалите
## могат да хвърлят/ходят; победителят се прескача; MatchFinished не се емитва.
## End-to-end победа/класиране → Task #124 / win_and_ranking_test.gd.


var _finish: FinishRules
var _turn: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_turn = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## 4p: след 1-во място → should_continue_match; ranking не е пълен.
func test_should_continue_after_first_place_four_player() -> void:
	var state := _four_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	_finish.rank_finished_player(state, state.get_player_by_index(0).player_id, 1)
	assert_true(_finish.has_first_place(state))
	assert_true(_finish.should_continue_match(state))
	assert_false(_finish.is_ranking_complete(state))
	assert_eq(_finish.count_unranked_players(state), 3)
	assert_null(_finish.auto_rank_last_remaining(state, 1))


## 3p: след 1-во място → should_continue_match; остават 2 за 2-ро/3-то.
func test_should_continue_after_first_place_three_player() -> void:
	var state := _three_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	_finish.rank_finished_player(state, state.get_player_by_index(0).player_id, 1)
	assert_true(_finish.has_first_place(state))
	assert_true(_finish.should_continue_match(state))
	assert_eq(_finish.count_unranked_players(state), 2)


## 2p: след победител остава 1 → should_continue false (auto last приключва).
func test_should_not_continue_when_one_unranked_remains() -> void:
	var state := _two_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	_finish.rank_finished_player(state, state.get_player_by_index(0).player_id, 1)
	assert_true(_finish.has_first_place(state))
	assert_false(_finish.should_continue_match(state))
	assert_eq(_finish.count_unranked_players(state), 1)


## Engine 4p: 1-во място → IN_PROGRESS, TurnChanged, без MatchFinished.
func test_engine_four_player_first_place_keeps_match_in_progress() -> void:
	var state := _setup_awaiting_fourth_finish(_four_player_in_progress(), 0, 1)
	var finisher_id: StringName = state.get_active_player_id()
	var finisher_index: int = state.active_player_index
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(_finish.has_first_place(result.state))
	assert_true(_finish.should_continue_match(result.state))
	assert_true(result.state.is_in_progress())
	assert_false(result.state.is_finished())
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.active_player_index, finisher_index)
	assert_true(_turn.should_skip_player(result.state.get_player(finisher_id)))
	assert_false(_turn.should_skip_player(result.state.get_active_player()))
	assert_true(_has_player_ranked(result.events, finisher_id, 1))
	assert_false(_has_match_finished(result.events))


## Engine 3p: след 1-во място следващият некласиран може да хвърли зар.
func test_engine_three_player_unranked_can_roll_after_first_place() -> void:
	var state := _setup_awaiting_fourth_finish(_three_player_in_progress(), 0, 1)
	var finisher_id: StringName = state.get_active_player_id()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var finish_cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(finish_cmd)
	var finished := _engine.validate_and_apply(state, finish_cmd, rng)
	assert_true(finished.accepted)
	assert_true(_finish.should_continue_match(finished.state))
	assert_true(finished.state.is_in_progress())

	var mid := finished.state
	var roller_id: StringName = mid.get_active_player_id()
	assert_ne(roller_id, finisher_id)
	assert_false(mid.is_ranked(roller_id))
	var roll_cmd := RollDiceCommand.create_for_player(roller_id)
	mid.stamp_command(roll_cmd)

	var rolled := _engine.validate_and_apply(mid, roll_cmd, rng)

	assert_true(rolled.accepted, "некласиран трябва да може да хвърля след 1-во място")
	assert_true(rolled.state.is_in_progress())
	assert_false(rolled.state.is_finished())
	assert_false(_has_match_finished(rolled.events))
	assert_true(rolled.events[0] is DiceRolledEvent)


## Engine 4p: победителят не става отново активен докато мачът тече.
func test_engine_skips_winner_while_match_continues() -> void:
	var state := _setup_awaiting_fourth_finish(_four_player_in_progress(), 0, 1)
	var winner_id: StringName = state.get_active_player_id()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var finish_cmd := MovePawnCommand.create_for_pawn(
			winner_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(finish_cmd)
	var after_first := _engine.validate_and_apply(state, finish_cmd, rng)
	assert_true(after_first.accepted)
	assert_true(_finish.should_continue_match(after_first.state))

	var current := after_first.state
	var seen_active: Dictionary = {}
	for _i in current.player_count():
		var active_id: StringName = current.get_active_player_id()
		assert_ne(active_id, winner_id, "победителят не получава нов ход (#122)")
		assert_false(current.is_ranked(active_id))
		seen_active[active_id] = true
		var mover := current.get_active_player()
		var pawn := mover.get_pawn_by_index(0)
		if pawn.is_in_base():
			pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(mover.player_id))
		current.turn.enter_awaiting_move(1, [pawn.pawn_id])
		current.dice.set_roll(mover.player_id, 1)
		var move_cmd := MovePawnCommand.create_for_pawn(mover.player_id, pawn.pawn_id)
		current.stamp_command(move_cmd)
		var advanced := _engine.validate_and_apply(current, move_cmd, rng)
		assert_true(advanced.accepted)
		assert_true(advanced.state.is_in_progress())
		assert_true(_finish.should_continue_match(advanced.state))
		current = advanced.state

	assert_eq(seen_active.size(), 3, "трите некласирани трябва да получат ход")
	assert_false(seen_active.has(winner_id))
	assert_true(_turn.should_skip_player(current.get_player(winner_id)))


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 1224
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _three_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_three_player()
	cfg.rng_seed = 1223
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _two_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 1222
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _setup_awaiting_fourth_finish(
		state: GameState,
		player_index: int,
		dice_value: int
) -> GameState:
	_turn.begin_player_turn(state, player_index, 1)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		var idx: int = first_home + i
		player.get_pawn_by_index(i).mark_finished(idx, route[idx])
	var pawn := player.get_pawn_by_index(0)
	var from_index: int = first_home - dice_value
	pawn.set_position(PawnZone.MAIN_PATH, from_index, route[from_index])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_eq(player.count_finished_pawns(), 3)
	assert_false(player.is_ranked())
	return state


func _mark_all_pawns_finished(player: PlayerState) -> void:
	for i in PlayerState.PAWNS_PER_PLAYER:
		var pawn := player.get_pawn_by_index(i)
		var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
		pawn.mark_finished(route.size() - 1, route[route.size() - 1])


func _has_match_finished(events: Array) -> bool:
	for entry in events:
		if entry is MatchFinishedEvent:
			return true
	return false


func _has_player_ranked(events: Array, player_id: StringName, rank: int) -> bool:
	for entry in events:
		if entry is PlayerRankedEvent:
			var ev := entry as PlayerRankedEvent
			if ev.player_id == player_id and ev.rank == rank:
				return true
	return false
