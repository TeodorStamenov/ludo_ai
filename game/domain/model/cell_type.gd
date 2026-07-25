class_name CellType
extends RefCounted
## Логически тип на клетка от дъската (docs/V1_ARCHITECTURE.md, §4.6).
##
## CellDefinition носи един от тези типове. Темата/текстурата не участват тук —
## BoardThemeDefinition мапва cell_type → визуални данни в presentation.
##
##   BASE   — клетка от базата на играч (2×2 старт зона).
##   PATH   — клетка от общото трасе (main loop).
##   SPAWN  — входна клетка на играч върху трасето (след излизане от база).
##   HOME   — клетка от финалната колона (home stretch) на играч.
##   CENTER — централната цел (CellId.CENTER); крайна точка на маршрута.

enum {
	BASE   = 0,
	PATH   = 1,
	SPAWN  = 2,
	HOME   = 3,
	CENTER = 4,
}

## Брой валидни типове.
const COUNT: int = 5

## Всички типове в ред на изброяване.
const ALL: Array[int] = [BASE, PATH, SPAWN, HOME, CENTER]


## Връща true ако cell_type е валидна стойност (0–4).
static func is_valid(cell_type: int) -> bool:
	return cell_type >= BASE and cell_type <= CENTER


## Връща стабилния StringName идентификатор за сериализация и дебъг.
## При невалидна стойност връща &"UNKNOWN".
static func type_name(cell_type: int) -> StringName:
	match cell_type:
		BASE:   return &"BASE"
		PATH:   return &"PATH"
		SPAWN:  return &"SPAWN"
		HOME:   return &"HOME"
		CENTER: return &"CENTER"
		_:      return &"UNKNOWN"
