extends TestCase
## Business-critical тестове за класиране при 3–4 играчи (Task #121 /
## docs/V1_GAME_DESIGN.md §3.1; docs/V1_ARCHITECTURE.md §12).
##
## Инварианти: мачът продължава след 1-во / междинни места; ranking[] е стабилен
## (местата не се пренареждат); предпоследно приключване → auto last + MatchFinished;
## класиран играч се прескача.
## End-to-end победа/класиране → Task #124 / win_and_ranking_test.gd.


var _finish: FinishRules
var _turn: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_turn = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## 4p: 1-во място не auto-rank-ва; остават 3 некласирани.
func test_four_player_first_place_leaves_three_unranked() -> void:
	var state := _four_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	var events: Array = _finish.resolve_ranking_progress(
			state, state.get_player_by_index(0).player_id, 1)
	assert_eq(events.size(), 1)
	assert_eq((events[0] as PlayerRankedEvent).rank, 1)
	assert_eq(state.ranking.size(), 1)
	assert_eq(_finish.count_unranked_players(state), 3)
	assert_false(_finish.is_ranking_complete(state))
	assert_null(_finish.auto_rank_last_remaining(state, 1))


## 4p: 2-ро място при вече 1 класиран → rank 2; мачът продължава.
func test_four_player_second_place_continues_match() -> void:
	var state := _setup_four_player_awaiting_finish_with_prior_ranks([0], 1)
	var finisher_id: StringName = state.get_active_player_id()
	var prior: Array = state.get_ranked_player_ids()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.get_player(finisher_id).rank, 2)
	assert_eq(result.state.ranking.size(), 2)
	assert_eq(StringName(str(result.state.ranking[0])), prior[0])
	assert_eq(StringName(str(result.state.ranking[1])), finisher_id)
	assert_false(result.state.is_finished())
	assert_eq(_finish.count_unranked_players(result.state), 2)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.get_active_player_id(), finisher_id)
	assert_false(_has_match_finished(result.events))
	assert_true(_has_player_ranked(result.events, finisher_id, 2))


## 4p: 3-то място → auto last (4) + MatchFinished; редът на 1–2 е запазен.
func test_four_player_third_place_auto_ranks_last_and_finishes() -> void:
	var state := _setup_four_player_awaiting_finish_with_prior_ranks([0, 1], 2)
	var finisher_id: StringName = state.get_active_player_id()
	var first_id: StringName = StringName(str(state.ranking[0]))
	var second_id: StringName = StringName(str(state.ranking[1]))
	var last_id: StringName = &""
	for i in state.player_count():
		var pid: StringName = state.get_player_by_index(i).player_id
		if not state.is_ranked(pid) and pid != finisher_id:
			last_id = pid
			break
	assert_ne(last_id, &"")
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_true(_finish.is_ranking_complete(result.state))
	assert_eq(result.state.ranking.size(), 4)
	assert_eq(StringName(str(result.state.ranking[0])), first_id)
	assert_eq(StringName(str(result.state.ranking[1])), second_id)
	assert_eq(StringName(str(result.state.ranking[2])), finisher_id)
	assert_eq(StringName(str(result.state.ranking[3])), last_id)
	assert_eq(result.state.get_player(finisher_id).rank, 3)
	assert_eq(result.state.get_player(last_id).rank, 4)
	assert_true(_has_player_ranked(result.events, finisher_id, 3))
	assert_true(_has_player_ranked(result.events, last_id, 4))
	assert_true(_has_match_finished(result.events))
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_eq(finished.get_ranked_player_ids(), result.state.get_ranked_player_ids())
	assert_eq(finished.get_winner_id(), first_id)


## 3p: първи finisher → 1-во място; мачът продължава за 2-ро/3-то.
func test_three_player_first_completion_continues_match() -> void:
	var state := _setup_three_player_awaiting_fourth_finish(0, 1)
	var finisher_id: StringName = state.get_active_player_id()
	var finisher_index: int = state.active_player_index
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.get_player(finisher_id).rank, 1)
	assert_eq(result.state.ranking.size(), 1)
	assert_eq(_finish.count_unranked_players(result.state), 2)
	assert_false(result.state.is_finished())
	assert_true(result.state.turn.is_awaiting_roll())
	assert_ne(result.state.active_player_index, finisher_index)
	assert_true(_has_player_ranked(result.events, finisher_id, 1))
	assert_false(_has_match_finished(result.events))


## 3p: 2-ро място → auto last (3) + MatchFinished; 1-вото място е стабилно.
func test_three_player_second_place_auto_ranks_last_and_finishes() -> void:
	var state := _setup_three_player_awaiting_finish_with_prior_ranks([0], 1)
	var finisher_id: StringName = state.get_active_player_id()
	var first_id: StringName = StringName(str(state.ranking[0]))
	var last_id: StringName = &""
	for i in state.player_count():
		var pid: StringName = state.get_player_by_index(i).player_id
		if not state.is_ranked(pid) and pid != finisher_id:
			last_id = pid
			break
	assert_ne(last_id, &"")
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			finisher_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_true(_finish.is_ranking_complete(result.state))
	assert_eq(result.state.ranking.size(), 3)
	assert_eq(StringName(str(result.state.ranking[0])), first_id)
	assert_eq(StringName(str(result.state.ranking[1])), finisher_id)
	assert_eq(StringName(str(result.state.ranking[2])), last_id)
	assert_eq(result.state.get_player(first_id).rank, 1)
	assert_eq(result.state.get_player(finisher_id).rank, 2)
	assert_eq(result.state.get_player(last_id).rank, 3)
	assert_true(_has_player_ranked(result.events, finisher_id, 2))
	assert_true(_has_player_ranked(result.events, last_id, 3))
	assert_true(_has_match_finished(result.events))


## §12: вече присвоено място не се променя при повторно rank_player.
func test_ranking_places_are_stable_once_assigned() -> void:
	var state := _four_player_in_progress()
	var a: StringName = state.get_player_by_index(0).player_id
	var b: StringName = state.get_player_by_index(1).player_id
	var c: StringName = state.get_player_by_index(2).player_id
	assert_eq(state.rank_player(a), 1)
	assert_eq(state.rank_player(b), 2)
	assert_eq(state.rank_player(a), 0, "повторно класиране не променя мястото")
	assert_eq(state.get_player(a).rank, 1)
	assert_eq(state.rank_player(c), 3)
	assert_eq(state.get_ranked_player_ids(), [a, b, c] as Array[StringName])
	assert_eq(state.get_player(a).rank, 1)
	assert_eq(state.get_player(b).rank, 2)


## 4p с два класирани: advance прескача и двамата към следващия playable.
func test_four_player_skips_multiple_ranked_on_advance() -> void:
	var state := _four_player_in_progress()
	_turn.begin_player_turn(state, 0, 1)
	state.rank_player(state.get_player_by_index(1).player_id)
	state.rank_player(state.get_player_by_index(2).player_id)
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	state.turn.enter_awaiting_move(2, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, 2)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_false(result.state.is_finished())
	assert_eq(result.state.active_player_index, 3)
	assert_false(_turn.should_skip_player(result.state.get_active_player()))
	assert_true(_turn.should_skip_player(result.state.get_player_by_index(1)))
	assert_true(_turn.should_skip_player(result.state.get_player_by_index(2)))


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 1214
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _three_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_three_player()
	cfg.rng_seed = 1213
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


## Активен 3p seat с 3 FINISHED + 1 на последна HOME, AWAITING_MOVE.
func _setup_three_player_awaiting_fourth_finish(
		player_index: int,
		dice_value: int
) -> GameState:
	var state := _three_player_in_progress()
	_prepare_awaiting_fourth_finish(state, player_index, dice_value)
	return state


## 4p: предварително класира prior_indices (по ред), после активен finisher.
func _setup_four_player_awaiting_finish_with_prior_ranks(
		prior_indices: Array,
		finisher_index: int
) -> GameState:
	var state := _four_player_in_progress()
	for entry in prior_indices:
		var idx: int = int(entry)
		_mark_all_pawns_finished(state.get_player_by_index(idx))
		state.rank_player(state.get_player_by_index(idx).player_id)
	_prepare_awaiting_fourth_finish(state, finisher_index, 1)
	return state


## 3p: предварително класира prior_indices, после активен finisher.
func _setup_three_player_awaiting_finish_with_prior_ranks(
		prior_indices: Array,
		finisher_index: int
) -> GameState:
	var state := _three_player_in_progress()
	for entry in prior_indices:
		var idx: int = int(entry)
		_mark_all_pawns_finished(state.get_player_by_index(idx))
		state.rank_player(state.get_player_by_index(idx).player_id)
	_prepare_awaiting_fourth_finish(state, finisher_index, 1)
	return state


func _prepare_awaiting_fourth_finish(
		state: GameState,
		player_index: int,
		dice_value: int
) -> void:
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
	assert_false(player.is_ranked())


func _mark_all_pawns_finished(player: PlayerState) -> void:
	for i in PlayerState.PAWNS_PER_PLAYER:
		var pawn := player.get_pawn_by_index(i)
		var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
		pawn.mark_finished(route.size())


func _has_match_finished(events: Array) -> bool:
	for entry in events:
		if entry is MatchFinishedEvent:
			return true
	return false


func _find_match_finished(events: Array) -> MatchFinishedEvent:
	for entry in events:
		if entry is MatchFinishedEvent:
			return entry as MatchFinishedEvent
	return null


func _has_player_ranked(events: Array, player_id: StringName, rank: int) -> bool:
	for entry in events:
		if entry is PlayerRankedEvent:
			var ev := entry as PlayerRankedEvent
			if ev.player_id == player_id and ev.rank == rank:
				return true
	return false
