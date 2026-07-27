extends TestCase
## Business-critical тестове за приключване на играч при 4 FINISHED (Task #120 /
## docs/V1_GAME_DESIGN.md §3.1; docs/V1_ARCHITECTURE.md §12; GAP-007).
##
## Инварианти: 4 прибрани → PlayerRanked + skip; <4 → без класиране;
## при 4p първият finisher не приключва мача; завършил няма extra roll / нов ход.


var _finish: FinishRules
var _turn: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_turn = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## <4 FINISHED → should_rank_player false; rank_finished_player → null.
func test_incomplete_finish_does_not_rank() -> void:
	var state := _four_player_in_progress()
	var player := state.get_player_by_index(0)
	_mark_pawn_finished(player, 0)
	_mark_pawn_finished(player, 1)
	_mark_pawn_finished(player, 2)
	assert_eq(player.count_finished_pawns(), 3)
	assert_false(player.has_finished_all_pawns())
	assert_false(_finish.should_rank_player(player))
	assert_null(_finish.rank_finished_player(state, player.player_id, 1))
	assert_false(player.is_ranked())
	assert_eq(state.ranking.size(), 0)


## 4 FINISHED → следващо място + PlayerRanked (#120).
func test_four_finished_ranks_player() -> void:
	var state := _four_player_in_progress()
	var player := state.get_player_by_index(0)
	_mark_all_pawns_finished(player)
	assert_true(_finish.should_rank_player(player))
	var event := _finish.rank_finished_player(state, player.player_id, 4)
	assert_not_null(event)
	assert_true(event is PlayerRankedEvent)
	assert_eq(event.player_id, player.player_id)
	assert_eq(event.rank, PlayerState.RANK_FIRST)
	assert_true(player.is_ranked())
	assert_eq(state.ranking.size(), 1)
	assert_eq(StringName(str(state.ranking[0])), player.player_id)
	assert_true(_turn.should_skip_player(player))


## Engine 4p: 4-та прибрана → PlayerRanked, мачът продължава, ходът минава нататък.
func test_engine_four_player_first_completion_continues_match() -> void:
	var state := _setup_player_awaiting_fourth_finish(0, 1)
	var finisher_id: StringName = state.get_active_player_id()
	var finisher_index: int = state.active_player_index
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var cmd := MovePawnCommand.create_for_pawn(finisher_id, pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var after := result.state.get_player(finisher_id)
	assert_true(after.has_finished_all_pawns())
	assert_true(after.is_ranked())
	assert_eq(after.rank, PlayerState.RANK_FIRST)
	assert_eq(result.state.ranking.size(), 1)
	assert_false(result.state.is_finished(), "4p: остават некласирани → мачът тече")
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.active_player_index, finisher_index)
	assert_false(_turn.should_skip_player(result.state.get_active_player()))

	var ranked := false
	var turn_changed := false
	var match_finished := false
	for entry in result.events:
		if entry is PlayerRankedEvent:
			var ev := entry as PlayerRankedEvent
			if ev.player_id == finisher_id:
				assert_eq(ev.rank, 1)
				ranked = true
		elif entry is TurnChangedEvent:
			turn_changed = true
			assert_eq((entry as TurnChangedEvent).previous_player_index, finisher_index)
		elif entry is MatchFinishedEvent:
			match_finished = true
	assert_true(ranked, "4 FINISHED → PlayerRanked")
	assert_true(turn_changed, "ходът минава към следващ playable")
	assert_false(match_finished, "първи finisher не приключва 4p мач")


## Завършил играч се прескача при следващ advance (§12 / #120).
func test_engine_skips_completed_player_on_next_advance() -> void:
	var state := _setup_player_awaiting_fourth_finish(0, 1)
	var finisher_id: StringName = state.get_active_player_id()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var finish_cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(finish_cmd)
	var finished := _engine.validate_and_apply(state, finish_cmd, rng)
	assert_true(finished.accepted)
	assert_true(finished.state.get_player(finisher_id).is_ranked())

	var mid := finished.state
	var mover := mid.get_active_player()
	var pawn := mover.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(mover.player_id))
	mid.turn.enter_awaiting_move(2, [pawn.pawn_id])
	mid.dice.set_roll(mover.player_id, 2)
	var before_index: int = mid.active_player_index
	var move_cmd := MovePawnCommand.create_for_pawn(mover.player_id, pawn.pawn_id)
	mid.stamp_command(move_cmd)

	var advanced := _engine.validate_and_apply(mid, move_cmd, rng)

	assert_true(advanced.accepted)
	assert_ne(advanced.state.active_player_index, before_index)
	assert_ne(advanced.state.get_active_player_id(), finisher_id)
	assert_true(_turn.should_skip_player(advanced.state.get_player(finisher_id)))


## player_completed=true отменя pending extra roll → TURN_END (#120 / §12).
func test_resolve_after_move_completed_clears_extra_roll() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	_turn.resolve_after_roll(turn, 6, false, [&"green_0"])
	assert_true(turn.has_extra_roll_pending())
	var outcome := _turn.resolve_after_move(turn, false, true)
	assert_eq(outcome, TurnRules.OUTCOME_TURN_END)
	assert_true(turn.is_turn_end())
	assert_false(turn.has_extra_roll_pending())


## Engine 2p: 4-та прибрана → rank + auto-rank последен → MatchFinished.
func test_engine_two_player_completion_finishes_match() -> void:
	var state := _setup_two_player_awaiting_fourth_finish(1)
	var finisher_id: StringName = state.get_active_player_id()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.get_player(finisher_id).is_ranked())
	assert_eq(result.state.get_player(finisher_id).rank, PlayerState.RANK_FIRST)
	assert_true(result.state.is_finished())
	assert_true(_finish.is_ranking_complete(result.state))
	var ranked_finisher := false
	var match_finished := false
	for entry in result.events:
		if entry is PlayerRankedEvent and (entry as PlayerRankedEvent).player_id == finisher_id:
			ranked_finisher = true
		elif entry is MatchFinishedEvent:
			match_finished = true
	assert_true(ranked_finisher)
	assert_true(match_finished)


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 120
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _two_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 121
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


## Активен seat с 3 FINISHED + 1 на последна HOME, AWAITING_MOVE с exact dice.
func _setup_player_awaiting_fourth_finish(
		player_index: int,
		dice_value: int
) -> GameState:
	var state := _four_player_in_progress()
	_turn.begin_player_turn(state, player_index, 1)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size())
	var pawn := player.get_pawn_by_index(0)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_eq(player.count_finished_pawns(), 3)
	return state


func _setup_two_player_awaiting_fourth_finish(dice_value: int) -> GameState:
	var state := _two_player_in_progress()
	_turn.begin_player_turn(state, 0, 1)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size())
	var pawn := player.get_pawn_by_index(0)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	return state


func _mark_all_pawns_finished(player: PlayerState) -> void:
	for i in PlayerState.PAWNS_PER_PLAYER:
		_mark_pawn_finished(player, i)


func _mark_pawn_finished(player: PlayerState, pawn_index: int) -> void:
	var pawn := player.get_pawn_by_index(pawn_index)
	assert_not_null(pawn)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	pawn.mark_finished(route.size())
