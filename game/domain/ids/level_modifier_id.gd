class_name LevelModifierId
extends RefCounted
## Стабилни идентификатори за кампанийни level modifiers
## (docs/V1_GAME_DESIGN.md §5.1, content/campaign/levels/: modifiers[],
## docs/V1_ARCHITECTURE.md §5.1: level_modifiers[]).
##
## MatchConfig.level_modifiers носи списък от тези ID-та. Модификаторите
## променят параметри на мача (напр. честота на подаръци), не визуализацията.
##
## v1 стартов каталог: gifts_double_frequency („подаръците се появяват
## двойно по-често"). Допълнителни модификатори се добавят тук при нужда.

## Подаръците се появяват двойно по-често (docs/V1_GAME_DESIGN.md §5.1,
## content/campaign/levels/README.md).
const GIFTS_DOUBLE_FREQUENCY: StringName = &"gifts_double_frequency"

## Всички v1 level_modifier id.
const ALL: Array[StringName] = [GIFTS_DOUBLE_FREQUENCY]

## Брой известни level modifiers във v1.
const COUNT: int = 1


## Връща true ако id е един от валидните v1 level_modifier id.
static func is_valid(id: StringName) -> bool:
	return id == GIFTS_DOUBLE_FREQUENCY
