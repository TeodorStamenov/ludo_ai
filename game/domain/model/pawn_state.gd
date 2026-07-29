class_name PawnState
extends RefCounted
## Логическо положение на пионка — не пикселна позиция (docs/V1_ARCHITECTURE.md, §4.1).
##
## Полета:
##   pawn_id, zone (BASE|MAIN_PATH|HOME_STRETCH|FINISHED),
##   path_index, cell_id, shield_turns_remaining
##
## Domain ползва стабилни cell_id и path_index; screen Vector2 е само в presentation.
## `in_base` от прототипа се замества от zone == PawnZone.BASE.
##
## Семантика на path_index (docs/CURRENT_YELLOW_BEHAVIOR.md / Classic15x15Board):
##   BASE     → PATH_INDEX_IN_BASE (-1)
##   MAIN_PATH / HOME_STRETCH → индекс в маршрута на играча (0 = spawn)
##   FINISHED → флаг-превключване на място в home stretch (V1.1) — pawn.cell_id
##     остава една от 4-те цветни клетки на собствения home stretch; пионката
##     НЕ се мести до централна клетка (маршрутът не включва центъра).

## path_index докато пионката е в базата (YEL-001 / прототип pawn.gd).
const PATH_INDEX_IN_BASE: int = -1
## path_index при излизане на spawn (YEL-030).
const PATH_INDEX_AT_SPAWN: int = 0


## Стабилен идентификатор (PawnId формат "{player_id}_{index}").
var pawn_id: StringName = &""
## Зона: PawnZone.BASE | MAIN_PATH | HOME_STRETCH | FINISHED.
var zone: int = PawnZone.BASE
## Индекс в маршрута на играча; PATH_INDEX_IN_BASE докато е в базата.
var path_index: int = PATH_INDEX_IN_BASE
## Стабилен идентификатор на клетката (CellId); не screen позиция.
var cell_id: StringName = &""
## Останали ходове със щит; 0 = няма активен щит (docs/V1_GAME_DESIGN.md §4.3).
var shield_turns_remaining: int = 0


## Фабрика за пълно конфигуриран PawnState.
static func create(
		p_pawn_id: StringName,
		p_zone: int,
		p_path_index: int,
		p_cell_id: StringName,
		p_shield_turns_remaining: int = 0
) -> PawnState:
	var pawn := PawnState.new()
	pawn.pawn_id = p_pawn_id
	pawn.zone = p_zone
	pawn.path_index = p_path_index
	pawn.cell_id = p_cell_id
	pawn.shield_turns_remaining = p_shield_turns_remaining
	return pawn


## Фабрика за пионка в базата (zone=BASE, path_index=-1, без щит).
static func create_in_base(p_pawn_id: StringName, p_cell_id: StringName) -> PawnState:
	return create(p_pawn_id, PawnZone.BASE, PATH_INDEX_IN_BASE, p_cell_id, 0)


## Фабрика за пионка на spawn (zone=MAIN_PATH, path_index=0, без щит).
static func create_at_spawn(p_pawn_id: StringName, p_spawn_cell: StringName) -> PawnState:
	return create(p_pawn_id, PawnZone.MAIN_PATH, PATH_INDEX_AT_SPAWN, p_spawn_cell, 0)


## Фабрика за прибрана пионка (zone=FINISHED) на собствената ѝ home stretch
## клетка (V1.1 — вижте класния коментар; НЕ CellId.CENTER).
static func create_finished(
		p_pawn_id: StringName, p_path_index: int, p_cell_id: StringName
) -> PawnState:
	return create(p_pawn_id, PawnZone.FINISHED, p_path_index, p_cell_id, 0)


func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


func get_pawn_index() -> int:
	return PawnId.get_index(pawn_id)


func is_in_base() -> bool:
	return zone == PawnZone.BASE


func is_on_main_path() -> bool:
	return zone == PawnZone.MAIN_PATH


func is_in_home_stretch() -> bool:
	return zone == PawnZone.HOME_STRETCH


func is_finished() -> bool:
	return zone == PawnZone.FINISHED


## True ако пионката е върху трасето или home stretch (не в база и не прибрана).
func is_on_board() -> bool:
	return zone == PawnZone.MAIN_PATH or zone == PawnZone.HOME_STRETCH


func has_shield() -> bool:
	return shield_turns_remaining > 0


## Поставя пионката в базата; щитът се нулира (връщане вкъщи / старт).
func place_in_base(p_cell_id: StringName) -> void:
	zone = PawnZone.BASE
	path_index = PATH_INDEX_IN_BASE
	cell_id = p_cell_id
	shield_turns_remaining = 0


## Извежда пионката на spawn при зар 6 (YEL-030).
func exit_base_to_spawn(p_spawn_cell: StringName) -> void:
	zone = PawnZone.MAIN_PATH
	path_index = PATH_INDEX_AT_SPAWN
	cell_id = p_spawn_cell


## Задава логическо положение без да пипа pawn_id / щита.
func set_position(p_zone: int, p_path_index: int, p_cell_id: StringName) -> void:
	zone = p_zone
	path_index = p_path_index
	cell_id = p_cell_id


## Маркира пионката като прибрана (флаг-превключване; не мести пионката —
## p_cell_id е нейната текуща home stretch клетка, V1.1).
func mark_finished(p_path_index: int, p_cell_id: StringName) -> void:
	zone = PawnZone.FINISHED
	path_index = p_path_index
	cell_id = p_cell_id
	shield_turns_remaining = 0


func apply_shield(turns: int) -> void:
	if turns < 0:
		shield_turns_remaining = 0
	else:
		shield_turns_remaining = turns


func clear_shield() -> void:
	shield_turns_remaining = 0


## Намалява щита с 1 ход; не пада под 0. Връща оставащите ходове.
func tick_shield() -> int:
	if shield_turns_remaining > 0:
		shield_turns_remaining -= 1
	return shield_turns_remaining


## True ако полетата са в договорните self-contained граници (§4.1 / §12).
## Не проверява съгласуваност с BoardDefinition маршрута — това е за MoveRules.
func is_valid() -> bool:
	if not PawnId.is_valid(pawn_id):
		return false
	if not PawnZone.is_valid(zone):
		return false
	if shield_turns_remaining < 0:
		return false
	if not CellId.is_valid(cell_id):
		return false
	match zone:
		PawnZone.BASE:
			return path_index == PATH_INDEX_IN_BASE
		PawnZone.MAIN_PATH, PawnZone.HOME_STRETCH, PawnZone.FINISHED:
			return path_index >= 0
		_:
			return false


## JSON-safe Dictionary: StringName → String, enum като int.
## Без Vector2 / NodePath — само стабилни идентификатори (§4.1).
func to_dict() -> Dictionary:
	return {
		"pawn_id": String(pawn_id),
		"zone": zone,
		"path_index": path_index,
		"cell_id": String(cell_id),
		"shield_turns_remaining": shield_turns_remaining,
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> PawnState:
	var pawn := PawnState.new()
	pawn.pawn_id = StringName(str(data.get("pawn_id", "")))
	pawn.zone = int(data.get("zone", PawnZone.BASE))
	pawn.path_index = int(data.get("path_index", PATH_INDEX_IN_BASE))
	pawn.cell_id = StringName(str(data.get("cell_id", "")))
	pawn.shield_turns_remaining = int(data.get("shield_turns_remaining", 0))
	return pawn


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_state() -> PawnState:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: PawnState) -> bool:
	if other == null:
		return false
	return (pawn_id == other.pawn_id
			and zone == other.zone
			and path_index == other.path_index
			and cell_id == other.cell_id
			and shield_turns_remaining == other.shield_turns_remaining)
