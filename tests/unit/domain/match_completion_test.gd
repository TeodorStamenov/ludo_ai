extends TestCase
## Business-critical тестове за приключване на целия мач (Task #123 /
## docs/V1_GAME_DESIGN.md §3.1; docs/V1_ARCHITECTURE.md §4.2 / §12).
##
## Инварианти: should_finish_match ↔ should_continue_match; пълен ranking →
## MatchPhase.FINISHED + MatchFinishedEvent; ≥2 некласирани → без тихо finish;
## след края командите се отхвърлят.
## End-to-end победа/класиране → Task #124 / win_and_ranking_test.gd.


var _finish: FinishRules
var _turn: TurnRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_turn = TurnRules.new()
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## Пълен ranking → should_finish; continue е false.
func test_should_finish_when_ranking_complete() -> void:
	var state := _two_player_in_progress()
	state.rank_player(state.get_player_by_index(0).player_id)
	state.rank_player(state.get_player_by_index(1).player_id)
	assert_true(_finish.is_ranking_complete(state))
	assert_true(_finish.should_finish_match(state))
	assert_false(_finish.should_continue_match(state))


## 1 некласиран + 1-во място → should_finish (готов за auto-last); continue false.
func test_should_finish_when_ready_for_auto_last() -> void:
	var state := _two_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	_finish.rank_finished_player(state, state.get_player_by_index(0).player_id, 1)
	assert_eq(_finish.count_unranked_players(state), 1)
	assert_true(_finish.should_finish_match(state))
	assert_false(_finish.should_continue_match(state))


## 4p след 1-во място → continue true, finish false (§3.1 / #122 vs #123).
func test_should_not_finish_while_match_continues() -> void:
	var state := _four_player_in_progress()
	_mark_all_pawns_finished(state.get_player_by_index(0))
	_finish.rank_finished_player(state, state.get_player_by_index(0).player_id, 1)
	assert_true(_finish.should_continue_match(state))
	assert_false(_finish.should_finish_match(state))
	assert_null(_finish.apply_match_finished(state, 1))
	assert_false(state.is_finished())


## apply_match_finished при ≥2 некласирани → null; фазата и ranking не се пипат.
func test_apply_match_finished_rejects_incomplete_multi_unranked() -> void:
	var state := _four_player_in_progress()
	state.rank_player(state.get_player_by_index(0).player_id)
	assert_eq(_finish.count_unranked_players(state), 3)
	assert_null(_finish.apply_match_finished(state, 2))
	assert_false(state.is_finished())
	assert_eq(state.ranking.size(), 1)
	assert_eq(_finish.count_unranked_players(state), 3)


## Пълен ranking → FINISHED фази + валиден MatchFinishedEvent.
func test_apply_match_finished_sets_phases_and_event() -> void:
	var state := _four_player_in_progress()
	_turn.begin_player_turn(state, 0, 1)
	var order: Array[StringName] = [
		state.get_player_by_index(1).player_id,
		state.get_player_by_index(3).player_id,
		state.get_player_by_index(0).player_id,
		state.get_player_by_index(2).player_id,
	]
	for player_id in order:
		state.rank_player(player_id)
	var event := _finish.apply_match_finished(state, 7)
	assert_not_null(event)
	assert_true(event.is_valid())
	assert_true(state.is_finished())
	assert_true(state.turn.is_match_finished())
	assert_eq(event.get_ranked_player_ids(), order)
	assert_eq(event.get_winner_id(), order[0])


## Engine 2p: 4-та прибрана → auto-last + MatchFinished; ranking стабилен.
func test_engine_two_player_full_completion_finishes_match() -> void:
	var state := _setup_awaiting_fourth_finish(_two_player_in_progress(), 0, 1)
	var winner_id: StringName = state.get_active_player_id()
	var loser_id: StringName = state.get_player_by_index(1).player_id
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			winner_id, state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(_finish.should_finish_match(result.state) or result.state.is_finished())
	assert_true(result.state.is_finished())
	assert_true(result.state.turn.is_match_finished())
	assert_true(_finish.is_ranking_complete(result.state))
	assert_eq(result.state.ranking.size(), 2)
	assert_eq(StringName(str(result.state.ranking[0])), winner_id)
	assert_eq(StringName(str(result.state.ranking[1])), loser_id)
	assert_true(_has_player_ranked(result.events, winner_id, 1))
	assert_true(_has_player_ranked(result.events, loser_id, 2))
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_true(finished.is_valid())
	assert_eq(finished.get_winner_id(), winner_id)
	assert_eq(finished.player_count(), 2)


## Engine 3p: 2-ро място → auto last + MatchFinished; 1-вото място запазено.
func test_engine_three_player_penultimate_finishes_entire_match() -> void:
	var state := _setup_awaiting_finish_with_prior_ranks(
			_three_player_in_progress(), [0], 1)
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
	var finished := _find_match_finished(result.events)
	assert_not_null(finished)
	assert_eq(finished.get_winner_id(), first_id)
	assert_eq(finished.get_ranked_player_ids(), result.state.get_ranked_player_ids())


## След MatchFinished → RollDice се отхвърля без мутация на state/RNG.
func test_engine_rejects_commands_after_entire_match_finished() -> void:
	var state := _setup_awaiting_fourth_finish(_two_player_in_progress(), 0, 1)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var finish_cmd := MovePawnCommand.create_for_pawn(
			state.get_active_player_id(),
			state.get_active_player().get_pawn_by_index(0).pawn_id)
	state.stamp_command(finish_cmd)
	var finished_result := _engine.validate_and_apply(state, finish_cmd, rng)
	assert_true(finished_result.accepted)
	assert_true(finished_result.state.is_finished())
	var before := finished_result.state.duplicate_state()
	var rng_before := rng.get_state()
	var roll := RollDiceCommand.create_for_player(
			finished_result.state.get_active_player_id())
	finished_result.state.stamp_command(roll)

	var rejected := _engine.validate_and_apply(finished_result.state, roll, rng)

	assert_true(rejected.is_rejected())
	assert_eq(rejected.error.code, CommandError.CODE_MATCH_FINISHED)
	assert_true(finished_result.state.equals(before))
	assert_eq(rng.get_state(), rng_before)


func _two_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 1232
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _three_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_three_player()
	cfg.rng_seed = 1233
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 1234
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


## prior_indices са seat индекси, класирани преди текущия finisher (редове 1..n).
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
