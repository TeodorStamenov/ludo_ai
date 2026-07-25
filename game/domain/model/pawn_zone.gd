class_name PawnZone
extends RefCounted
## Enum за зоните, в които може да се намира дадена пионка (docs/V1_ARCHITECTURE.md, §4.1).
##
## Всяка пионка е точно в една зона по всяко време — инвариант, проверяван в §12.
##
## Ред на прогресия: BASE → MAIN_PATH → HOME_STRETCH → FINISHED
##
##   BASE         — пионката е в базата и не участва в играта.
##   MAIN_PATH    — пионката е на общото трасе (може да бъде взета/атакувана).
##   HOME_STRETCH — пионката е в собствената финална колона (недостъпна за противници).
##   FINISHED     — пионката е прибрана в центъра; играчът не я ходи повече.

enum {
	BASE         = 0,
	MAIN_PATH    = 1,
	HOME_STRETCH = 2,
	FINISHED     = 3,
}

## Брой валидни зони.
const COUNT: int = 4

## Всички зони в ред по прогресия (BASE → FINISHED).
const ALL: Array[int] = [BASE, MAIN_PATH, HOME_STRETCH, FINISHED]


## Връща true ако zone е валидна стойност (0–3).
static func is_valid(zone: int) -> bool:
	return zone >= BASE and zone <= FINISHED


## Връща стабилния StringName идентификатор на зоната за сериализация и дебъг.
## При невалидна стойност връща &"UNKNOWN".
static func zone_name(zone: int) -> StringName:
	match zone:
		BASE:         return &"BASE"
		MAIN_PATH:    return &"MAIN_PATH"
		HOME_STRETCH: return &"HOME_STRETCH"
		FINISHED:     return &"FINISHED"
		_:            return &"UNKNOWN"
