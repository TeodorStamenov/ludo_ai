class_name TurnRules
extends RefCounted
## Управление на смяната на ход и TurnState machine (docs/V1_ARCHITECTURE.md, §4.2;
## docs/V1_GAME_DESIGN.md §3.1; CURRENT_YELLOW_BEHAVIOR YEL-003/004/010–013/042/043).
##
## Отговорности:
##   - валидни преходи между TurnPhase;
##   - следващ активен играч (прескача класирани);
##   - опити в база и допълнително хвърляне при 6;
##   - after-roll / after-move / after-power-up изход към следваща фаза.
##
## GameEngine вика тези методи; изчисляването на валидни пионки е в MoveRules (#95).
## MatchPhase.FINISHED се задава от FinishRules (#90) при OUTCOME_MATCH_FINISHED.


const OUTCOME_AWAITING_MOVE: StringName = &"awaiting_move"
const OUTCOME_RETRY_ROLL: StringName = &"retry_roll"
const OUTCOME_EXTRA_ROLL: StringName = &"extra_roll"
const OUTCOME_TURN_END: StringName = &"turn_end"
const OUTCOME_RESOLVING_POWER_UP: StringName = &"resolving_power_up"
const OUTCOME_NEXT_TURN: StringName = &"next_turn"
const OUTCOME_MATCH_FINISHED: StringName = &"match_finished"

const EXTRA_ROLL_VALUE: int = DiceState.EXTRA_TURN_VALUE


## Разрешени ребра на state machine-а (§4.2). AWAITING_ROLL→AWAITING_ROLL = retry.
const _ALLOWED_TRANSITIONS: Dictionary = {
	TurnPhase.MATCH_START: [TurnPhase.AWAITING_ROLL],
	TurnPhase.AWAITING_ROLL: [
		TurnPhase.AWAITING_ROLL,
		TurnPhase.AWAITING_MOVE,
		TurnPhase.TURN_END,
	],
	TurnPhase.AWAITING_MOVE: [TurnPhase.RESOLVING_MOVE],
	TurnPhase.RESOLVING_MOVE: [
		TurnPhase.RESOLVING_POWER_UP,
		TurnPhase.AWAITING_ROLL,
		TurnPhase.TURN_END,
	],
	TurnPhase.RESOLVING_POWER_UP: [
		TurnPhase.AWAITING_ROLL,
		TurnPhase.TURN_END,
		TurnPhase.RESOLVING_MOVE,
	],
	TurnPhase.TURN_END: [TurnPhase.AWAITING_ROLL, TurnPhase.MATCH_FINISHED],
	TurnPhase.MATCH_FINISHED: [],
}


func can_transition(from_phase: int, to_phase: int) -> bool:
	if not TurnPhase.is_valid(from_phase) or not TurnPhase.is_valid(to_phase):
		return false
	var allowed = _ALLOWED_TRANSITIONS.get(from_phase, [])
	return to_phase in allowed


func grants_extra_roll(dice_value: int) -> bool:
	return dice_value == EXTRA_ROLL_VALUE


## Класиран играч не получава нов ход (§12 / FinishRules).
func should_skip_player(player: PlayerState) -> bool:
	return player == null or player.is_ranked()


func all_pawns_in_base(player: PlayerState) -> bool:
	if player == null or player.pawns.is_empty():
		return true
	for entry in player.pawns:
		if not (entry is PawnState) or not (entry as PawnState).is_in_base():
			return false
	return true


## Следващ playable индекс след from_index (wrap). ACTIVE_PLAYER_NONE ако няма.
## from_index < 0 → ползва state.active_player_index (или 0 при NONE).
func find_next_player_index(state: GameState, from_index: int = -1) -> int:
	if state == null or state.player_count() == 0:
		return GameState.ACTIVE_PLAYER_NONE
	var start: int = from_index
	if start < 0:
		start = state.active_player_index
	if start < 0:
		start = 0
	var count: int = state.player_count()
	for offset in range(1, count + 1):
		var idx: int = (start + offset) % count
		var player := state.get_player_by_index(idx)
		if not should_skip_player(player):
			return idx
	return GameState.ACTIVE_PLAYER_NONE


func count_playable_players(state: GameState) -> int:
	if state == null:
		return 0
	var count := 0
	for i in state.player_count():
		if not should_skip_player(state.get_player_by_index(i)):
			count += 1
	return count


## Активира ход: active_player_index + AWAITING_ROLL с правилния брой опити.
func begin_player_turn(
		state: GameState,
		player_index: int,
		turn_number: int
) -> bool:
	if state == null or state.turn == null:
		return false
	if player_index < 0 or player_index >= state.player_count():
		return false
	var player := state.get_player_by_index(player_index)
	if should_skip_player(player):
		return false
	state.set_active_player_index(player_index)
	state.turn.begin_player_turn(turn_number, all_pawns_in_base(player))
	return true


## След известен зар + валидни пионки (YEL-010–013 / YEL-042–045).
## Мутира turn; връща outcome StringName.
func resolve_after_roll(
		turn: TurnState,
		dice_value: int,
		all_in_base: bool,
		valid_pawn_ids: Array
) -> StringName:
	if turn == null:
		return OUTCOME_TURN_END
	if not turn.is_awaiting_roll():
		return OUTCOME_TURN_END

	turn.set_dice_value(dice_value)

	if all_in_base and not grants_extra_roll(dice_value):
		turn.consume_base_attempt()
		if turn.has_base_attempts_remaining():
			turn.clear_dice()
			turn.set_valid_command_kinds([TurnState.COMMAND_ROLL_DICE])
			turn.valid_pawn_ids.clear()
			return OUTCOME_RETRY_ROLL
		turn.enter_turn_end()
		return OUTCOME_TURN_END

	if grants_extra_roll(dice_value):
		turn.grant_extra_roll()
	else:
		turn.clear_extra_roll()

	if valid_pawn_ids.is_empty():
		return complete_turn_action(turn)

	turn.enter_awaiting_move(dice_value, valid_pawn_ids)
	return OUTCOME_AWAITING_MOVE


## Старт на обработка на избран ход: AWAITING_MOVE → RESOLVING_MOVE.
func begin_resolving_move(turn: TurnState) -> bool:
	if turn == null or not turn.is_awaiting_move():
		return false
	if not can_transition(TurnPhase.AWAITING_MOVE, TurnPhase.RESOLVING_MOVE):
		return false
	turn.enter_resolving_move()
	return true


## След приложен ход: gift → RESOLVING_POWER_UP, иначе complete_turn_action.
func resolve_after_move(turn: TurnState, landed_on_gift: bool = false) -> StringName:
	if turn == null:
		return OUTCOME_TURN_END
	if turn.is_awaiting_move():
		begin_resolving_move(turn)
	if not turn.is_resolving_move():
		return OUTCOME_TURN_END
	if landed_on_gift:
		turn.enter_resolving_power_up()
		return OUTCOME_RESOLVING_POWER_UP
	return complete_turn_action(turn)


## След power-up: extra roll или TURN_END (Extra Turn effect вече е grant-нат).
func resolve_after_power_up(turn: TurnState) -> StringName:
	if turn == null or not turn.is_resolving_power_up():
		return OUTCOME_TURN_END
	return complete_turn_action(turn)


## Ако има pending extra roll → AWAITING_ROLL (същият turn_number); иначе TURN_END.
func complete_turn_action(turn: TurnState) -> StringName:
	if turn == null:
		return OUTCOME_TURN_END
	if turn.has_extra_roll_pending():
		turn.enter_extra_roll()
		return OUTCOME_EXTRA_ROLL
	turn.enter_turn_end()
	return OUTCOME_TURN_END


## TURN_END → следващ играч (TurnChanged) или MATCH_FINISHED.
## Връща { "outcome": StringName, "event": TurnChangedEvent|null }.
func advance_from_turn_end(
		state: GameState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> Dictionary:
	var finished := {"outcome": OUTCOME_MATCH_FINISHED, "event": null}
	if state == null or state.turn == null:
		return finished
	if not state.turn.is_turn_end():
		state.turn.enter_turn_end()

	var previous_index: int = state.active_player_index
	var next_index: int = find_next_player_index(state, previous_index)
	if next_index == GameState.ACTIVE_PLAYER_NONE:
		state.turn.enter_match_finished()
		return finished

	var next_turn_number: int = maxi(state.turn.turn_number + 1, 1)
	if not begin_player_turn(state, next_index, next_turn_number):
		state.turn.enter_match_finished()
		return finished

	var event := TurnChangedEvent.create_from_state(
			state, previous_index, command_sequence)
	return {"outcome": OUTCOME_NEXT_TURN, "event": event}
