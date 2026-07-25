class_name AIDifficulty
extends RefCounted
## Нива на трудност за AI контролер (docs/V1_GAME_DESIGN.md §6,
## docs/V1_ARCHITECTURE.md §5.1: seats[].ai_difficulty?).
##
##   EASY   — квази-случаен избор от legal_actions.
##   MEDIUM — базова евристика върху същите legal_actions.
##   HARD   — оценява ходове (взимане, бягство, подарък, купчина, прибиране).
##
## ai_difficulty е задължителен само когато controller_type == AI.
## Domain само дефинира нивата; конкретните AIPolicy живеят в application/ai/.

enum {
	EASY   = 0,  ## Квази-случаен AI.
	MEDIUM = 1,  ## Базова евристика.
	HARD   = 2,  ## Пълна оценка на ходовете.
}

## Брой валидни нива на трудност.
const COUNT: int = 3

## Всички нива в ред от лесно към трудно.
const ALL: Array[int] = [EASY, MEDIUM, HARD]


## Връща true ако difficulty е валидна стойност (0–2).
static func is_valid(difficulty: int) -> bool:
	return difficulty >= EASY and difficulty <= HARD


## Връща стабилния StringName идентификатор за сериализация и дебъг.
## При невалидна стойност връща &"UNKNOWN".
static func difficulty_name(difficulty: int) -> StringName:
	match difficulty:
		EASY:   return &"EASY"
		MEDIUM: return &"MEDIUM"
		HARD:   return &"HARD"
		_:      return &"UNKNOWN"
