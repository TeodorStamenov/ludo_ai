class_name MoveRules
extends RefCounted
## Правила за движение по маршрута (docs/V1_ARCHITECTURE.md, раздел 4, 14;
## docs/V1_GAME_DESIGN.md §3; CURRENT_YELLOW_BEHAVIOR YEL-013/030/040–045/050–055).
##
## Отговорности:
##   - излизане от база само при 6 (#92);
##   - изчисляване на валидни пионки след зар (#95 / YEL-020/044/045/052–055);
##   - движение по общото трасе (#96 / YEL-040–043) — точен зар, без GAP-008 clamp;
##   - влизане в home stretch (#97 / YEL-050) — MAIN_PATH → HOME_STRETCH, без обиколка;
##   - точен зар вътре в home stretch (#98 / YEL-051–055).
##
## Capture / stacks / FINISHED → CaptureRules / StackRules / FinishRules.
## Gift → RESOLVING_POWER_UP.


const EXIT_BASE_VALUE: int = DiceState.EXIT_BASE_VALUE
## Невалиден destination index (няма ход / overshoot).
const DESTINATION_NONE: int = -1


func allows_exit_base(dice_value: int) -> bool:
	return dice_value == EXIT_BASE_VALUE


## True ако пионката може да излезе от база с дадения зар (YEL-030 / #92).
func can_exit_base(
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
	return resolve_spawn_cell(state, player.player_id) != &""


## True ако MovePawnCommand за пионката е валидна при този зар (#95).
func can_move_pawn(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null:
		return false
	if pawn.is_finished():
		return false
	if pawn.is_in_base():
		return can_exit_base(state, player, pawn, dice_value)
	if pawn.is_on_board():
		return can_advance_on_board(state, player, pawn, dice_value)
	return false


## Пионки, за които MovePawnCommand е валидна след зар (#95).
## База → 6 + spawn (YEL-013/030). Дъска → can_advance_on_board (YEL-040+).
## Празен резултат = няма ход (YEL-045). Редът следва player.pawns.
func collect_valid_pawn_ids(
		state: GameState,
		player: PlayerState,
		dice_value: int
) -> Array:
	var result: Array = []
	if state == null or player == null or not DiceState.is_face_value(dice_value):
		return result
	for entry in player.pawns:
		if not (entry is PawnState):
			continue
		var pawn := entry as PawnState
		if can_move_pawn(state, player, pawn, dice_value):
			result.append(pawn.pawn_id)
	return result


## Spawn cell_id за seat според board_id на GameState. Непозната дъска → &"".
func resolve_spawn_cell(state: GameState, player_id: StringName) -> StringName:
	if state == null or player_id == &"":
		return &""
	if _uses_classic_board(state):
		return Classic15x15Board.spawn_cell_for(player_id)
	return &""


## Пълен маршрут на seat (cell_id). Непозната дъска / играч → [].
func resolve_player_route(state: GameState, player_id: StringName) -> Array[StringName]:
	var route: Array[StringName] = []
	if state == null or player_id == &"":
		return route
	if not _uses_classic_board(state):
		return route
	return Classic15x15Board.player_route_cell_ids_for(player_id)


## Destination path_index след `steps` от `from_index`. Overshoot / край → NONE.
## Точен зар до края на маршрута (YEL-052 / GAP-008 rejected — без clamp).
func resolve_destination_index(from_index: int, steps: int, route_length: int) -> int:
	if from_index < 0 or steps <= 0 or route_length <= 0:
		return DESTINATION_NONE
	var remaining: int = (route_length - 1) - from_index
	if remaining <= 0:
		return DESTINATION_NONE
	if steps > remaining:
		return DESTINATION_NONE
	return from_index + steps


## Клетките от хода: exclusive from → inclusive dest (YEL-040 последователно).
## Празен при overshoot / невалидни входни данни. Без clamp (GAP-008 rejected).
func resolve_traversed_cell_ids(
		from_index: int,
		steps: int,
		route: Array[StringName]
) -> Array[StringName]:
	var cells: Array[StringName] = []
	var dest_index := resolve_destination_index(from_index, steps, route.size())
	if dest_index == DESTINATION_NONE:
		return cells
	for i in range(from_index + 1, dest_index + 1):
		cells.append(route[i])
	return cells


## True ако пионка на дъската може да се премести с дадения зар (YEL-040/050/052/053/055).
## Home stretch дестинация: само ако крайната клетка е свободна от своя пионка (YEL-053).
func can_advance_on_board(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if state == null or player == null or pawn == null:
		return false
	if not pawn.is_on_board():
		return false
	if not DiceState.is_face_value(dice_value):
		return false
	var route := resolve_player_route(state, player.player_id)
	if route.is_empty():
		return false
	if pawn.path_index < 0 or pawn.path_index >= route.size():
		return false
	if route[pawn.path_index] != pawn.cell_id:
		return false
	var dest_index := resolve_destination_index(pawn.path_index, dice_value, route.size())
	if dest_index == DESTINATION_NONE:
		return false
	var dest_cell: StringName = route[dest_index]
	if Classic15x15Board.is_home_stretch_cell_of(player.player_id, dest_cell):
		if _own_other_pawn_on_cell(player, pawn.pawn_id, dest_cell):
			return false
	return true


## True ако ходът от MAIN_PATH би влязъл в собствения home stretch (YEL-050 / #97).
func would_enter_home_stretch(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null or not pawn.is_on_main_path():
		return false
	if not can_advance_on_board(state, player, pawn, dice_value):
		return false
	var route := resolve_player_route(state, player.player_id)
	var dest_index := resolve_destination_index(pawn.path_index, dice_value, route.size())
	if dest_index == DESTINATION_NONE:
		return false
	return Classic15x15Board.is_home_stretch_cell_of(player.player_id, route[dest_index])


## Извежда пионка от база на spawn (YEL-030). Изисква can_exit_base.
## Мутира pawn; връща false без промяна при невалидни входни данни.
func apply_exit_base(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if not can_exit_base(state, player, pawn, dice_value):
		return false
	var spawn := resolve_spawn_cell(state, player.player_id)
	pawn.exit_base_to_spawn(spawn)
	return true


## Премества пионка с dice_value клетки по маршрута (YEL-040 / #96, YEL-050 / #97).
## MAIN_PATH дестинация → MAIN_PATH; home stretch дестинация → HOME_STRETCH (без обиколка).
## Мутира pawn; връща false без промяна ако ходът е невалиден.
func apply_board_move(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if not can_advance_on_board(state, player, pawn, dice_value):
		return false
	var route := resolve_player_route(state, player.player_id)
	var dest_index := resolve_destination_index(pawn.path_index, dice_value, route.size())
	var dest_cell: StringName = route[dest_index]
	var zone: int = _zone_for_destination(player.player_id, dest_cell)
	pawn.set_position(zone, dest_index, dest_cell)
	return true


## Зона след хода: HOME_STRETCH при собствена HOME клетка (#97), иначе MAIN_PATH.
func _zone_for_destination(player_id: StringName, dest_cell: StringName) -> int:
	if Classic15x15Board.is_home_stretch_cell_of(player_id, dest_cell):
		return PawnZone.HOME_STRETCH
	return PawnZone.MAIN_PATH


func _uses_classic_board(state: GameState) -> bool:
	return (
			state.board_id == Classic15x15Board.BOARD_ID
			or state.board_id == BoardDefinition.DEFAULT_BOARD_ID
	)


func _own_other_pawn_on_cell(
		player: PlayerState,
		moving_pawn_id: StringName,
		cell_id: StringName
) -> bool:
	for entry in player.pawns:
		if not (entry is PawnState):
			continue
		var other := entry as PawnState
		if other.pawn_id == moving_pawn_id:
			continue
		if other.cell_id == cell_id and other.is_on_board():
			return true
	return false
