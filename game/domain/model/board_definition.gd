class_name BoardDefinition
extends RefCounted
## Дефиниция на дъската като данни (docs/V1_ARCHITECTURE.md, §4.6).
##
## Една BoardDefinition обслужва 2/3/4 играчи чрез активни seats (MatchConfig).
## Геометрията е обща: cells + main_loop + player_definitions за четирите места.
## Маршрутът на играч = отрязък от main_loop (циклично от start до home_entry)
## + неговият home_stretch (виж build_player_route).
##
## Не носи тема/текстура — визуалът идва от BoardThemeDefinition.
## Валидацията (self-contained + съгласуваност cells/main_loop/players)
## е в BoardDefinitionValidator — is_valid() делегира към него.

## Подразбиращ се board_id — съвпада с MatchConfig.board_id по подразбиране.
const DEFAULT_BOARD_ID: StringName = &"classic_15x15"
## Размер на решетката (docs/V1_GAME_DESIGN.md §3.3) — делегира към CellId.
const BOARD_SIZE: int = 15
## Брой seat дефиниции на пълна дъска (винаги 4; активните seats са в MatchConfig).
const SEAT_COUNT: int = 4


## Стабилен идентификатор на дъската (напр. classic_15x15).
var board_id: StringName = DEFAULT_BOARD_ID
## Dictionary[cell_id: StringName, CellDefinition] — всички логически клетки.
var cells: Dictionary = {}
## Затворено общо трасе като наредени cell_id (без home stretch / base / center).
var main_loop: Array = []
## Периферни дефиниции за seats — типично SEAT_COUNT елемента.
var player_definitions: Array = []


## Фабрика за пълно конфигуриран BoardDefinition.
static func create(
		p_board_id: StringName,
		p_cells: Dictionary = {},
		p_main_loop: Array = [],
		p_player_definitions: Array = []
) -> BoardDefinition:
	var def := BoardDefinition.new()
	def.board_id = p_board_id
	def.set_cells(p_cells)
	def.set_main_loop(p_main_loop)
	def.set_player_definitions(p_player_definitions)
	return def


## Замества cells с копие; ключовете се нормализират към StringName.
## Стойностите трябва да са CellDefinition (или се пропускат).
func set_cells(p_cells: Dictionary) -> void:
	cells.clear()
	for key in p_cells.keys():
		var cell = p_cells[key]
		if cell is CellDefinition:
			var cell_def := cell as CellDefinition
			var cell_id := StringName(key)
			if cell_def.cell_id != &"":
				cell_id = cell_def.cell_id
			cells[cell_id] = cell_def


## Добавя / замества една клетка под нейния cell_id.
func put_cell(cell: CellDefinition) -> void:
	if cell == null:
		return
	cells[cell.cell_id] = cell


func set_main_loop(p_main_loop: Array) -> void:
	main_loop.clear()
	for cell in p_main_loop:
		main_loop.append(StringName(cell))


func set_player_definitions(p_defs: Array) -> void:
	player_definitions.clear()
	for item in p_defs:
		if item is PlayerBoardDefinition:
			player_definitions.append(item)


func cell_count() -> int:
	return cells.size()


func main_loop_length() -> int:
	return main_loop.size()


func player_definition_count() -> int:
	return player_definitions.size()


func has_cell(cell_id: StringName) -> bool:
	return cells.has(cell_id)


func get_cell(cell_id: StringName) -> CellDefinition:
	if not cells.has(cell_id):
		return null
	return cells[cell_id] as CellDefinition


## Клетка по изометрични grid координати, или null ако липсва / е извън BOARD_SIZE.
func get_cell_at_grid(col: int, row: int) -> CellDefinition:
	if col < 0 or col >= BOARD_SIZE or row < 0 or row >= BOARD_SIZE:
		return null
	return get_cell(CellId.from_grid(col, row))


func has_cell_at_grid(col: int, row: int) -> bool:
	return get_cell_at_grid(col, row) != null


## Независимо копие на main_loop като Array[StringName].
func get_main_loop() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cell in main_loop:
		ids.append(StringName(cell))
	return ids


func has_player_definition(player_id: StringName) -> bool:
	return get_player_definition(player_id) != null


## Връща PlayerBoardDefinition за seat-а, или null ако липсва.
func get_player_definition(player_id: StringName) -> PlayerBoardDefinition:
	for item in player_definitions:
		var def := item as PlayerBoardDefinition
		if def != null and def.player_id == player_id:
			return def
	return null


## Независимо копие на списъка с player definitions (референциите към defs остават).
func get_player_definitions() -> Array[PlayerBoardDefinition]:
	var result: Array[PlayerBoardDefinition] = []
	for item in player_definitions:
		var def := item as PlayerBoardDefinition
		if def != null:
			result.append(def)
	return result


## PlayerBoardDefinition за активните seats в реда на player_ids (Task #44–#46).
## Липсващ seat се пропуска — ползвай has_definitions_for_players за строга проверка.
## Дъската винаги държи SEAT_COUNT дефиниции; мачът активира 2/3/4 чрез MatchConfig.
func get_active_player_definitions(player_ids: Array) -> Array[PlayerBoardDefinition]:
	var result: Array[PlayerBoardDefinition] = []
	for pid in player_ids:
		var def := get_player_definition(StringName(pid))
		if def != null:
			result.append(def)
	return result


## True ако дъската има PlayerBoardDefinition за всеки от player_ids.
func has_definitions_for_players(player_ids: Array) -> bool:
	for pid in player_ids:
		if not has_player_definition(StringName(pid)):
			return false
	return player_ids.size() > 0


## Маршрут на играча: main_loop от start_loop_index до home_entry_loop_index
## (включително, циклично), последван от home_stretch[].
## При липсваща дефиниция или индекси извън main_loop → празен масив.
## Не включва CENTER — финалът е отделна логика (FinishRules).
func build_player_route(player_id: StringName) -> Array[StringName]:
	var route: Array[StringName] = []
	var player := get_player_definition(player_id)
	if player == null:
		return route
	var loop_len := main_loop.size()
	if loop_len == 0:
		return route
	var start: int = player.start_loop_index
	var home_entry: int = player.home_entry_loop_index
	if start < 0 or start >= loop_len:
		return route
	if home_entry < 0 or home_entry >= loop_len:
		return route
	var i: int = start
	while true:
		route.append(StringName(main_loop[i]))
		if i == home_entry:
			break
		i = (i + 1) % loop_len
		# Защита: ако home_entry никога не се срещне (не би трябвало при валидни индекси).
		if i == start:
			break
	for cell in player.home_stretch:
		route.append(StringName(cell))
	return route


## True ако дъската е в договорните граници (§4.6 / §3.3).
## Делегира към BoardDefinitionValidator — за подробности ползвай
## BoardDefinitionValidator.validate(self).
func is_valid() -> bool:
	return BoardDefinitionValidator.is_valid(self)


## JSON-safe Dictionary: StringName → String; вложените defs чрез to_dict().
func to_dict() -> Dictionary:
	var cells_dict: Dictionary = {}
	for key in cells.keys():
		var cell := cells[key] as CellDefinition
		if cell != null:
			cells_dict[String(key)] = cell.to_dict()
	var loop: Array = []
	for cell in main_loop:
		loop.append(String(cell))
	var players: Array = []
	for item in player_definitions:
		var def := item as PlayerBoardDefinition
		if def != null:
			players.append(def.to_dict())
	return {
		"board_id": String(board_id),
		"cells": cells_dict,
		"main_loop": loop,
		"player_definitions": players,
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> BoardDefinition:
	var def := BoardDefinition.new()
	def.board_id = StringName(str(data.get("board_id", DEFAULT_BOARD_ID)))
	var cells_data = data.get("cells", {})
	if cells_data is Dictionary:
		var loaded: Dictionary = {}
		for key in cells_data.keys():
			var entry = cells_data[key]
			if entry is Dictionary:
				var cell := CellDefinition.from_dict(entry)
				loaded[cell.cell_id] = cell
		def.set_cells(loaded)
	var loop_data = data.get("main_loop", [])
	if loop_data is Array:
		def.set_main_loop(loop_data)
	var players_data = data.get("player_definitions", [])
	if players_data is Array:
		var loaded_players: Array = []
		for entry in players_data:
			if entry is Dictionary:
				loaded_players.append(PlayerBoardDefinition.from_dict(entry))
			elif entry is PlayerBoardDefinition:
				loaded_players.append(entry)
		def.set_player_definitions(loaded_players)
	return def


## Дълбоко копие през сериализация — без споделени референции към cells/масиви.
func duplicate_definition() -> BoardDefinition:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: BoardDefinition) -> bool:
	if other == null:
		return false
	if board_id != other.board_id:
		return false
	if cells.size() != other.cells.size():
		return false
	for key in cells.keys():
		if not other.cells.has(key):
			return false
		var a := cells[key] as CellDefinition
		var b := other.cells[key] as CellDefinition
		if a == null or b == null or not a.equals(b):
			return false
	if not _string_name_arrays_equal(main_loop, other.main_loop):
		return false
	if player_definitions.size() != other.player_definitions.size():
		return false
	for i in player_definitions.size():
		var a := player_definitions[i] as PlayerBoardDefinition
		var b := other.player_definitions[i] as PlayerBoardDefinition
		if a == null or b == null or not a.equals(b):
			return false
	return true


static func _string_name_arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if StringName(a[i]) != StringName(b[i]):
			return false
	return true
