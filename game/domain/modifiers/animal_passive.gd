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
## Пълната имплементация е обхваната от задача "Създаване на AnimalPassive интерфейс".


func modify_teleport_distance(base: int) -> int:
	return base

func modify_push_distance(base: int) -> int:
	return base

func modify_shield_duration(base: int) -> int:
	return base

func modify_gift_spawn_weight(base: float) -> float:
	return base
