class_name CellPositionMap
extends RefCounted
## Mapping cell_id → локална изометрична позиция
## (docs/V1_ARCHITECTURE.md §4.1 / §6.2).
##
## Domain пази само стабилни cell_id; Presentation преобразува към Vector2.
## Ползва CellId + IsometricMath — без зависимост от Node2D / сцени.
##
## Предкомпютра 15×15 решетката при даден scale; lookup е O(1).


## cell_id (StringName) → Vector2 локална позиция спрямо центъра на дъската.
var _positions: Dictionary = {}


func _init(scale: float = 1.0) -> void:
	rebuild(scale)


## Преизгражда целия 15×15 mapping при нов scale.
func rebuild(scale: float = 1.0) -> void:
	_positions.clear()
	for row: int in CellId.BOARD_SIZE:
		for col: int in CellId.BOARD_SIZE:
			var cell_id: StringName = CellId.from_grid(col, row)
			_positions[cell_id] = IsometricMath.grid_to_local(
					Vector2i(col, row), scale)


## Локална изометрична позиция за cell_id, или Vector2.ZERO при невалиден id.
func position_of(cell_id: StringName) -> Vector2:
	if _positions.has(cell_id):
		return _positions[cell_id] as Vector2
	return Vector2.ZERO


## True ако cell_id е в mapping-а (валидна grid клетка).
func has_cell(cell_id: StringName) -> bool:
	return _positions.has(cell_id)


## Painter's algorithm z-index за клетката, или 0 при невалиден id.
func z_index_of(cell_id: StringName) -> int:
	var grid: Vector2i = CellId.to_vec(cell_id)
	if grid.x < 0:
		return 0
	return IsometricMath.z_index_for(grid)


## One-shot без инстанция — за потребители, които не пазят map.
static func to_local(cell_id: StringName, scale: float = 1.0) -> Vector2:
	var grid: Vector2i = CellId.to_vec(cell_id)
	if grid.x < 0:
		return Vector2.ZERO
	return IsometricMath.grid_to_local(grid, scale)
