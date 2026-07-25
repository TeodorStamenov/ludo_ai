class_name CellId
extends RefCounted
## Стабилни идентификатори за клетките на 15×15 изометричната дъска.
##
## Форматът е "c_{col}_{row}" за позиции в решетката, където col и row са в [0, 14].
## Пример: CellId.from_grid(8, 2) → &"c_8_2" (spawn клетката на GREEN).
##
## Конвенцията за координати следва ludo_board.gd и Godot Vector2i: x=col, y=row.
##
## Presentation преобразува cell_id → изометрична Vector2 (screen position).
## Domain никога не използва Vector2, NodePath или editor-generated имена.
##
## Заетите клетки на classic_15x15 носят конкретни стойности чрез
## Classic15x15Board.all_cell_ids() (Task #38) — схемата тук е обща за всяка
## валидна grid позиция; board factory-то избира кои ID-та са логически клетки.
##
## Специална константа CENTER — единствената именувана клетка, защото е
## логически особена (финална цел), не защото е изключение от схемата.

## Префикс на формата — отличава cell_id от player_id / pawn_id / match_id.
const PREFIX: String = "c_"

## Брой колони и редове в дъската.
const BOARD_SIZE: int = 15

## Централна клетка — финалната цел (col=7, row=7).
const CENTER: StringName = &"c_7_7"


## Генерира cell_id от колона и ред (0-базирано, [0, BOARD_SIZE)).
## Пример: from_grid(8, 2) → &"c_8_2"
static func from_grid(col: int, row: int) -> StringName:
	assert(col >= 0 and col < BOARD_SIZE,
			"col must be 0–%d, got %d" % [BOARD_SIZE - 1, col])
	assert(row >= 0 and row < BOARD_SIZE,
			"row must be 0–%d, got %d" % [BOARD_SIZE - 1, row])
	return StringName("%s%d_%d" % [PREFIX, col, row])


## Удобен вариант — приема Vector2i(col, row), какъвто ползва ludo_board.gd.
## Пример: from_vec(Vector2i(7, 7)) → CellId.CENTER
static func from_vec(grid_pos: Vector2i) -> StringName:
	return from_grid(grid_pos.x, grid_pos.y)


## Разпарсва cell_id и връща Vector2i(col, row).
## При невалиден формат или стойности извън [0, BOARD_SIZE) → Vector2i(-1, -1).
static func to_vec(cell_id: StringName) -> Vector2i:
	var s: String = cell_id
	if not s.begins_with(PREFIX):
		return Vector2i(-1, -1)
	var parts := s.substr(PREFIX.length()).split("_")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	var col: int = parts[0].to_int()
	var row: int = parts[1].to_int()
	if col < 0 or col >= BOARD_SIZE or row < 0 or row >= BOARD_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


## Проверява дали cell_id е валидно: правилен формат и в границите на дъската.
static func is_valid(cell_id: StringName) -> bool:
	var v := to_vec(cell_id)
	return v.x >= 0 and v.y >= 0


## True ако cell_id е централната цел.
static func is_center(cell_id: StringName) -> bool:
	return cell_id == CENTER
