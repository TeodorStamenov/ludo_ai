class_name PlayerState
extends RefCounted
## Състояние на един играч вътре в GameState (docs/V1_ARCHITECTURE.md, §4.1).
##
## Полета:
##   player_id, seat, color/team, controller_type,
##   animal_id, pawns[], rank, status_effects[]
##
## player_id ≠ color (пазят се поотделно); в класическото Ludo v1 seat и цвят
## са 1:1 с PlayerId — фабриките подразбират color = player_id, seat = to_seat().
##
## Пионките са PawnState (логическо положение). Щитът е на пионката;
## status_effects[] са ефекти на ниво играч (JSON-safe Dictionary записи).
##
## controller_type ползва MatchConfig.ControllerType (HUMAN | AI | REMOTE).
## rank: RANK_UNRANKED докато играчът не е класиран; после 1..MAX_RANK.

## Все още не е класиран (мачът тече / не е прибрал 4 пионки).
const RANK_UNRANKED: int = 0
## Най-ниско валидно класиране (1-во място).
const RANK_FIRST: int = 1
## Най-високо валидно класиране при 4 играчи.
const RANK_MAX: int = PlayerId.COUNT

## Брой пионки на играч — архитектурен инвариант (§12).
const PAWNS_PER_PLAYER: int = PawnId.PAWNS_PER_PLAYER


## Стабилен идентификатор на мястото (PlayerId).
var player_id: StringName = &""
## Индекс на seat (0–3); в v1 съвпада с PlayerId.to_seat(player_id).
var seat: int = -1
## Цвят/отбор (StringName); в v1 обикновено = player_id, но полето е отделно.
var color: StringName = &""
## MatchConfig.ControllerType: HUMAN | AI | REMOTE.
var controller_type: int = MatchConfig.ControllerType.HUMAN
## Избрано животно-пионка (AnimalId).
var animal_id: StringName = AnimalId.DEFAULT
## Точно PAWNS_PER_PLAYER × PawnState.
var pawns: Array = []
## Класиране: RANK_UNRANKED или 1..RANK_MAX.
var rank: int = RANK_UNRANKED
## Ефекти на ниво играч. Всеки запис: { "id": String, "turns_remaining": int }.
var status_effects: Array = []


## Фабрика за пълно конфигуриран PlayerState (пawns/status_effects се копират по референция).
static func create(
		p_player_id: StringName,
		p_seat: int,
		p_color: StringName,
		p_controller_type: int,
		p_animal_id: StringName,
		p_pawns: Array = [],
		p_rank: int = RANK_UNRANKED,
		p_status_effects: Array = []
) -> PlayerState:
	var player := PlayerState.new()
	player.player_id = p_player_id
	player.seat = p_seat
	player.color = p_color
	player.controller_type = p_controller_type
	player.animal_id = p_animal_id
	player.pawns = p_pawns.duplicate()
	player.rank = p_rank
	player.status_effects = _duplicate_status_effects(p_status_effects)
	return player


## Фабрика от активен MatchConfig seat + базови клетки (4 × PawnState в BASE).
## color подразбира player_id; seat = PlayerId.to_seat(player_id).
static func create_from_seat_config(
		seat_config: MatchConfig.SeatConfig,
		base_cells: Array
) -> PlayerState:
	return create_with_base_pawns(
			seat_config.player_id,
			seat_config.controller_type,
			seat_config.animal_id,
			base_cells)


## Фабрика с 4 пионки в базата (path_index=-1, zone=BASE).
## base_cells трябва да са PAWNS_PER_PLAYER cell_id в ред index 0→3.
static func create_with_base_pawns(
		p_player_id: StringName,
		p_controller_type: int,
		p_animal_id: StringName,
		base_cells: Array,
		p_color: StringName = &""
) -> PlayerState:
	var resolved_color: StringName = p_color if p_color != &"" else p_player_id
	var base_pawns: Array = []
	for i in PAWNS_PER_PLAYER:
		var cell: StringName = &""
		if i < base_cells.size():
			cell = StringName(base_cells[i])
		base_pawns.append(PawnState.create_in_base(
				PawnId.for_player(p_player_id, i), cell))
	return create(
			p_player_id,
			PlayerId.to_seat(p_player_id),
			resolved_color,
			p_controller_type,
			p_animal_id,
			base_pawns,
			RANK_UNRANKED,
			[])


func is_human() -> bool:
	return controller_type == MatchConfig.ControllerType.HUMAN


func is_ai() -> bool:
	return controller_type == MatchConfig.ControllerType.AI


func is_remote() -> bool:
	return controller_type == MatchConfig.ControllerType.REMOTE


func is_ranked() -> bool:
	return rank >= RANK_FIRST


## True ако и четирите пионки са в зона FINISHED (§3.1 / FinishRules).
func has_finished_all_pawns() -> bool:
	if pawns.size() != PAWNS_PER_PLAYER:
		return false
	for pawn in pawns:
		if not (pawn is PawnState) or not (pawn as PawnState).is_finished():
			return false
	return true


func count_finished_pawns() -> int:
	var count := 0
	for pawn in pawns:
		if pawn is PawnState and (pawn as PawnState).is_finished():
			count += 1
	return count


func count_pawns_in_zone(zone: int) -> int:
	var count := 0
	for pawn in pawns:
		if pawn is PawnState and (pawn as PawnState).zone == zone:
			count += 1
	return count


## Връща PawnState по pawn_id, или null.
func get_pawn(pawn_id: StringName) -> PawnState:
	for pawn in pawns:
		if pawn is PawnState and (pawn as PawnState).pawn_id == pawn_id:
			return pawn as PawnState
	return null


## Връща пионка по индекс 0..3, или null.
func get_pawn_by_index(index: int) -> PawnState:
	if index < 0 or index >= pawns.size():
		return null
	var pawn = pawns[index]
	if pawn is PawnState:
		return pawn as PawnState
	return null


func set_rank(p_rank: int) -> void:
	rank = p_rank


func clear_rank() -> void:
	rank = RANK_UNRANKED


## Добавя/обновява статус ефект по id. turns_remaining < 0 → 0.
func apply_status_effect(effect_id: StringName, turns_remaining: int = 0) -> void:
	var turns: int = turns_remaining if turns_remaining >= 0 else 0
	var id_str := String(effect_id)
	for i in status_effects.size():
		var entry = status_effects[i]
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id_str:
			var updated: Dictionary = (entry as Dictionary).duplicate(true)
			updated["id"] = id_str
			updated["turns_remaining"] = turns
			status_effects[i] = updated
			return
	status_effects.append({
		"id": id_str,
		"turns_remaining": turns,
	})


func clear_status_effects() -> void:
	status_effects.clear()


func has_status_effect(effect_id: StringName) -> bool:
	var id_str := String(effect_id)
	for entry in status_effects:
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id_str:
			return true
	return false


func remove_status_effect(effect_id: StringName) -> bool:
	var id_str := String(effect_id)
	for i in status_effects.size():
		var entry = status_effects[i]
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id_str:
			status_effects.remove_at(i)
			return true
	return false


## True ако полетата са в договорните self-contained граници (§4.1 / §12).
func is_valid() -> bool:
	if not PlayerId.is_valid(player_id):
		return false
	if seat != PlayerId.to_seat(player_id):
		return false
	if color == &"":
		return false
	if not _is_controller_type_valid(controller_type):
		return false
	if not AnimalId.is_valid(animal_id):
		return false
	if not _is_rank_valid(rank):
		return false
	if pawns.size() != PAWNS_PER_PLAYER:
		return false
	var seen_indices: Dictionary = {}
	for pawn in pawns:
		if not (pawn is PawnState):
			return false
		var ps := pawn as PawnState
		if not ps.is_valid():
			return false
		if ps.get_player_id() != player_id:
			return false
		var idx := ps.get_pawn_index()
		if seen_indices.has(idx):
			return false
		seen_indices[idx] = true
	if seen_indices.size() != PAWNS_PER_PLAYER:
		return false
	if not _are_status_effects_valid(status_effects):
		return false
	return true


## JSON-safe Dictionary: StringName → String, enum като int, вложени pawns/effects.
## Без Vector2 / NodePath — само стабилни идентификатори (§4.1).
func to_dict() -> Dictionary:
	var pawn_dicts: Array = []
	for pawn in pawns:
		if pawn is PawnState:
			pawn_dicts.append((pawn as PawnState).to_dict())
	return {
		"player_id": String(player_id),
		"seat": seat,
		"color": String(color),
		"controller_type": controller_type,
		"animal_id": String(animal_id),
		"pawns": pawn_dicts,
		"rank": rank,
		"status_effects": _duplicate_status_effects(status_effects),
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> PlayerState:
	var player := PlayerState.new()
	player.player_id = StringName(str(data.get("player_id", "")))
	player.seat = int(data.get("seat", -1))
	player.color = StringName(str(data.get("color", "")))
	player.controller_type = int(data.get(
			"controller_type", MatchConfig.ControllerType.HUMAN))
	player.animal_id = StringName(str(data.get("animal_id", AnimalId.DEFAULT)))
	player.rank = int(data.get("rank", RANK_UNRANKED))
	player.pawns.clear()
	for pd in data.get("pawns", []):
		if pd is Dictionary:
			player.pawns.append(PawnState.from_dict(pd))
	var effects = data.get("status_effects", [])
	if effects is Array:
		player.status_effects = _duplicate_status_effects(effects)
	else:
		player.status_effects = []
	return player


## Дълбоко копие през сериализация — без споделени референции към pawns/effects.
func duplicate_state() -> PlayerState:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат (вкл. вложени pawns).
func equals(other: PlayerState) -> bool:
	if other == null:
		return false
	if (player_id != other.player_id
			or seat != other.seat
			or color != other.color
			or controller_type != other.controller_type
			or animal_id != other.animal_id
			or rank != other.rank):
		return false
	if pawns.size() != other.pawns.size():
		return false
	for i in pawns.size():
		var a = pawns[i]
		var b = other.pawns[i]
		if not (a is PawnState) or not (b is PawnState):
			return false
		if not (a as PawnState).equals(b as PawnState):
			return false
	return _status_effects_equal(status_effects, other.status_effects)


static func _is_controller_type_valid(value: int) -> bool:
	return (value >= MatchConfig.ControllerType.HUMAN
			and value <= MatchConfig.ControllerType.REMOTE)


static func _is_rank_valid(value: int) -> bool:
	return value == RANK_UNRANKED or (value >= RANK_FIRST and value <= RANK_MAX)


static func _are_status_effects_valid(effects: Array) -> bool:
	for entry in effects:
		if not (entry is Dictionary):
			return false
		var d := entry as Dictionary
		if str(d.get("id", "")).is_empty():
			return false
		if int(d.get("turns_remaining", 0)) < 0:
			return false
	return true


static func _duplicate_status_effects(effects: Array) -> Array:
	var copy: Array = []
	for entry in effects:
		if entry is Dictionary:
			var d: Dictionary = (entry as Dictionary).duplicate(true)
			# Нормализирай ключовете към JSON-safe примитиви.
			copy.append({
				"id": str(d.get("id", "")),
				"turns_remaining": int(d.get("turns_remaining", 0)),
			})
	return copy


static func _status_effects_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not (a[i] is Dictionary) or not (b[i] is Dictionary):
			return false
		var da := a[i] as Dictionary
		var db := b[i] as Dictionary
		if str(da.get("id", "")) != str(db.get("id", "")):
			return false
		if int(da.get("turns_remaining", 0)) != int(db.get("turns_remaining", 0)):
			return false
	return true
