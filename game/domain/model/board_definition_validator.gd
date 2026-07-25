class_name BoardDefinitionValidator
extends RefCounted
## Валидатор за BoardDefinition (docs/V1_ARCHITECTURE.md §4.6,
## docs/V1_GAME_DESIGN.md §3.2 / §3.3).
##
## Проверява self-contained инварианти и съгласуваност между cells,
## main_loop и player_definitions (spawn ∈ loop, типове, индекси ↔ клетки).
## Връща структуриран Result със стабилни error codes.
##
## BoardDefinition.is_valid() делегира тук. Domain-only: без Node / сцени.

## Стабилни кодове на грешки (сериализируеми / UI-friendly).
const ERR_NULL_BOARD := &"null_board"
const ERR_EMPTY_BOARD_ID := &"empty_board_id"
const ERR_EMPTY_CELLS := &"empty_cells"
const ERR_EMPTY_MAIN_LOOP := &"empty_main_loop"
const ERR_INVALID_SEAT_COUNT := &"invalid_seat_count"
const ERR_INVALID_CELL := &"invalid_cell"
const ERR_CELL_KEY_MISMATCH := &"cell_key_mismatch"
const ERR_INVALID_MAIN_LOOP_CELL := &"invalid_main_loop_cell"
const ERR_DUPLICATE_MAIN_LOOP_CELL := &"duplicate_main_loop_cell"
const ERR_MAIN_LOOP_CELL_MISSING := &"main_loop_cell_missing"
const ERR_MAIN_LOOP_CELL_TYPE := &"main_loop_cell_type"
const ERR_TRACK_CELL_NOT_IN_LOOP := &"track_cell_not_in_loop"
const ERR_INVALID_PLAYER_DEFINITION := &"invalid_player_definition"
const ERR_DUPLICATE_PLAYER_ID := &"duplicate_player_id"
const ERR_MISSING_PLAYER_ID := &"missing_player_id"
const ERR_SPAWN_NOT_IN_LOOP := &"spawn_not_in_loop"
const ERR_SPAWN_INDEX_MISMATCH := &"spawn_index_mismatch"
const ERR_LOOP_INDEX_OUT_OF_RANGE := &"loop_index_out_of_range"
const ERR_SPAWN_CELL_TYPE := &"spawn_cell_type"
const ERR_HOME_ENTRY_CELL_TYPE := &"home_entry_cell_type"
const ERR_HOME_CELL_MISSING := &"home_cell_missing"
const ERR_HOME_CELL_TYPE := &"home_cell_type"
const ERR_HOME_CELL_IN_LOOP := &"home_cell_in_loop"
const ERR_BASE_CELL_MISSING := &"base_cell_missing"
const ERR_BASE_CELL_TYPE := &"base_cell_type"
const ERR_BASE_CELL_IN_LOOP := &"base_cell_in_loop"
const ERR_SHARED_SPAWN_CELL := &"shared_spawn_cell"
const ERR_SHARED_HOME_CELL := &"shared_home_cell"
const ERR_SHARED_BASE_CELL := &"shared_base_cell"
const ERR_ORPHAN_SPAWN_CELL := &"orphan_spawn_cell"
const ERR_ORPHAN_HOME_CELL := &"orphan_home_cell"
const ERR_ORPHAN_BASE_CELL := &"orphan_base_cell"
const ERR_MISSING_CENTER := &"missing_center"
const ERR_DUPLICATE_CENTER := &"duplicate_center"
const ERR_CENTER_IN_LOOP := &"center_in_loop"


## Резултат от валидация: ok + наредени error codes (+ съобщения за дебъг).
class Result extends RefCounted:
	var ok: bool = true
	var error_codes: Array[StringName] = []
	var error_messages: Array[String] = []

	func is_ok() -> bool:
		return ok

	func is_invalid() -> bool:
		return not ok

	func has_error(code: StringName) -> bool:
		return error_codes.has(code)

	func first_error_code() -> StringName:
		if error_codes.is_empty():
			return &""
		return error_codes[0]

	func first_error_message() -> String:
		if error_messages.is_empty():
			return ""
		return error_messages[0]

	func add_error(code: StringName, message: String) -> void:
		ok = false
		error_codes.append(code)
		error_messages.append(message)


## True ако board минава всички договорни проверки.
static func is_valid(board: BoardDefinition) -> bool:
	return validate(board).ok


## Пълна валидация — събира всички открити грешки (не спира на първата).
static func validate(board: BoardDefinition) -> Result:
	var result := Result.new()
	if board == null:
		result.add_error(ERR_NULL_BOARD, "BoardDefinition е null")
		return result

	_validate_board_id(board, result)
	_validate_cells_structure(board, result)
	_validate_main_loop_structure(board, result)
	_validate_player_definitions_structure(board, result)
	_validate_main_loop_consistency(board, result)
	_validate_center(board, result)
	_validate_player_consistency(board, result)
	_validate_cell_ownership(board, result)
	return result


static func _validate_board_id(board: BoardDefinition, result: Result) -> void:
	if board.board_id == &"" or String(board.board_id).is_empty():
		result.add_error(ERR_EMPTY_BOARD_ID, "board_id не може да е празен")


static func _validate_cells_structure(board: BoardDefinition, result: Result) -> void:
	if board.cells.is_empty():
		result.add_error(ERR_EMPTY_CELLS, "cells не може да е празен")
		return
	for key in board.cells.keys():
		var cell_id := StringName(key)
		var cell := board.cells[key] as CellDefinition
		if cell == null or not cell.is_valid():
			result.add_error(ERR_INVALID_CELL,
					"невалидна клетка '%s'" % String(cell_id))
			continue
		if cell.cell_id != cell_id:
			result.add_error(ERR_CELL_KEY_MISMATCH,
					"ключ '%s' ≠ cell_id '%s'" % [String(cell_id), String(cell.cell_id)])


static func _validate_main_loop_structure(board: BoardDefinition, result: Result) -> void:
	if board.main_loop.is_empty():
		result.add_error(ERR_EMPTY_MAIN_LOOP, "main_loop не може да е празен")
		return
	var seen: Dictionary = {}
	for cell in board.main_loop:
		var cell_id := StringName(cell)
		if not CellId.is_valid(cell_id):
			result.add_error(ERR_INVALID_MAIN_LOOP_CELL,
					"невалиден cell_id в main_loop: '%s'" % String(cell_id))
			continue
		if seen.has(cell_id):
			result.add_error(ERR_DUPLICATE_MAIN_LOOP_CELL,
					"дублиран cell_id в main_loop: '%s'" % String(cell_id))
		else:
			seen[cell_id] = true


static func _validate_player_definitions_structure(
		board: BoardDefinition, result: Result
) -> void:
	if board.player_definitions.size() != BoardDefinition.SEAT_COUNT:
		result.add_error(ERR_INVALID_SEAT_COUNT,
				"брой player_definitions %d ≠ %d" % [
					board.player_definitions.size(), BoardDefinition.SEAT_COUNT])

	var seen_players: Dictionary = {}
	for item in board.player_definitions:
		var def := item as PlayerBoardDefinition
		if def == null or not def.is_valid():
			var pid := &""
			if def != null:
				pid = def.player_id
			result.add_error(ERR_INVALID_PLAYER_DEFINITION,
					"невалидна PlayerBoardDefinition '%s'" % String(pid))
			continue
		if seen_players.has(def.player_id):
			result.add_error(ERR_DUPLICATE_PLAYER_ID,
					"дублиран player_id '%s'" % String(def.player_id))
		else:
			seen_players[def.player_id] = true

	for player_id in PlayerId.ALL:
		if not seen_players.has(player_id):
			result.add_error(ERR_MISSING_PLAYER_ID,
					"липсва PlayerBoardDefinition за '%s'" % String(player_id))


static func _validate_main_loop_consistency(
		board: BoardDefinition, result: Result
) -> void:
	if board.main_loop.is_empty() or board.cells.is_empty():
		return

	var loop_set: Dictionary = {}
	for cell in board.main_loop:
		var cell_id := StringName(cell)
		loop_set[cell_id] = true
		var cell_def := board.get_cell(cell_id)
		if cell_def == null:
			result.add_error(ERR_MAIN_LOOP_CELL_MISSING,
					"main_loop клетка '%s' липсва в cells" % String(cell_id))
			continue
		if not cell_def.is_on_main_track():
			result.add_error(ERR_MAIN_LOOP_CELL_TYPE,
					"main_loop клетка '%s' трябва да е PATH или SPAWN" % String(cell_id))

	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell == null:
			continue
		if cell.is_on_main_track() and not loop_set.has(cell.cell_id):
			result.add_error(ERR_TRACK_CELL_NOT_IN_LOOP,
					"PATH|SPAWN клетка '%s' липсва в main_loop" % String(cell.cell_id))


static func _validate_center(board: BoardDefinition, result: Result) -> void:
	var center_count: int = 0
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell != null and cell.is_center():
			center_count += 1
	if center_count == 0:
		result.add_error(ERR_MISSING_CENTER, "липсва CENTER клетка")
	elif center_count > 1:
		result.add_error(ERR_DUPLICATE_CENTER,
				"очаква се точно 1 CENTER, намерени %d" % center_count)

	if board.has_cell(CellId.CENTER):
		for cell in board.main_loop:
			if StringName(cell) == CellId.CENTER:
				result.add_error(ERR_CENTER_IN_LOOP,
						"CENTER не може да е в main_loop")
				break


static func _validate_player_consistency(
		board: BoardDefinition, result: Result
) -> void:
	var loop_len := board.main_loop.size()
	var loop_set: Dictionary = {}
	for cell in board.main_loop:
		loop_set[StringName(cell)] = true

	for item in board.player_definitions:
		var def := item as PlayerBoardDefinition
		if def == null:
			continue
		var pid := String(def.player_id)

		if loop_len > 0:
			if def.start_loop_index < 0 or def.start_loop_index >= loop_len:
				result.add_error(ERR_LOOP_INDEX_OUT_OF_RANGE,
						"%s start_loop_index %d извън [0, %d)" % [
							pid, def.start_loop_index, loop_len])
			if def.home_entry_loop_index < 0 or def.home_entry_loop_index >= loop_len:
				result.add_error(ERR_LOOP_INDEX_OUT_OF_RANGE,
						"%s home_entry_loop_index %d извън [0, %d)" % [
							pid, def.home_entry_loop_index, loop_len])

		if not loop_set.has(def.spawn_cell):
			result.add_error(ERR_SPAWN_NOT_IN_LOOP,
					"%s spawn_cell '%s' не е в main_loop" % [pid, String(def.spawn_cell)])
		elif (
				def.start_loop_index >= 0
				and def.start_loop_index < loop_len
				and StringName(board.main_loop[def.start_loop_index]) != def.spawn_cell
		):
			result.add_error(ERR_SPAWN_INDEX_MISMATCH,
					"%s main_loop[%d] ≠ spawn_cell '%s'" % [
						pid, def.start_loop_index, String(def.spawn_cell)])

		var spawn_def := board.get_cell(def.spawn_cell)
		if spawn_def != null and not spawn_def.is_spawn():
			result.add_error(ERR_SPAWN_CELL_TYPE,
					"%s spawn_cell '%s' трябва да е CellType.SPAWN" % [
						pid, String(def.spawn_cell)])

		if (
				def.home_entry_loop_index >= 0
				and def.home_entry_loop_index < loop_len
		):
			var entry_id := StringName(board.main_loop[def.home_entry_loop_index])
			var entry_def := board.get_cell(entry_id)
			if entry_def != null and not entry_def.is_on_main_track():
				result.add_error(ERR_HOME_ENTRY_CELL_TYPE,
						"%s home_entry '%s' трябва да е PATH или SPAWN" % [
							pid, String(entry_id)])

		for home in def.home_stretch:
			var home_id := StringName(home)
			var home_def := board.get_cell(home_id)
			if home_def == null:
				result.add_error(ERR_HOME_CELL_MISSING,
						"%s home_stretch клетка '%s' липсва в cells" % [
							pid, String(home_id)])
			elif not home_def.is_home():
				result.add_error(ERR_HOME_CELL_TYPE,
						"%s home_stretch клетка '%s' трябва да е HOME" % [
							pid, String(home_id)])
			if loop_set.has(home_id):
				result.add_error(ERR_HOME_CELL_IN_LOOP,
						"%s home_stretch клетка '%s' не може да е в main_loop" % [
							pid, String(home_id)])

		for base in def.base_cells:
			var base_id := StringName(base)
			var base_def := board.get_cell(base_id)
			if base_def == null:
				result.add_error(ERR_BASE_CELL_MISSING,
						"%s base_cells клетка '%s' липсва в cells" % [
							pid, String(base_id)])
			elif not base_def.is_base():
				result.add_error(ERR_BASE_CELL_TYPE,
						"%s base_cells клетка '%s' трябва да е BASE" % [
							pid, String(base_id)])
			if loop_set.has(base_id):
				result.add_error(ERR_BASE_CELL_IN_LOOP,
						"%s base_cells клетка '%s' не може да е в main_loop" % [
							pid, String(base_id)])


static func _validate_cell_ownership(
		board: BoardDefinition, result: Result
) -> void:
	var spawn_owners: Dictionary = {}
	var home_owners: Dictionary = {}
	var base_owners: Dictionary = {}

	for item in board.player_definitions:
		var def := item as PlayerBoardDefinition
		if def == null:
			continue
		var pid := String(def.player_id)

		if spawn_owners.has(def.spawn_cell):
			result.add_error(ERR_SHARED_SPAWN_CELL,
					"spawn_cell '%s' е споделен между seats" % String(def.spawn_cell))
		else:
			spawn_owners[def.spawn_cell] = def.player_id

		for home in def.home_stretch:
			var home_id := StringName(home)
			if home_owners.has(home_id):
				result.add_error(ERR_SHARED_HOME_CELL,
						"HOME клетка '%s' е споделена (вкл. %s)" % [
							String(home_id), pid])
			else:
				home_owners[home_id] = def.player_id

		for base in def.base_cells:
			var base_id := StringName(base)
			if base_owners.has(base_id):
				result.add_error(ERR_SHARED_BASE_CELL,
						"BASE клетка '%s' е споделена (вкл. %s)" % [
							String(base_id), pid])
			else:
				base_owners[base_id] = def.player_id

	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		if cell == null:
			continue
		if cell.is_spawn() and not spawn_owners.has(cell.cell_id):
			result.add_error(ERR_ORPHAN_SPAWN_CELL,
					"SPAWN клетка '%s' няма seat собственик" % String(cell.cell_id))
		if cell.is_home() and not home_owners.has(cell.cell_id):
			result.add_error(ERR_ORPHAN_HOME_CELL,
					"HOME клетка '%s' няма seat собственик" % String(cell.cell_id))
		if cell.is_base() and not base_owners.has(cell.cell_id):
			result.add_error(ERR_ORPHAN_BASE_CELL,
					"BASE клетка '%s' няма seat собственик" % String(cell.cell_id))
