class_name FinishRules
extends RefCounted
## Правила за прибиране на пионка и класиране (docs/V1_ARCHITECTURE.md, §4.1 / §4.2 / §12;
## docs/V1_GAME_DESIGN.md §3.1 / §3.2; GAP-007).
##
## Отговорности:
##   - играч прибира пионка веднага щом всичките 4 влязат в home stretch —
##     флаг-превключване на място, БЕЗ допълнителна стъпка до централна клетка
##     (V1.1; #99 redefined). Пионките остават на собствените си 4 цветни
##     клетки (safe/exit/finish zone) — никога на CellId.CENTER;
##   - приключване на играч при 4 FINISHED → PlayerRanked (#120);
##   - при 3–4 играчи ranking[] е стабилен (#121);
##   - след 1-во място при ≥2 некласирани мачът продължава (#122 / §3.1);
##   - автоматично последно място когато остава 1 некласиран;
##   - приключване на целия мач (#123): should_finish_match → MatchPhase.FINISHED
##     + TurnPhase.MATCH_FINISHED + MatchFinishedEvent с пълен ranking.
##
## GameEngine: should_continue_match → мачът тече (#122); should_finish_match →
## apply_match_finished (#90 / #123). Завършил не получава нов ход (#120).
##
## #121/#122/#123 инварианти: мястото се присвоява веднъж; ≥2 некласирани → тече;
## предпоследно / auto last → пълен ranking → MATCH_FINISHED (без тихо класиране
## на ≥2 играчи без PlayerRanked).


## Играч е "прибрал" всичките си пионки веднага щом всичките 4 са влезли в
## home stretch (безопасната зона от 4 цветни клетки преди центъра) — не се
## изисква допълнителна стъпка до централна клетка (V1.1 / #99 redefined).
## Маркира всяка все още неFINISHED пионка на текущата ѝ клетка (без движение;
## occupancy правилата вече гарантират, че всяка от 4-те стои на различна
## клетка — MoveRules.can_advance_on_board / YEL-053). Връща Array от
## PawnFinishedEvent (0 ако вече е класиран / още не всичките 4 са там).
func resolve_home_stretch_completion(
		player: PlayerState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> Array:
	var events: Array = []
	if player == null or player.is_ranked():
		return events
	if not _all_pawns_ready_to_finish(player):
		return events
	for entry in player.pawns:
		var pawn := entry as PawnState
		if pawn == null or pawn.is_finished():
			continue
		var before := pawn.duplicate_state()
		pawn.mark_finished(pawn.path_index, pawn.cell_id)
		events.append(PawnFinishedEvent.create_from_states(before, pawn, command_sequence))
	return events


func _all_pawns_ready_to_finish(player: PlayerState) -> bool:
	for entry in player.pawns:
		var pawn := entry as PawnState
		if pawn == null:
			return false
		if not (pawn.is_in_home_stretch() or pawn.is_finished()):
			return false
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
