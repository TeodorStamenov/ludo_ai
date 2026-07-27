class_name StackRules
extends RefCounted
## Правила за купчини (stacks) (docs/V1_ARCHITECTURE.md, раздел 4; V1_GAME_DESIGN.md, раздел 3.2).
##
## Максимум CellOccupancy.MAX_OWN_PAWNS_PER_CELL собствени пионки на обща клетка.
## Купчина от 2 е имунизирана срещу взимане.
## Противниците могат да прескачат купчина (тя не е стена).
## Опит за трета своя пионка → невалидна команда.
##
## Occupancy query view: CellOccupancy (#107).
## MoveRules ползва can_place_own_pawn за MAIN_PATH / spawn landing (#108).
## Имунитет / прескачане / stack events → #110–#112.


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
