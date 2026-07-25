class_name MatchPhase
extends RefCounted
## Enum за фазите на мача на ниво GameState.phase (docs/V1_ARCHITECTURE.md, §4.1).
##
## Тези фази описват общото състояние на мача, а не вътрешното
## разпределение на хода (вж. TurnPhase).
##
## Ред на прогресия: SETUP → IN_PROGRESS → FINISHED
##
##   SETUP       — MatchConfig е получен; играчи и дъска се инициализират;
##                 мачът още не е стартиран.
##   IN_PROGRESS — Мачът е активен; ходовете се изпълняват.
##   FINISHED    — Всички места са определени; MatchSession произвежда MatchSummary.

enum {
	SETUP       = 0,
	IN_PROGRESS = 1,
	FINISHED    = 2,
}

## Брой валидни фази.
const COUNT: int = 3

## Всички фази в ред по прогресия (SETUP → FINISHED).
const ALL: Array[int] = [SETUP, IN_PROGRESS, FINISHED]


## Връща true ако phase е валидна стойност (0–2).
static func is_valid(phase: int) -> bool:
	return phase >= SETUP and phase <= FINISHED


## Връща стабилния StringName идентификатор на фазата за сериализация и дебъг.
## При невалидна стойност връща &"UNKNOWN".
static func phase_name(phase: int) -> StringName:
	match phase:
		SETUP:       return &"SETUP"
		IN_PROGRESS: return &"IN_PROGRESS"
		FINISHED:    return &"FINISHED"
		_:           return &"UNKNOWN"
