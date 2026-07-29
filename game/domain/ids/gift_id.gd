class_name GiftId
extends RefCounted
## Стабилни идентификатори за активни подаръци върху дъската
## (docs/V1_ARCHITECTURE.md, §4.1 gifts[], GiftSpawnedEvent).
##
## Формат: "g_{command_sequence}", напр. &"g_11". Изведен от
## command_sequence-а на приетата команда, породила spawn-а — не от wall-clock
## (§12: state hash / replay трябва да са напълно детерминирани от seed +
## commands; всеки accepted command спавва най-много един подарък, затова
## command_sequence гарантира уникалност в рамките на мача).
##
## Съдържанието на подаръка НЕ е част от ID-то — тегли се чрез RNG при взимане
## (docs/V1_ARCHITECTURE.md §4.7; docs/V1_GAME_DESIGN.md §4.1–4.2).

## Префикс на формата — отличава gift_id от другите domain идентификатори.
const PREFIX: String = "g_"


## Генерира gift_id, детерминиран от command_sequence-а на spawn-ващата команда.
static func generate(command_sequence: int) -> StringName:
	return StringName("%s%d" % [PREFIX, command_sequence])


## Проверява дали стойността изглежда като генериран gift_id (префикс "g_").
static func is_valid(id: StringName) -> bool:
	return (id as String).begins_with(PREFIX)
