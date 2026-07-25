class_name TurnPhase
extends RefCounted
## Enum за фазите на хода — изрична state machine на TurnState
## (docs/V1_ARCHITECTURE.md, §4.2).
##
## Машината следва този ред:
##
##   MATCH_START
##     → AWAITING_ROLL
##     → AWAITING_MOVE
##     → RESOLVING_MOVE
##     → RESOLVING_POWER_UP   (само ако пионката е стъпила на подарък)
##     → TURN_END
##     → AWAITING_ROLL        (следващ играч)
##     → …
##     → MATCH_FINISHED
##
##   MATCH_START      — начална фаза преди първия ход; мачът е стартиран,
##                      но никой играч още не е хвърлял.
##   AWAITING_ROLL    — очаква RollDiceCommand от активния играч.
##   AWAITING_MOVE    — зарът е хвърлен; очаква MovePawnCommand.
##   RESOLVING_MOVE   — ходът на пионката се обработва; нови DomainEvent се излъчват.
##   RESOLVING_POWER_UP — power-up ефект се изпълнява след взимане на подарък.
##   TURN_END         — ходът приключи; GameEngine определя следващия активен играч.
##   MATCH_FINISHED   — всички места са определени; мачът е завършен.

enum {
	MATCH_START        = 0,
	AWAITING_ROLL      = 1,
	AWAITING_MOVE      = 2,
	RESOLVING_MOVE     = 3,
	RESOLVING_POWER_UP = 4,
	TURN_END           = 5,
	MATCH_FINISHED     = 6,
}

## Брой валидни фази.
const COUNT: int = 7

## Всички фази в ред по прогресия.
const ALL: Array[int] = [
	MATCH_START,
	AWAITING_ROLL,
	AWAITING_MOVE,
	RESOLVING_MOVE,
	RESOLVING_POWER_UP,
	TURN_END,
	MATCH_FINISHED,
]

## Фази, в които активният играч може да изпрати команда.
const COMMAND_ACCEPTING: Array[int] = [AWAITING_ROLL, AWAITING_MOVE]


## Връща true ако phase е валидна стойност (0–6).
static func is_valid(phase: int) -> bool:
	return phase >= MATCH_START and phase <= MATCH_FINISHED


## Връща true ако в тази фаза се очаква команда от играча.
static func accepts_command(phase: int) -> bool:
	return phase in COMMAND_ACCEPTING


## Връща stабилния StringName идентификатор на фазата за сериализация и дебъг.
## При невалидна стойност връща &"UNKNOWN".
static func phase_name(phase: int) -> StringName:
	match phase:
		MATCH_START:        return &"MATCH_START"
		AWAITING_ROLL:      return &"AWAITING_ROLL"
		AWAITING_MOVE:      return &"AWAITING_MOVE"
		RESOLVING_MOVE:     return &"RESOLVING_MOVE"
		RESOLVING_POWER_UP: return &"RESOLVING_POWER_UP"
		TURN_END:           return &"TURN_END"
		MATCH_FINISHED:     return &"MATCH_FINISHED"
		_:                  return &"UNKNOWN"
