class_name AnimalPassive
extends RefCounted
## Интерфейс за пасивно умение на животно (docs/V1_ARCHITECTURE.md, раздел 4.8).
##
## Пасивите са дребни числови модификатори върху съществуващи механики;
## никога не въвеждат нови системи или game loops.
##
## Модификуеми параметри (docs/V1_ARCHITECTURE.md, раздел 4.8):
##   modify_teleport_distance(base: int) -> int
##   modify_push_distance(base: int) -> int
##   modify_shield_duration(base: int) -> int
##   modify_gift_spawn_weight(base: float) -> float
##
## AI не се нуждае от специална логика за пасивите — те са числови
## модификатори в самата игрова логика, еднакви за Human и AI.
##
## Базовият клас връща стойностите непроменени (identity) — конкретните
## животни extend-ват този клас и override-ват само хуковете, които им трябват
## (напр. AnimalDefinition.passive_script, content/animals/README.md; #223).


func modify_teleport_distance(base: int) -> int:
	return base

func modify_push_distance(base: int) -> int:
	return base

func modify_shield_duration(base: int) -> int:
	return base

func modify_gift_spawn_weight(base: float) -> float:
	return base
