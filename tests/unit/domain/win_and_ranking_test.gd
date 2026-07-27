extends TestCase
## Business-critical тестове за победа и класиране (Task #124 /
## docs/V1_GAME_DESIGN.md §3.1; docs/V1_ARCHITECTURE.md §4.2 / §12;
## #120–#123 имплементация; GAP-007).
##
## Инварианти: победител = първи с 4 FINISHED; ranking[] по ред на прибиране
## (стабилен); при 3–4p мачът продължава след 1-во; предпоследно → auto last +
## MatchFinished; завършил не получава нов ход.


var _finish: FinishRules
var _turn: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_turn = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## §3.1: първият с 4 прибрани е победител (rank 1 / ranking[0]).
func test_first_to_finish_all_pawns_is_winner() -> void:
	var state := _setup_awaiting_fourth_finish(_two_player_in_progress(), 0, 1)
	var winner_id: StringName = state.get_active_player_id()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			winner_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.get_player(winner_id).rank, PlayerState.RANK_FIRST)
	assert_eq(StringName(str(result.state.ranking[0])), winner_id)
	assert_true(_finish.has_first_place(result.state))
	assert_true(_has_player_ranked(result.events, winner_id, PlayerState.RANK_FIRST))
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_eq(finished.get_winner_id(), winner_id)


## 2p: победа → auto last → MATCH_FINISHED с пълен ranking от 2.
func test_two_player_win_auto_ranks_loser_and_finishes() -> void:
	var state := _setup_awaiting_fourth_finish(_two_player_in_progress(), 0, 1)
	var winner_id: StringName = state.get_active_player_id()
	var loser_id: StringName = state.get_player_by_index(1).player_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			winner_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_true(_finish.is_ranking_complete(result.state))
	assert_eq(result.state.get_ranked_player_ids(), [winner_id, loser_id] as Array[StringName])
	assert_eq(result.state.get_player(loser_id).rank, 2)
	assert_true(_has_player_ranked(result.events, loser_id, 2))
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_eq(finished.get_ranked_player_ids(), [winner_id, loser_id] as Array[StringName])
	assert_eq(finished.get_winner_id(), winner_id)


## §3.1 / §12: 4p след 1-во място → мачът тече; ranking не е пълен.
func test_four_player_continues_after_first_place_for_remaining_ranks() -> void:
	var state := _setup_awaiting_fourth_finish(_four_player_in_progress(), 0, 1)
	var winner_id: StringName = state.get_active_player_id()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			winner_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_eq(result.state.get_player(winner_id).rank, PlayerState.RANK_FIRST)
	assert_true(result.state.is_in_progress())
	assert_false(result.state.is_finished())
	assert_true(_finish.should_continue_match(result.state))
	assert_false(_finish.should_finish_match(result.state))
	assert_eq(_finish.count_unranked_players(result.state), 3)
	assert_null(_find_match_finished(result.events))
	assert_true(_turn.should_skip_player(result.state.get_player(winner_id)))
	assert_ne(result.state.get_active_player_id(), winner_id)


## §12: присвоен rank не се променя; редът в ranking[] е стабилен до края.
func test_ranking_order_is_stable_through_full_four_player_finish() -> void:
	var state := _setup_awaiting_finish_with_prior_ranks(
			_four_player_in_progress(), [0, 1], 2)
	var first_id: StringName = StringName(str(state.ranking[0]))
	var second_id: StringName = StringName(str(state.ranking[1]))
	var third_id: StringName = state.get_active_player_id()
	var last_id: StringName = &""
	for i in state.player_count():
		var pid: StringName = state.get_player_by_index(i).player_id
		if not state.is_ranked(pid) and pid != third_id:
			last_id = pid
			break
	assert_ne(last_id, &"")
	var expected: Array[StringName] = [first_id, second_id, third_id, last_id]
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			third_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_eq(result.state.get_ranked_player_ids(), expected)
	assert_eq(result.state.get_player(first_id).rank, 1)
	assert_eq(result.state.get_player(second_id).rank, 2)
	assert_eq(result.state.get_player(third_id).rank, 3)
	assert_eq(result.state.get_player(last_id).rank, 4)
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_eq(finished.get_ranked_player_ids(), expected)
	assert_eq(finished.get_winner_id(), first_id)


## 3p: 2-ро място определя 3-то (auto last); победителят остава ranking[0].
func test_three_player_second_place_locks_winner_and_last() -> void:
	var state := _setup_awaiting_finish_with_prior_ranks(
			_three_player_in_progress(), [0], 1)
	var winner_id: StringName = StringName(str(state.ranking[0]))
	var second_id: StringName = state.get_active_player_id()
	var last_id: StringName = &""
	for i in state.player_count():
		var pid: StringName = state.get_player_by_index(i).player_id
		if not state.is_ranked(pid) and pid != second_id:
			last_id = pid
			break
	assert_ne(last_id, &"")
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			second_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.is_finished())
	assert_eq(
			result.state.get_ranked_player_ids(),
			[winner_id, second_id, last_id] as Array[StringName])
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_eq(finished.get_winner_id(), winner_id)
	assert_true(_has_player_ranked(result.events, second_id, 2))
	assert_true(_has_player_ranked(result.events, last_id, 3))


## §12: класиран играч се прескача докато мачът още тече за останалите места.
func test_ranked_player_never_becomes_active_while_match_continues() -> void:
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
	for _i in current.player_count():
		assert_ne(current.get_active_player_id(), winner_id)
		assert_true(_turn.should_skip_player(current.get_player(winner_id)))
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
		current = advanced.state


## continue ↔ finish са комплементарни около победата (§3.1 / #122 vs #123).
func test_continue_and_finish_are_complementary_around_first_place() -> void:
	var four := _four_player_in_progress()
	_mark_all_pawns_finished(four.get_player_by_index(0))
	_finish.rank_finished_player(four, four.get_player_by_index(0).player_id, 1)
	assert_true(_finish.should_continue_match(four))
	assert_false(_finish.should_finish_match(four))

	var two := _two_player_in_progress()
	_mark_all_pawns_finished(two.get_player_by_index(0))
	_finish.rank_finished_player(two, two.get_player_by_index(0).player_id, 1)
	assert_false(_finish.should_continue_match(two))
	assert_true(_finish.should_finish_match(two))


func _two_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 1242
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _three_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_three_player()
	cfg.rng_seed = 1243
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 1244
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
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		player.get_pawn_by_index(i).mark_finished(route.size())
	var pawn := player.get_pawn_by_index(0)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	assert_eq(player.count_finished_pawns(), 3)
	assert_false(player.is_ranked())
	return state


func _setup_awaiting_finish_with_prior_ranks(
		state: GameState,
		prior_indices: Array,
		finisher_index: int
) -> GameState:
	for idx in prior_indices:
		var prior := state.get_player_by_index(int(idx))
		_mark_all_pawns_finished(prior)
		_finish.rank_finished_player(state, prior.player_id, 1)
	return _setup_awaiting_fourth_finish(state, finisher_index, 1)


func _mark_all_pawns_finished(player: PlayerState) -> void:
	for i in PlayerState.PAWNS_PER_PLAYER:
		var pawn := player.get_pawn_by_index(i)
		var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
		pawn.mark_finished(route.size())


func _has_player_ranked(events: Array, player_id: StringName, rank: int) -> bool:
	for entry in events:
		if entry is PlayerRankedEvent:
			var ev := entry as PlayerRankedEvent
			if ev.player_id == player_id and ev.rank == rank:
				return true
	return false


func _find_match_finished(events: Array) -> MatchFinishedEvent:
	for entry in events:
		if entry is MatchFinishedEvent:
			return entry as MatchFinishedEvent
	return null
