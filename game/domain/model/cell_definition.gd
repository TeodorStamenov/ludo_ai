class_name CellDefinition
extends RefCounted
## Логическа дефиниция на една клетка от дъската (docs/V1_ARCHITECTURE.md, §4.6).
##
## Част от BoardDefinition.cells: Dictionary[cell_id, CellDefinition].
## Носи логически тип (CellType) и изометрични grid координати.
## Темата не е част от него — визуалът идва от BoardThemeDefinition.
##
## Domain ползва стабилни cell_id и целочислени col/row; screen Vector2 е
## само в presentation (BoardView).

## Стабилен идентификатор (CellId формат "c_{col}_{row}").
var cell_id: StringName = &""
## Логически тип: CellType.BASE | PATH | SPAWN | HOME | CENTER.
var cell_type: int = CellType.PATH
## Изометрична колона в 15×15 решетката (0–14). Съвпада с CellId.to_vec().x.
var grid_col: int = 0
## Изометричен ред в 15×15 решетката (0–14). Съвпада с CellId.to_vec().y.
var grid_row: int = 0


## Фабрика от grid координати — cell_id се извежда чрез CellId.from_grid.
static func create_from_grid(col: int, row: int, p_cell_type: int) -> CellDefinition:
	var cell := CellDefinition.new()
	cell.grid_col = col
	cell.grid_row = row
	cell.cell_type = p_cell_type
	if col >= 0 and col < CellId.BOARD_SIZE and row >= 0 and row < CellId.BOARD_SIZE:
		cell.cell_id = CellId.from_grid(col, row)
	else:
		cell.cell_id = &""
	return cell


## Фабрика от cell_id — grid координатите се извеждат чрез CellId.to_vec.
## При невалиден cell_id grid_col/grid_row остават -1.
static func create(p_cell_id: StringName, p_cell_type: int) -> CellDefinition:
	var cell := CellDefinition.new()
	cell.cell_id = p_cell_id
	cell.cell_type = p_cell_type
	var grid := CellId.to_vec(p_cell_id)
	cell.grid_col = grid.x
	cell.grid_row = grid.y
	return cell


## Vector2i(col, row) — същият формат, който ползва CellId / ludo_board.gd.
func grid_pos() -> Vector2i:
	return Vector2i(grid_col, grid_row)


func is_base() -> bool:
	return cell_type == CellType.BASE


func is_path() -> bool:
	return cell_type == CellType.PATH


func is_spawn() -> bool:
	return cell_type == CellType.SPAWN


func is_home() -> bool:
	return cell_type == CellType.HOME


func is_center() -> bool:
	return cell_type == CellType.CENTER


## True ако клетката е част от общото трасе (PATH или SPAWN).
## Подаръци и купчини живеят върху трасето; бази/home/център са изключени.
func is_on_main_track() -> bool:
	return cell_type == CellType.PATH or cell_type == CellType.SPAWN


## True ако cell_id, типът и grid координатите са валидни и съгласувани.
func is_valid() -> bool:
	if not CellId.is_valid(cell_id):
		return false
	if not CellType.is_valid(cell_type):
		return false
	if grid_col < 0 or grid_col >= CellId.BOARD_SIZE:
		return false
	if grid_row < 0 or grid_row >= CellId.BOARD_SIZE:
		return false
	if CellId.from_grid(grid_col, grid_row) != cell_id:
		return false
	if cell_type == CellType.CENTER and cell_id != CellId.CENTER:
		return false
	return true


## JSON-safe Dictionary: StringName → String, enum като int.
func to_dict() -> Dictionary:
	return {
		"cell_id": String(cell_id),
		"cell_type": cell_type,
		"grid_col": grid_col,
		"grid_row": grid_row,
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> CellDefinition:
	var cell := CellDefinition.new()
	cell.cell_id = StringName(str(data.get("cell_id", "")))
	cell.cell_type = int(data.get("cell_type", CellType.PATH))
	cell.grid_col = int(data.get("grid_col", 0))
	cell.grid_row = int(data.get("grid_row", 0))
	return cell


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_definition() -> CellDefinition:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: CellDefinition) -> bool:
	if other == null:
		return false
	return (cell_id == other.cell_id
			and cell_type == other.cell_type
			and grid_col == other.grid_col
			and grid_row == other.grid_row)
