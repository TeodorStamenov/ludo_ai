class_name PlayerBoardDefinition
extends RefCounted
## Периферна дефиниция на един seat върху дъската (docs/V1_ARCHITECTURE.md, §4.6).
##
## Част от BoardDefinition.player_definitions: Array[PlayerBoardDefinition].
## Носи spawn, индекси в общия main_loop, home stretch и base клетките
## за един PlayerId. Маршрутът на играча = main_loop[start..] + home_stretch.
##
## Не носи тема/текстура — визуалът идва от BoardThemeDefinition.
## Валидация спрямо main_loop/cells живее в BoardDefinition валидатора;
## is_valid() проверява само self-contained инварианти.

## Документирана дължина на финалната зона (docs/V1_GAME_DESIGN.md §3.2 / §3.3).
const HOME_STRETCH_LENGTH: int = 4
## Брой базови клетки / пионки на seat (docs/V1_GAME_DESIGN.md §3.1).
const BASE_CELL_COUNT: int = 4
## Подразбираща се / невалидна стойност за loop индекси.
const INVALID_LOOP_INDEX: int = -1


## Seat, за който важи тази дефиниция (PlayerId).
var player_id: StringName = &""
## Клетка за излизане от базата при зар 6 (CellId на SPAWN).
var spawn_cell: StringName = &""
## Индекс в BoardDefinition.main_loop, откъдето започва маршрутът (обикновено spawn).
var start_loop_index: int = INVALID_LOOP_INDEX
## Индекс в main_loop, откъдето пионката влиза в home_stretch (последна PATH преди HOME).
var home_entry_loop_index: int = INVALID_LOOP_INDEX
## Последователните HOME клетки към центъра (точно HOME_STRETCH_LENGTH).
var home_stretch: Array = []
## Четирите BASE клетки на seat-а (точно BASE_CELL_COUNT).
var base_cells: Array = []


## Фабрика за пълно конфигуриран PlayerBoardDefinition.
static func create(
		p_player_id: StringName,
		p_spawn_cell: StringName,
		p_start_loop_index: int,
		p_home_entry_loop_index: int,
		p_home_stretch: Array = [],
		p_base_cells: Array = []
) -> PlayerBoardDefinition:
	var def := PlayerBoardDefinition.new()
	def.player_id = p_player_id
	def.spawn_cell = p_spawn_cell
	def.start_loop_index = p_start_loop_index
	def.home_entry_loop_index = p_home_entry_loop_index
	def.set_home_stretch(p_home_stretch)
	def.set_base_cells(p_base_cells)
	return def


## Замества home_stretch[] с нормализирани CellId стойности.
func set_home_stretch(cells: Array) -> void:
	home_stretch.clear()
	for cell in cells:
		home_stretch.append(StringName(cell))


## Замества base_cells[] с нормализирани CellId стойности.
func set_base_cells(cells: Array) -> void:
	base_cells.clear()
	for cell in cells:
		base_cells.append(StringName(cell))


func get_home_stretch() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cell in home_stretch:
		ids.append(StringName(cell))
	return ids


func get_base_cells() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cell in base_cells:
		ids.append(StringName(cell))
	return ids


func home_stretch_length() -> int:
	return home_stretch.size()


func base_cell_count() -> int:
	return base_cells.size()


func is_spawn(cell_id: StringName) -> bool:
	return cell_id == spawn_cell


func contains_home_cell(cell_id: StringName) -> bool:
	for cell in home_stretch:
		if StringName(cell) == cell_id:
			return true
	return false


func contains_base_cell(cell_id: StringName) -> bool:
	for cell in base_cells:
		if StringName(cell) == cell_id:
			return true
	return false


## Индекс на клетката в home_stretch, или -1 ако не е част от него.
func home_stretch_index(cell_id: StringName) -> int:
	for i in home_stretch.size():
		if StringName(home_stretch[i]) == cell_id:
			return i
	return -1


## True ако player_id, spawn, индексите и клетъчните масиви са в договорните граници.
## Не проверява съгласуваност с BoardDefinition.main_loop / cells — това е за валидатора.
func is_valid() -> bool:
	if not PlayerId.is_valid(player_id):
		return false
	if not CellId.is_valid(spawn_cell):
		return false
	if start_loop_index < 0:
		return false
	if home_entry_loop_index < 0:
		return false
	if home_stretch.size() != HOME_STRETCH_LENGTH:
		return false
	if base_cells.size() != BASE_CELL_COUNT:
		return false
	if not _cell_array_valid(home_stretch):
		return false
	if not _cell_array_valid(base_cells):
		return false
	# Spawn е върху общото трасе — не в базата и не в home stretch.
	if contains_home_cell(spawn_cell) or contains_base_cell(spawn_cell):
		return false
	# База и home stretch не се припокриват.
	for cell in base_cells:
		if contains_home_cell(StringName(cell)):
			return false
	return true


static func _cell_array_valid(cells: Array) -> bool:
	var seen: Dictionary = {}
	for cell in cells:
		var cell_id := StringName(cell)
		if not CellId.is_valid(cell_id):
			return false
		if seen.has(cell_id):
			return false
		seen[cell_id] = true
	return true


## JSON-safe Dictionary: StringName → String, масивите са независими копия.
func to_dict() -> Dictionary:
	var stretch: Array = []
	for cell in home_stretch:
		stretch.append(String(cell))
	var bases: Array = []
	for cell in base_cells:
		bases.append(String(cell))
	return {
		"player_id": String(player_id),
		"spawn_cell": String(spawn_cell),
		"start_loop_index": start_loop_index,
		"home_entry_loop_index": home_entry_loop_index,
		"home_stretch": stretch,
		"base_cells": bases,
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> PlayerBoardDefinition:
	var def := PlayerBoardDefinition.new()
	def.player_id = StringName(str(data.get("player_id", "")))
	def.spawn_cell = StringName(str(data.get("spawn_cell", "")))
	def.start_loop_index = int(data.get("start_loop_index", INVALID_LOOP_INDEX))
	def.home_entry_loop_index = int(data.get("home_entry_loop_index", INVALID_LOOP_INDEX))
	var stretch = data.get("home_stretch", [])
	if stretch is Array:
		def.set_home_stretch(stretch)
	var bases = data.get("base_cells", [])
	if bases is Array:
		def.set_base_cells(bases)
	return def


## Дълбоко копие през сериализация — без споделена референция към масивите.
func duplicate_definition() -> PlayerBoardDefinition:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: PlayerBoardDefinition) -> bool:
	if other == null:
		return false
	return (player_id == other.player_id
			and spawn_cell == other.spawn_cell
			and start_loop_index == other.start_loop_index
			and home_entry_loop_index == other.home_entry_loop_index
			and _string_name_arrays_equal(home_stretch, other.home_stretch)
			and _string_name_arrays_equal(base_cells, other.base_cells))


static func _string_name_arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if StringName(a[i]) != StringName(b[i]):
			return false
	return true
