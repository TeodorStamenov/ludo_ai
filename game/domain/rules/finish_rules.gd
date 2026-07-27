class_name FinishRules
extends RefCounted
## Правила за класиране и приключване на мача (docs/V1_ARCHITECTURE.md, §4.1 / §4.2 / §12;
## docs/V1_GAME_DESIGN.md §3.1).
##
## Отговорности:
##   - класиране на играч с 4 прибрани пионки (PlayerRanked);
##   - автоматично последно място когато остава 1 некласиран;
##   - MATCH_FINISHED: MatchPhase.FINISHED + TurnPhase.MATCH_FINISHED + MatchFinishedEvent.
##
## TurnRules сочи OUTCOME_MATCH_FINISHED; GameEngine вика apply_match_finished (#90).
## Завършил / класиран играч не получава нов ход (TurnRules.should_skip_player).


## Играч с 4 FINISHED пионки, който още не е класиран.
func should_rank_player(player: PlayerState) -> bool:
	return (
			player != null
			and not player.is_ranked()
			and player.has_finished_all_pawns()
	)


func count_unranked_players(state: GameState) -> int:
	if state == null:
		return 0
	var count := 0
	for i in state.player_count():
		var player := state.get_player_by_index(i)
		if player != null and not state.is_ranked(player.player_id):
			count += 1
	return count


## Всички места са определени — мачът може да влезе в MATCH_FINISHED.
func is_ranking_complete(state: GameState) -> bool:
	if state == null:
		return false
	var count: int = state.player_count()
	if count < GameState.MIN_PLAYERS:
		return false
	return state.ranking.size() == count and count_unranked_players(state) == 0


## Класира играч с 4 FINISHED пионки. Връща PlayerRankedEvent или null.
func rank_finished_player(
		state: GameState,
		player_id: StringName,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> PlayerRankedEvent:
	if state == null or not PlayerId.is_valid(player_id):
		return null
	var player := state.get_player(player_id)
	if not should_rank_player(player):
		return null
	var rank_value: int = state.rank_player(player_id)
	if rank_value < PlayerState.RANK_FIRST:
		return null
	return PlayerRankedEvent.create_ranked(player_id, rank_value, command_sequence)


## Остава точно 1 некласиран и ≥1 класиран → последно място (стабилно при 2–4).
func auto_rank_last_remaining(
		state: GameState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> PlayerRankedEvent:
	if state == null:
		return null
	if state.ranking.size() < 1:
		return null
	if count_unranked_players(state) != 1:
		return null
	for i in state.player_count():
		var player := state.get_player_by_index(i)
		if player == null or state.is_ranked(player.player_id):
			continue
		var rank_value: int = state.rank_player(player.player_id)
		if rank_value < PlayerState.RANK_FIRST:
			return null
		return PlayerRankedEvent.create_ranked(
				player.player_id, rank_value, command_sequence)
	return null


## След прибиране / преди advance: rank finisher + евентуално последен.
## Връща Array от PlayerRankedEvent (0..2).
func resolve_ranking_progress(
		state: GameState,
		player_id: StringName,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> Array:
	var events: Array = []
	if state == null:
		return events
	var ranked := rank_finished_player(state, player_id, command_sequence)
	if ranked != null:
		events.append(ranked)
	var last := auto_rank_last_remaining(state, command_sequence)
	if last != null:
		events.append(last)
	return events


## MATCH_FINISHED фаза: допълва ranking[], MatchPhase.FINISHED, TurnPhase.MATCH_FINISHED.
## Връща MatchFinishedEvent (валиден при пълен ranking) или null.
func apply_match_finished(
		state: GameState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> MatchFinishedEvent:
	if state == null:
		return null

	for i in state.player_count():
		var player := state.get_player_by_index(i)
		if player != null and not state.is_ranked(player.player_id):
			state.rank_player(player.player_id)

	state.set_phase(MatchPhase.FINISHED)
	if state.turn != null:
		state.turn.enter_match_finished()

	return MatchFinishedEvent.create_from_state(state, command_sequence)
