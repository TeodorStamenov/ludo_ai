class_name GiftId
extends RefCounted
## Стабилни идентификатори за активни подаръци върху дъската
## (docs/V1_ARCHITECTURE.md §4.1 gifts[], GiftSpawnedEvent).
##
## Формат: "g_{ticks_msec}_{counter}", напр. &"g_1721915400000_3".
## Префиксът "g_" го отличава от match_id ("m_"), player_id, pawn_id и cell_id.
##
## Съдържанието на подаръка НЕ е част от ID-то — тегли се чрез RNG при взимане
## (docs/V1_ARCHITECTURE.md §4.7; docs/V1_GAME_DESIGN.md §4.1–4.2).

## Префикс на формата — отличава gift_id от другите domain идентификатори.
const PREFIX: String = "g_"

## Монотонен брояч — нараства само напред за уникалност в рамките на сесията.
static var _counter: int = 0


## Генерира уникален gift_id.
## Гарантирано различен от всеки предишен ID в рамките на едно изпълнение.
static func generate() -> StringName:
	var ts: int = Time.get_ticks_msec()
	var id := StringName("%s%d_%d" % [PREFIX, ts, _counter])
	_counter += 1
	return id


## Нулира вътрешния брояч. Използва се само в тестове за детерминизъм.
## В production код не се извиква.
static func _reset_counter_for_tests() -> void:
	_counter = 0


## Проверява дали стойността изглежда като генериран gift_id (префикс "g_").
static func is_valid(id: StringName) -> bool:
	return (id as String).begins_with(PREFIX)
