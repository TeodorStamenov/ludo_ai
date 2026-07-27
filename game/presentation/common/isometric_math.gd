class_name IsometricMath
extends RefCounted
## Изометрична проекция grid → локални екранни координати
## (docs/V1_ARCHITECTURE.md §6.2 / §13.1).
##
## Извадена от BoardView (#147), за да може mapping-ът cell_id → позиция
## (#149) и други presentation потребители да ползват една и съща формула
## без да зависят от Node2D.
##
## Конвенция (като в прототипа):
##   - grid: Vector2i(col, row), център на дъската = (7, 7);
##   - локален origin е центърът на дъската (CENTER → Vector2.ZERO);
##   - scale мащабира tile размера (BoardView.board_scale).


const TILE_W: float = 136.0
const TILE_H: float = 97.0
const HALF_W: float = TILE_W / 2.0
const HALF_H: float = TILE_H / 2.0

## Grid координата, която се проектира в локален (0, 0).
const GRID_CENTER: Vector2i = Vector2i(7, 7)


## Преобразува grid клетка към локална изометрична позиция.
static func grid_to_local(grid_pos: Vector2i, scale: float = 1.0) -> Vector2:
	var rel_x: int = grid_pos.x - GRID_CENTER.x
	var rel_y: int = grid_pos.y - GRID_CENTER.y
	var sx: float = (rel_x - rel_y) * HALF_W * scale
	var sy: float = (rel_x + rel_y) * HALF_H * scale
	return Vector2(sx, sy)


## Ширина на tile при даден scale (за spacing на пионки и layout).
static func tile_display_width(scale: float = 1.0) -> float:
	return TILE_W * scale


## Височина на tile при даден scale.
static func tile_display_height(scale: float = 1.0) -> float:
	return TILE_H * scale


## Painter's algorithm z-index за изометрична клетка (по-далечните са отгоре).
static func z_index_for(grid_pos: Vector2i) -> int:
	return grid_pos.x + grid_pos.y
