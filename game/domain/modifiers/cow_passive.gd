class_name CowPassive
extends AnimalPassive
## Пасив на Кравата (content/animals/README.md) — когато противник я избутва
## (PUSH power-up), тя отстъпва само 1 клетка вместо базовото разстояние
## (в момента 2, PushEffect.BASE_DISTANCE).
##
## Приложимо само когато Кравата е ЦЕЛТА на PUSH, не triggering играча.
## PushEffect.resolve() в момента консултира само triggering player-а
## (context.modifiers), не target-а — push_effect.gd го документира изрично:
## "target-ово намаление изисква отделен modifiers за target-а, извън обхвата
## на #211". Класът тук е готовият, тестван градивен елемент; wiring на
## target-side modifiers в PushEffect остава отделна задача.

const MAX_PUSH_DISTANCE_AS_TARGET := 1


func modify_push_distance(base: int) -> int:
	return mini(base, MAX_PUSH_DISTANCE_AS_TARGET)
