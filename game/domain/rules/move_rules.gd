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
##   - точен зар вътре в home stretch (#98 / YEL-051–055);
##   - забрана за движение на FINISHED пионка (#100) — can_move_pawn / collect;
##   - макс. 2 свои на MAIN_PATH / spawn (#108 / GAP-004 / GAP-006);
##   - опит за трета своя → невалиден ход (#109);
##   - кацане върху противникова купчина от 2 → невалиден ход (#111);
##   - прескачане на междинни купчини (не са стена) (#112);
##   - чужд home stretch е недостъпен за кацане / взимане (#115).
##
## Capture / stack immunity / прибиране → CaptureRules / StackRules / FinishRules.
## Stack formation events → GameEngine + StackRules.resolve_stack_formed (#110).
## Capture events → GameEngine + CaptureRules.resolve_capture (#113).
## Home stretch защита от противници → CaptureRules (#115).
## Gift → RESOLVING_POWER_UP.


const EXIT_BASE_VALUE: int = DiceState.EXIT_BASE_VALUE
## Невалиден destination index (няма ход / overshoot).
const DESTINATION_NONE: int = -1

var _finish_rules: FinishRules
var _stack_rules: StackRules
var _capture_rules: CaptureRules


func _init(
		finish_rules: FinishRules = null,
		stack_rules: StackRules = null,
		capture_rules: CaptureRules = null
) -> void:
	_finish_rules = finish_rules if finish_rules != null else FinishRules.new()
	_stack_rules = stack_rules if stack_rules != null else StackRules.new()
	_capture_rules = (
			capture_rules if capture_rules != null
			else CaptureRules.new(_stack_rules)
	)


func allows_exit_base(dice_value: int) -> bool:
	return dice_value == EXIT_BASE_VALUE


## True ако пионката може да излезе от база с дадения зар (YEL-030 / #92).
## Spawn трябва да приема собствена пионка без да надхвърли max 2 (#108 / GAP-006).
## Spawn с противникова купчина от 2 е блокиран (#111).
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
	var spawn := resolve_spawn_cell(state, player.player_id)
	if spawn == &"":
		return false
	if _capture_rules.blocks_landing(state, spawn, player.player_id):
		return false
	return _stack_rules.can_place_own_pawn(state, spawn, player.player_id, pawn.pawn_id)


## True ако кацането (MAIN_PATH) или spawn би сложил трета своя пионка (#109).
## Home-stretch заетост е отделно правило (YEL-053) — тук не се отчита.
func would_place_third_own_pawn(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if state == null or player == null or pawn == null:
		return false
	if pawn.is_in_base():
		if not allows_exit_base(dice_value):
			return false
		var spawn := resolve_spawn_cell(state, player.player_id)
		if spawn == &"":
			return false
		return not _stack_rules.can_place_own_pawn(
				state, spawn, player.player_id, pawn.pawn_id)
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
		return false
	return not _stack_rules.can_place_own_pawn(
			state, dest_cell, player.player_id, pawn.pawn_id)


## True ако ходът би кацнал върху имунна противникова купчина от 2 (#111).
## Междинни клетки не се проверяват тук — прескачането е would_be_blocked_en_route (#112).
func would_land_on_enemy_stack(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if state == null or player == null or pawn == null:
		return false
	if pawn.is_in_base():
		if not allows_exit_base(dice_value):
			return false
		var spawn := resolve_spawn_cell(state, player.player_id)
		if spawn == &"":
			return false
		return _capture_rules.blocks_landing(state, spawn, player.player_id)
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
		return false
	return _capture_rules.blocks_landing(state, dest_cell, player.player_id)


## True ако междинна клетка по хода блокира преминаване (#112).
## Дестинацията не влиза — кацането е #111 / max-own. Купчините никога не блокират.
func would_be_blocked_en_route(
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
	var traversed := resolve_traversed_cell_ids(pawn.path_index, dice_value, route)
	if traversed.size() <= 1:
		return false
	for i in range(traversed.size() - 1):
		var cell: StringName = traversed[i]
		if _capture_rules.blocks_passage(state, cell, player.player_id):
			return true
	return false


## True ако MovePawnCommand за пионката е валидна при този зар (#95 / #100).
## FINISHED пионка никога не е подвижна — независимо от зара.
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
		return (
				can_advance_on_board(state, player, pawn, dice_value)
				or _finish_rules.can_finish_pawn(state, player, pawn, dice_value)
		)
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


## Оставащи клетки до края на маршрута (последна HOME). 0 = на края / извън (YEL-055).
func remaining_steps_to_route_end(from_index: int, route_length: int) -> int:
	if from_index < 0 or route_length <= 0 or from_index >= route_length:
		return 0
	return (route_length - 1) - from_index


## Destination path_index след `steps` от `from_index`. Overshoot / край → NONE.
## Точен зар до края на маршрута (YEL-051/052 / GAP-008 rejected — без clamp).
func resolve_destination_index(from_index: int, steps: int, route_length: int) -> int:
	if from_index < 0 or steps <= 0 or route_length <= 0:
		return DESTINATION_NONE
	var remaining: int = remaining_steps_to_route_end(from_index, route_length)
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
## Междинни HOME клетки не блокират (YEL-054).
## MAIN_PATH дестинация: макс. 2 свои — трета е невалидна (#108 / #109 / GAP-004).
## MAIN_PATH дестинация с противникова купчина от 2 → невалидна (#111).
## Междинни MAIN_PATH клетки (вкл. противникови купчини) не блокират (#112).
## Capture на единична противникова след кацане → CaptureRules.resolve_capture (#113).
## Собствен home stretch: само occupancy на свои (#97 / YEL-053). Чужд → #115.
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
	if would_be_blocked_en_route(state, player, pawn, dice_value):
		return false
	var dest_cell: StringName = route[dest_index]
	if Classic15x15Board.is_home_stretch_cell_of(player.player_id, dest_cell):
		var occupancy := CellOccupancy.from_state(state)
		if occupancy.count_own_excluding(
				dest_cell, player.player_id, pawn.pawn_id) > 0:
			return false
		return true
	if _capture_rules.is_foreign_home_stretch(dest_cell, player.player_id):
		return false
	if _capture_rules.blocks_landing(state, dest_cell, player.player_id):
		return false
	return _stack_rules.can_place_own_pawn(
			state, dest_cell, player.player_id, pawn.pawn_id)


## True ако пионката е в home stretch и зарът е валиден точен ход (YEL-051–055 / #98).
func can_advance_in_home_stretch(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null or not pawn.is_in_home_stretch():
		return false
	return can_advance_on_board(state, player, pawn, dice_value)


## True ако ход от HOME_STRETCH би надхвърлил края на маршрута (YEL-052 / #98).
func would_overshoot_in_home_stretch(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null or player == null or state == null:
		return false
	if not pawn.is_in_home_stretch():
		return false
	if not DiceState.is_face_value(dice_value):
		return false
	var route := resolve_player_route(state, player.player_id)
	if route.is_empty():
		return false
	if pawn.path_index < 0 or pawn.path_index >= route.size():
		return false
	var remaining: int = remaining_steps_to_route_end(pawn.path_index, route.size())
	return dice_value > remaining


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
## FINISHED пионка не излиза (#100). Мутира pawn; връща false без промяна при невалидни входни данни.
func apply_exit_base(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null or pawn.is_finished():
		return false
	if not can_exit_base(state, player, pawn, dice_value):
		return false
	var spawn := resolve_spawn_cell(state, player.player_id)
	pawn.exit_base_to_spawn(spawn)
	return true


## Премества пионка с dice_value клетки по маршрута (YEL-040 / #96, YEL-050–055 / #97–#98).
## MAIN_PATH дестинация → MAIN_PATH; home stretch дестинация → HOME_STRETCH (без обиколка).
## Вътре в home stretch: само точен зар без overshoot. Прибиране до CENTER → FinishRules (#99).
## FINISHED пионка не се мести (#100). Мутира pawn; връща false без промяна ако ходът е невалиден.
func apply_board_move(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> bool:
	if pawn == null or pawn.is_finished():
		return false
	if not can_advance_on_board(state, player, pawn, dice_value):
		return false
	var route := resolve_player_route(state, player.player_id)
	var dest_index := resolve_destination_index(pawn.path_index, dice_value, route.size())
	var dest_cell: StringName = route[dest_index]
	var zone: int = _zone_for_destination(player.player_id, dest_cell)
	pawn.set_position(zone, dest_index, dest_cell)
	return true


## #212: destination index за power-up движение (телепорт напред / избутване
## назад) с до max_steps в посока direction (+1 напред, -1 назад) от
## from_index по player маршрута. При конфликт (imunna купчина / max 2 свои)
## на пълното разстояние опитва по-малко стъпки в СЪЩАТА посока, докато
## намери валидна клетка ("най-близката валидна клетка" — V1_GAME_DESIGN §4.3).
## DESTINATION_NONE ако дори 1 стъпка е извън маршрута или невалидна.
## За разлика от resolve_destination_index (нормален ход): тук overshoot към
## края на маршрута просто не се разглежда (idx извън route.size() се прескача),
## вместо да отхвърля целия ход — power-up-ите не могат да прибират пионка.
func resolve_power_up_destination_index(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		max_steps: int,
		direction: int
) -> int:
	if state == null or player == null or pawn == null or max_steps <= 0:
		return DESTINATION_NONE
	var route := resolve_player_route(state, player.player_id)
	if route.is_empty() or pawn.path_index < 0 or pawn.path_index >= route.size():
		return DESTINATION_NONE
	if route[pawn.path_index] != pawn.cell_id:
		return DESTINATION_NONE

	for steps in range(max_steps, 0, -1):
		var idx: int = pawn.path_index + steps * direction
		if idx < 0 or idx >= route.size():
			continue
		var cell: StringName = route[idx]
		if _capture_rules.blocks_landing(state, cell, player.player_id):
			continue
		if Classic15x15Board.is_home_stretch_cell_of(player.player_id, cell):
			var occupancy := CellOccupancy.from_state(state)
			if occupancy.count_own_excluding(cell, player.player_id, pawn.pawn_id) > 0:
				continue
			return idx
		if not _stack_rules.can_place_own_pawn(state, cell, player.player_id, pawn.pawn_id):
			continue
		return idx
	return DESTINATION_NONE


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
