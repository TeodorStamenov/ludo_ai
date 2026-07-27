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
## #86/#87 MVP: collect_valid_pawn_ids + apply_exit_base за база при зар 6.
## Ходове по дъската → #88 / #95.


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


## Spawn cell_id за seat според board_id на GameState. Непозната дъска → &"".
func resolve_spawn_cell(state: GameState, player_id: StringName) -> StringName:
	if state == null or player_id == &"":
		return &""
	if (
			state.board_id == Classic15x15Board.BOARD_ID
			or state.board_id == BoardDefinition.DEFAULT_BOARD_ID
	):
		return Classic15x15Board.spawn_cell_for(player_id)
	return &""


## Извежда пионка от база на spawn (YEL-030). Изисква BASE + валиден зар 6.
## Мутира pawn; връща false без промяна при невалидни входни данни.
func apply_exit_base(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if state == null or player == null or pawn == null:
		return false
	if not pawn.is_in_base():
		return false
	if not allows_exit_base(dice_value):
		return false
	var spawn := resolve_spawn_cell(state, player.player_id)
	if spawn == &"":
		return false
	pawn.exit_base_to_spawn(spawn)
	return true
