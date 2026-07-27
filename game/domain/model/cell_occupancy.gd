class_name CellOccupancy
extends RefCounted
## Derived index: cell_id → пионки върху клетката (docs/V1_ARCHITECTURE.md §4.1 / §12;
## docs/V1_GAME_DESIGN.md §3.2; GAP-004 / GAP-006).
##
## Source of truth остава GameState.players[].pawns[].cell_id — този клас е
## query view за stacks / capture / spawn / home-stretch правила.
## Не сериализира се; строи се от snapshot при нужда.
##
## По подразбиране индексира само is_on_board() пионки (MAIN_PATH | HOME_STRETCH).
## BASE / FINISHED не участват в board occupancy (взимане / купчини).
## За свободни базови клетки виж free_base_cells().

## Максимум собствени пионки на обща клетка (V1_GAME_DESIGN §3.2 / §12).
const MAX_OWN_PAWNS_PER_CELL: int = 2

## cell_id (String) → Array[PawnState] (референции към живите pawn обекти).
var _by_cell: Dictionary = {}


## Индекс от GameState. Само пионки на дъската (is_on_board).
static func from_state(state: GameState) -> CellOccupancy:
	var occupancy := CellOccupancy.new()
	if state == null:
		return occupancy
	for player_entry in state.players:
		if not (player_entry is PlayerState):
			continue
		var player := player_entry as PlayerState
		for pawn_entry in player.pawns:
			if not (pawn_entry is PawnState):
				continue
			var pawn := pawn_entry as PawnState
			if not pawn.is_on_board():
				continue
			if pawn.cell_id == &"":
				continue
			occupancy._add(pawn)
	return occupancy


## Пионки върху клетката (копие на масива; редът следва обхождането на players/pawns).
func get_pawns_at(cell_id: StringName) -> Array:
	var key := String(cell_id)
	if not _by_cell.has(key):
		return []
	return (_by_cell[key] as Array).duplicate()


func count_at(cell_id: StringName) -> int:
	return get_pawns_at(cell_id).size()


func is_empty(cell_id: StringName) -> bool:
	return count_at(cell_id) == 0


## Собствени пионки на клетката (player_id).
func get_pawns_of_player_at(cell_id: StringName, player_id: StringName) -> Array:
	var result: Array = []
	for entry in get_pawns_at(cell_id):
		var pawn := entry as PawnState
		if pawn.get_player_id() == player_id:
			result.append(pawn)
	return result


func count_of_player_at(cell_id: StringName, player_id: StringName) -> int:
	return get_pawns_of_player_at(cell_id, player_id).size()


## Противникови пионки на клетката спрямо player_id.
func get_opponent_pawns_at(cell_id: StringName, player_id: StringName) -> Array:
	var result: Array = []
	for entry in get_pawns_at(cell_id):
		var pawn := entry as PawnState
		if pawn.get_player_id() != player_id:
			result.append(pawn)
	return result


func count_opponents_at(cell_id: StringName, player_id: StringName) -> int:
	return get_opponent_pawns_at(cell_id, player_id).size()


## Брой собствени пионки без exclude_pawn_id (за landing / exit-base проверки).
func count_own_excluding(
		cell_id: StringName,
		player_id: StringName,
		exclude_pawn_id: StringName
) -> int:
	var count := 0
	for entry in get_pawns_of_player_at(cell_id, player_id):
		var pawn := entry as PawnState
		if exclude_pawn_id != &"" and pawn.pawn_id == exclude_pawn_id:
			continue
		count += 1
	return count


## True ако има точно MAX_OWN_PAWNS_PER_CELL собствени пионки (имунна купчина).
func has_friendly_stack(cell_id: StringName, player_id: StringName) -> bool:
	return count_of_player_at(cell_id, player_id) == MAX_OWN_PAWNS_PER_CELL


## True ако някой противник има купчина от 2 на клетката.
func has_enemy_stack(cell_id: StringName, for_player_id: StringName) -> bool:
	var by_owner: Dictionary = {}
	for entry in get_opponent_pawns_at(cell_id, for_player_id):
		var pawn := entry as PawnState
		var owner := String(pawn.get_player_id())
		by_owner[owner] = int(by_owner.get(owner, 0)) + 1
		if int(by_owner[owner]) >= MAX_OWN_PAWNS_PER_CELL:
			return true
	return false


## True ако добавяне на собствена пионка не надвишава MAX_OWN_PAWNS_PER_CELL.
## exclude_pawn_id = движещата се пионка (вече на клетката или напускаща друга).
func can_accept_own_pawn(
		cell_id: StringName,
		player_id: StringName,
		exclude_pawn_id: StringName = &""
) -> bool:
	return count_own_excluding(cell_id, player_id, exclude_pawn_id) < MAX_OWN_PAWNS_PER_CELL


## Единствена противникова пионка на клетката, или null (0 или ≥2 / смесени).
## Не прилага shield / home-stretch имунитет — това е CaptureRules.
func get_single_opponent_at(cell_id: StringName, player_id: StringName) -> PawnState:
	var opponents := get_opponent_pawns_at(cell_id, player_id)
	if opponents.size() != 1:
		return null
	return opponents[0] as PawnState


## Заети cell_id в детерминиран (сортиран) ред.
func occupied_cell_ids() -> Array[StringName]:
	var keys: Array = _by_cell.keys()
	keys.sort()
	var ids: Array[StringName] = []
	for key in keys:
		ids.append(StringName(str(key)))
	return ids


## Свободни BASE клетки на seat (за връщане след capture — #114).
## base_cells = каноничният ред от BoardDefinition / Classic15x15Board.
static func free_base_cells(
		state: GameState,
		player_id: StringName,
		base_cells: Array
) -> Array[StringName]:
	var free: Array[StringName] = []
	if state == null or player_id == &"":
		return free
	var player := state.get_player(player_id)
	if player == null:
		return free
	var occupied: Dictionary = {}
	for pawn_entry in player.pawns:
		if not (pawn_entry is PawnState):
			continue
		var pawn := pawn_entry as PawnState
		if pawn.is_in_base() and pawn.cell_id != &"":
			occupied[String(pawn.cell_id)] = true
	for cell in base_cells:
		var cell_id := StringName(str(cell))
		if cell_id == &"":
			continue
		if not occupied.has(String(cell_id)):
			free.append(cell_id)
	return free


func _add(pawn: PawnState) -> void:
	var key := String(pawn.cell_id)
	if not _by_cell.has(key):
		_by_cell[key] = []
	(_by_cell[key] as Array).append(pawn)
