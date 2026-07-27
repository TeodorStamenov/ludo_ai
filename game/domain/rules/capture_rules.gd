class_name CaptureRules
extends RefCounted
## Правила за взимане на противникова пионка (docs/V1_ARCHITECTURE.md, раздел 4;
## docs/V1_GAME_DESIGN.md §3.1–3.2).
##
## Единична незащитена противникова пионка се взима при стъпване върху нея (#113).
## Взетата пионка се връща в свободна позиция в базата на своя играч (#114).
## Пионки в home stretch / BASE / FINISHED са защитени от взимане (#115).
## Купчина от 2 е имунизирана — противник не може да стъпи на клетката (#111).
## Купчината не е стена — противниците могат да я прескачат при движение (#112).
##
## Occupancy query: CellOccupancy (#107). Stack detection: StackRules / CellOccupancy.
## Типична верига: PawnMoved → PawnCaptured → PawnSentHome → …


var _stack_rules: StackRules


func _init(stack_rules: StackRules = null) -> void:
	_stack_rules = stack_rules if stack_rules != null else StackRules.new()


## True ако клетката има противникова купчина от 2 — имунна срещу взимане/кацане (#111).
func is_immune_stack(
		state: GameState,
		cell_id: StringName,
		attacking_player_id: StringName
) -> bool:
	if state == null or cell_id == &"" or attacking_player_id == &"":
		return false
	return _stack_rules.is_enemy_stack(state, cell_id, attacking_player_id)


## True ако кацане на MAIN_PATH клетка е забранено заради имунна купчина (#111).
func blocks_landing(
		state: GameState,
		cell_id: StringName,
		landing_player_id: StringName
) -> bool:
	return is_immune_stack(state, cell_id, landing_player_id)


## True ако клетката блокира преминаване (не кацане).
## V1: купчините не са стена — само защита при кацане (#112 / V1_GAME_DESIGN §3.2).
func blocks_passage(
		_state: GameState,
		_cell_id: StringName,
		_moving_player_id: StringName
) -> bool:
	return false


## True ако пионката може да бъде взета: MAIN_PATH, без щит (#113 / #115).
func is_capturable(pawn: PawnState) -> bool:
	if pawn == null:
		return false
	if not pawn.is_on_main_path():
		return false
	if pawn.cell_id == &"":
		return false
	if pawn.has_shield():
		return false
	return true


## Единствената capturable противникова на клетката, или null (#113).
## Имунна купчина / 0 / ≥2 / щит / не-MAIN_PATH → null.
func find_capturable_at(
		state: GameState,
		cell_id: StringName,
		attacking_player_id: StringName
) -> PawnState:
	if state == null or cell_id == &"" or attacking_player_id == &"":
		return null
	if is_immune_stack(state, cell_id, attacking_player_id):
		return null
	var opponent := _stack_rules.occupancy_of(state).get_single_opponent_at(
			cell_id, attacking_player_id)
	if opponent == null:
		return null
	if not is_capturable(opponent):
		return null
	return opponent


## След кацане на MAIN_PATH: взима единична незащитена противникова (#113),
## връща я в свободна base клетка (#114) и емитира PawnCaptured → PawnSentHome.
## Празен Array ако няма capture. Мутира state само при успех.
func resolve_capture(
		state: GameState,
		arriving: PawnState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> Array:
	var events: Array = []
	if state == null or arriving == null:
		return events
	if not arriving.is_on_main_path() or arriving.cell_id == &"":
		return events
	var attacker_id := arriving.get_player_id()
	if attacker_id == &"":
		return events
	var captured := find_capturable_at(state, arriving.cell_id, attacker_id)
	if captured == null:
		return events
	if captured.pawn_id == arriving.pawn_id:
		return events

	var captured_event := PawnCapturedEvent.create_from_states(
			arriving, captured, command_sequence)
	if not captured_event.is_valid():
		return events

	var from_cell: StringName = captured.cell_id
	var base_cell := _first_free_base_cell(state, captured.get_player_id())
	if base_cell == &"":
		return events

	var sent_event := PawnSentHomeEvent.create_sent_home(
			captured.pawn_id, from_cell, base_cell, command_sequence)
	if not sent_event.is_valid():
		return events

	captured.place_in_base(base_cell)
	events.append(captured_event)
	events.append(sent_event)
	return events


## Първа свободна base клетка в каноничен ред (#114), или &"".
func _first_free_base_cell(state: GameState, player_id: StringName) -> StringName:
	if player_id == &"":
		return &""
	var bases: Array = Classic15x15Board.base_cells_for(player_id)
	var free: Array[StringName] = CellOccupancy.free_base_cells(state, player_id, bases)
	if free.is_empty():
		return &""
	return free[0]
