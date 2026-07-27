class_name MoveRules
extends RefCounted
## Правила за движение по маршрута (docs/V1_ARCHITECTURE.md, раздел 4, 14;
## docs/V1_GAME_DESIGN.md §3; CURRENT_YELLOW_BEHAVIOR YEL-013/030/044/045).
##
## Отговорности:
##   - излизане от база само при 6;
##   - изчисляване на валидни пионки след зар (#95 — пълна path валидация);
##   - движение по общото трасе / home stretch / точен зар за finish.
##
## #86 MVP: collect_valid_pawn_ids връща пионки в база при зар 6.
## Ходове по дъската се добавят от #95.


const EXIT_BASE_VALUE: int = DiceState.EXIT_BASE_VALUE


func allows_exit_base(dice_value: int) -> bool:
	return dice_value == EXIT_BASE_VALUE


## Пионки, за които MovePawnCommand е валидна след зар.
## База → само при 6 (YEL-013 / #92). Пълна path валидация → #95.
func collect_valid_pawn_ids(
		_state: GameState,
		player: PlayerState,
		dice_value: int
) -> Array:
	var result: Array = []
	if player == null or not DiceState.is_face_value(dice_value):
		return result
	for entry in player.pawns:
		if not (entry is PawnState):
			continue
		var pawn := entry as PawnState
		if pawn.is_finished():
			continue
		if pawn.is_in_base():
			if allows_exit_base(dice_value):
				result.append(pawn.pawn_id)
	return result
