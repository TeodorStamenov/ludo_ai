class_name FinishRules
extends RefCounted
## Правила за прибиране на пионка и класиране (docs/V1_ARCHITECTURE.md, §4.1 / §4.2 / §12;
## docs/V1_GAME_DESIGN.md §3.1 / §3.2; GAP-007).
##
## Отговорности:
##   - HOME_STRETCH → FINISHED при точен зар до центъра (#99);
##   - приключване на играч при 4 FINISHED → PlayerRanked (#120);
##   - при 3–4 играчи ranking[] е стабилен (#121);
##   - след 1-во място при ≥2 некласирани мачът продължава (#122 / §3.1);
##   - автоматично последно място когато остава 1 некласиран;
##   - приключване на целия мач (#123): should_finish_match → MatchPhase.FINISHED
##     + TurnPhase.MATCH_FINISHED + MatchFinishedEvent с пълен ranking.
##
## Маршрутът не включва CENTER — remaining_to_finish = remaining_to_last_home + 1.
## GameEngine: should_continue_match → мачът тече (#122); should_finish_match →
## apply_match_finished (#90 / #123). Завършил не получава нов ход (#120).
##
## #121/#122/#123 инварианти: мястото се присвоява веднъж; ≥2 некласирани → тече;
## предпоследно / auto last → пълен ranking → MATCH_FINISHED (без тихо класиране
## на ≥2 играчи без PlayerRanked).


## Оставащи стъпки до центъра (последна HOME + 1). 0 = извън маршрута / вече минато.
func remaining_steps_to_finish(from_index: int, route_length: int) -> int:
	if from_index < 0 or route_length <= 0 or from_index >= route_length:
		return 0
	return route_length - from_index


## True ако пионка в HOME_STRETCH може да се прибере с точен зар до центъра (#99).
func can_finish_pawn(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if state == null or player == null or pawn == null:
		return false
	if not pawn.is_in_home_stretch():
		return false
	if not DiceState.is_face_value(dice_value):
		return false
	var route := _resolve_player_route(state, player.player_id)
	if route.is_empty():
		return false
	if pawn.path_index < 0 or pawn.path_index >= route.size():
		return false
	if route[pawn.path_index] != pawn.cell_id:
		return false
	var remaining: int = remaining_steps_to_finish(pawn.path_index, route.size())
	return remaining > 0 and dice_value == remaining


## Прибира пионка в центъра (FINISHED, CellId.CENTER). Изисква can_finish_pawn.
## Вече FINISHED пионка не се пипа (#100). Мутира pawn; връща false без промяна при невалидни входни данни.
func apply_finish_pawn(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null or pawn.is_finished():
		return false
	if not can_finish_pawn(state, player, pawn, dice_value):
		return false
	var route := _resolve_player_route(state, player.player_id)
	pawn.mark_finished(route.size())
	return true


## Играч с 4 FINISHED пионки, който още не е класиран (#120).
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


## True ако ranking[] вече има 1-во място (победител по §3.1).
func has_first_place(state: GameState) -> bool:
	return state != null and state.ranking.size() >= 1


## §3.1 / #122: при ≥2 некласирани мачът продължава за останалите места.
## След 1-во / междинно място в 3–4p → true; след auto last / пълен ranking → false.
## 2p след победител (остава 1) → false — auto_rank_last приключва мача.
func should_continue_match(state: GameState) -> bool:
	if state == null:
		return false
	return count_unranked_players(state) >= 2


## §3.1 / #123: мачът трябва да приключи — пълен ranking или готов за auto-last.
## Комплементарно на should_continue_match: не и двете true едновременно.
func should_finish_match(state: GameState) -> bool:
	if state == null:
		return false
	if is_ranking_complete(state):
		return true
	return has_first_place(state) and count_unranked_players(state) == 1


## Приключва играч с 4 FINISHED (#120): следващо място + PlayerRankedEvent.
## Връща null ако няма 4 прибрани / вече е класиран / невалиден вход.
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


## Остава точно 1 некласиран и ≥1 класиран → последно място (стабилно при 2–4 / #121).
## При ≥2 некласирани (типично след 1-во / 2-ро в 3–4p) → null; should_continue_match (#122).
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


## След прибиране / преди advance: следващо място + евентуално последен (#120 / #121).
## При 3–4p: 1-во / междинно → само finisher event (мачът продължава, #122);
## предпоследно → + auto last. Мястата в ranking[] не се пренареждат.
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


## #123: приключва целия мач — MatchPhase.FINISHED + TurnPhase.MATCH_FINISHED +
## MatchFinishedEvent. Допуска само пълен ranking или safety auto-last на 1 останал
## (PlayerRanked трябва вече да е емитнат от auto_rank_last_remaining / resolve).
## При ≥2 некласирани → null (мачът продължава, #122); без тихо класиране на група.
func apply_match_finished(
		state: GameState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> MatchFinishedEvent:
	if state == null:
		return null
	if not should_finish_match(state):
		return null

	if not is_ranking_complete(state):
		_rank_sole_unranked_player(state)
		if not is_ranking_complete(state):
			return null

	state.set_phase(MatchPhase.FINISHED)
	if state.turn != null:
		state.turn.enter_match_finished()

	return MatchFinishedEvent.create_from_state(state, command_sequence)


## Safety за apply_match_finished: класира единствения некласиран без event
## (event-ът вече е от auto_rank_last_remaining в GameEngine).
func _rank_sole_unranked_player(state: GameState) -> void:
	if count_unranked_players(state) != 1:
		return
	for i in state.player_count():
		var player := state.get_player_by_index(i)
		if player != null and not state.is_ranked(player.player_id):
			state.rank_player(player.player_id)
			return


func _resolve_player_route(state: GameState, player_id: StringName) -> Array[StringName]:
	var route: Array[StringName] = []
	if state == null or player_id == &"":
		return route
	if (
			state.board_id != Classic15x15Board.BOARD_ID
			and state.board_id != BoardDefinition.DEFAULT_BOARD_ID
	):
		return route
	return Classic15x15Board.player_route_cell_ids_for(player_id)
