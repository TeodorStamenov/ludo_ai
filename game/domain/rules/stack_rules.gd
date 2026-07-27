class_name StackRules
extends RefCounted
## Правила за купчини (stacks) (docs/V1_ARCHITECTURE.md, раздел 4; V1_GAME_DESIGN.md, раздел 3.2).
##
## Максимум CellOccupancy.MAX_OWN_PAWNS_PER_CELL собствени пионки на обща клетка.
## Купчина от 2 е имунизирана срещу взимане.
## Противниците могат да прескачат купчина (тя не е стена) — CaptureRules.blocks_passage (#112).
## Опит за трета своя пионка → невалидна команда.
## Образуване → PawnStackFormedEvent (#110). Разпадане: ход на едната пионка
## оставя другата уязвима (няма отделно domain събитие — §4.4).
##
## Occupancy query view: CellOccupancy (#107).
## MoveRules ползва can_place_own_pawn за MAIN_PATH / spawn landing (#108).
## GameEngine reject при трета своя → #109.
## Имунитет при кацане (MoveRules + CaptureRules.blocks_landing) → #111.
## Прескачане: CaptureRules.blocks_passage + MoveRules en-route (#112).
## Взимане на единична противникова → CaptureRules.resolve_capture (#113).


const MAX_OWN_PAWNS_PER_CELL: int = CellOccupancy.MAX_OWN_PAWNS_PER_CELL


## Derived occupancy snapshot за текущия GameState.
func occupancy_of(state: GameState) -> CellOccupancy:
	return CellOccupancy.from_state(state)


## True ако клетката вече има имунна купчина от player_id.
func is_friendly_stack(state: GameState, cell_id: StringName, player_id: StringName) -> bool:
	return occupancy_of(state).has_friendly_stack(cell_id, player_id)


## True ако противник има купчина от 2 на клетката (не може да се стъпва).
func is_enemy_stack(
		state: GameState,
		cell_id: StringName,
		for_player_id: StringName
) -> bool:
	return occupancy_of(state).has_enemy_stack(cell_id, for_player_id)


## True ако собствена пионка може да кацне без да надвиши MAX (#108 / #109).
func can_place_own_pawn(
		state: GameState,
		cell_id: StringName,
		player_id: StringName,
		exclude_pawn_id: StringName = &""
) -> bool:
	return occupancy_of(state).can_accept_own_pawn(cell_id, player_id, exclude_pawn_id)


## True ако leaving_pawn е една от двете в friendly stack на cell — ходът ѝ разваля купчината (#110).
func would_break_friendly_stack(
		state: GameState,
		cell_id: StringName,
		player_id: StringName,
		leaving_pawn_id: StringName
) -> bool:
	if state == null or cell_id == &"" or player_id == &"" or leaving_pawn_id == &"":
		return false
	if not is_friendly_stack(state, cell_id, player_id):
		return false
	for entry in occupancy_of(state).get_pawns_of_player_at(cell_id, player_id):
		var pawn := entry as PawnState
		if pawn != null and pawn.pawn_id == leaving_pawn_id:
			return true
	return false


## След кацане на MAIN_PATH: ако има точно 2 свои → PawnStackFormedEvent; иначе null (#110).
func resolve_stack_formed(
		state: GameState,
		arriving: PawnState,
		command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
) -> PawnStackFormedEvent:
	if state == null or arriving == null:
		return null
	if not arriving.is_on_main_path() or arriving.cell_id == &"":
		return null
	var player_id := arriving.get_player_id()
	if player_id == &"":
		return null
	if not is_friendly_stack(state, arriving.cell_id, player_id):
		return null
	var resident := _find_stack_partner(state, arriving.cell_id, player_id, arriving.pawn_id)
	if resident == null:
		return null
	var event := PawnStackFormedEvent.create_from_states(
			arriving, resident, command_sequence)
	if not event.is_valid():
		return null
	return event


## Другата собствена MAIN_PATH пионка на клетката, или null.
func _find_stack_partner(
		state: GameState,
		cell_id: StringName,
		player_id: StringName,
		arriving_pawn_id: StringName
) -> PawnState:
	var partner: PawnState = null
	for entry in occupancy_of(state).get_pawns_of_player_at(cell_id, player_id):
		var pawn := entry as PawnState
		if pawn == null or pawn.pawn_id == arriving_pawn_id:
			continue
		if not pawn.is_on_main_path():
			continue
		if partner != null:
			return null
		partner = pawn
	return partner
