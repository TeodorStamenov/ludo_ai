extends TestCase
## Business-critical тестове за фазата MATCH_FINISHED (Task #90 /
## docs/V1_ARCHITECTURE.md §4.1 / §4.2 / §12; docs/V1_GAME_DESIGN.md §3.1).
##
## Покрива: класиране при 4 FINISHED, auto-rank на последен, MatchPhase.FINISHED
## + MatchFinishedEvent през GameEngine, reject на команди след края.


var _engine: GameEngine
var _finish: FinishRules


func before_each() -> void:
	_engine = GameEngine.new()
	_finish = FinishRules.new()
	MatchId._reset_counter_for_tests()


func test_rank_finished_player_assigns_next_place() -> void:
	var state := _two_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	var event := _finish.rank_finished_player(
			state, state.get_player_by_index(0).player_id, 3)
	assert_not_null(event)
	assert_true(event is PlayerRankedEvent)
	assert_eq(event.rank, 1)
	assert_eq(event.player_id, state.get_player_by_index(0).player_id)
	assert_true(state.get_player_by_index(0).is_ranked())
	assert_eq(state.ranking.size(), 1)


func test_rank_finished_player_ignores_incomplete() -> void:
	var state := _two_player_in_progress()
	var player := state.get_player_by_index(0)
	_mark_pawn_finished(player, 0)
	_mark_pawn_finished(player, 1)
	_mark_pawn_finished(player, 2)
	assert_null(_finish.rank_finished_player(state, player.player_id, 1))
	assert_false(player.is_ranked())


func test_auto_rank_last_remaining_on_two_player() -> void:
	var state := _two_player_in_progress()
	var first := state.get_player_by_index(0)
	var second := state.get_player_by_index(1)
	_mark_all_pawns_finished(first)
	_finish.rank_finished_player(state, first.player_id, 2)
	var last := _finish.auto_rank_last_remaining(state, 2)
	assert_not_null(last)
	assert_eq(last.player_id, second.player_id)
	assert_eq(last.rank, 2)
	assert_true(_finish.is_ranking_complete(state))


func test_auto_rank_last_skips_when_two_unranked_remain() -> void:
	var state := _four_player_in_progress()
	state.rank_player(state.get_player_by_index(0).player_id)
	assert_null(_finish.auto_rank_last_remaining(state, 1))
	assert_eq(_finish.count_unranked_players(state), 3)


func test_engine_emits_match_finished_when_all_ranked() -> void:
	var state := _setup_awaiting_move_both_ready_to_end()
	state.rank_player(state.get_player_by_index(0).player_id)
	state.rank_player(state.get_player_by_index(1).player_id)
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_true(result.state.turn.is_match_finished())
	assert_true(_finish.is_ranking_complete(result.state))
	var finished: MatchFinishedEvent = null
	for entry in result.events:
		if entry is MatchFinishedEvent:
			finished = entry as MatchFinishedEvent
			break
	assert_not_null(finished)
	assert_true(finished.is_valid())
	assert_eq(finished.player_count(), 2)
	assert_eq(finished.get_winner_id(), result.state.ranking[0])


func test_engine_auto_ranks_last_and_finishes_match() -> void:
	var state := _setup_awaiting_move_both_ready_to_end()
	var already_first := state.get_player_by_index(1)
	_mark_all_pawns_finished(already_first)
	_finish.rank_finished_player(state, already_first.player_id, 1)
	assert_eq(state.ranking.size(), 1)
	assert_eq(_finish.count_unranked_players(state), 1)
	var active_id: StringName = state.get_active_player_id()
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(active_id, pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_true(result.state.turn.is_match_finished())
	assert_eq(result.state.ranking.size(), 2)
	assert_eq(result.state.ranking[1], active_id)
	var ranked_last := false
	var match_finished := false
	for entry in result.events:
		if entry is PlayerRankedEvent:
			var ranked := entry as PlayerRankedEvent
			assert_eq(ranked.player_id, active_id)
			assert_eq(ranked.rank, 2)
			ranked_last = true
		elif entry is MatchFinishedEvent:
			match_finished = true
			assert_true((entry as MatchFinishedEvent).is_valid())
	assert_true(ranked_last, "последното място трябва да е PlayerRanked")
	assert_true(match_finished, "трябва да има MatchFinishedEvent")


func test_commands_rejected_after_match_finished() -> void:
	var state := _setup_awaiting_move_both_ready_to_end()
	state.rank_player(state.get_player_by_index(0).player_id)
	state.rank_player(state.get_player_by_index(1).player_id)
	var pawn_id: StringName = state.get_active_player().get_pawn_by_index(0).pawn_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var move := MovePawnCommand.create_for_pawn(state.get_active_player_id(), pawn_id)
	state.stamp_command(move)
	var finished_result := _engine.validate_and_apply(state, move, rng)
	assert_true(finished_result.accepted)
	assert_true(finished_result.state.is_finished())
	var before := finished_result.state.duplicate_state()
	var rng_before := rng.get_state()
	var roll := RollDiceCommand.create_for_player(finished_result.state.get_active_player_id())
	finished_result.state.stamp_command(roll)

	var rejected := _engine.validate_and_apply(finished_result.state, roll, rng)

	assert_true(rejected.is_rejected())
	assert_eq(rejected.error.code, CommandError.CODE_MATCH_FINISHED)
	assert_true(finished_result.state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func test_four_player_ranking_stable_through_finish() -> void:
	var state := _four_player_in_progress()
	TurnRules.new().begin_player_turn(state, 0, 1)
	state.turn.enter_turn_end()
	var order: Array[StringName] = [
		state.get_player_by_index(2).player_id,
		state.get_player_by_index(0).player_id,
		state.get_player_by_index(3).player_id,
		state.get_player_by_index(1).player_id,
	]
	for player_id in order:
		state.rank_player(player_id)
	var event := _finish.apply_match_finished(state, 9)
	assert_not_null(event)
	assert_true(state.is_finished())
	assert_true(state.turn.is_match_finished())
	assert_eq(event.get_ranked_player_ids(), order)
	assert_eq(event.get_winner_id(), order[0])
	assert_true(event.is_valid())


func test_apply_match_finished_idempotent_phases() -> void:
	var state := _two_player_in_progress()
	state.rank_player(state.get_player_by_index(0).player_id)
	state.rank_player(state.get_player_by_index(1).player_id)
	var first := _finish.apply_match_finished(state, 4)
	var second := _finish.apply_match_finished(state, 5)
	assert_true(first.is_valid())
	assert_true(second.is_valid())
	assert_true(state.is_finished())
	assert_eq(state.ranking.size(), 2)


func _two_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 11
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 22
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _setup_awaiting_move_both_ready_to_end() -> GameState:
	var state := _two_player_in_progress()
	state.set_active_player_index(0)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.enter_awaiting_move(3, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	return state


func _mark_all_pawns_finished(player: PlayerState) -> void:
	for i in PlayerState.PAWNS_PER_PLAYER:
		_mark_pawn_finished(player, i)


func _mark_pawn_finished(player: PlayerState, pawn_index: int) -> void:
	var pawn := player.get_pawn_by_index(pawn_index)
	assert_not_null(pawn)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	pawn.mark_finished(route.size() - 1, route[route.size() - 1])
