class_name PigPassive
extends AnimalPassive
## Пасив на Прасето (content/animals/README.md) — подаръци се появяват
## по-често в близост до нея.
##
## modify_gift_spawn_weight(base: float) не носи cell-context (само базовото
## тегло) — точна позиционна "близост" не е представима с текущия hook
## signature, затова пасивът увеличава общото spawn тегло за играча ѝ.
## GiftRules все още не консултира ModifierPipeline при избора на клетка
## (content/animals/README.md; #223) — класът е изолиран, тестван градивен
## елемент, wiring-ът в GiftRules е отделна задача.

const SPAWN_WEIGHT_MULTIPLIER := 1.5


func modify_gift_spawn_weight(base: float) -> float:
	return base * SPAWN_WEIGHT_MULTIPLIER
