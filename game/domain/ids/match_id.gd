class_name MatchId
extends RefCounted
## Генератор на стабилни идентификатори за мачове.
##
## В v1 ID-тата са local-only: msec timestamp + монотонен брояч.
## В v2 се заменят от авторитативни server-side UUID-та без промяна на договора
## (GameCommand и GameState ще носят същото поле match_id: StringName).
##
## Формат: "m_{ticks_msec}_{counter}", напр. &"m_1721915400000_3".
## Префиксът "m_" го отличава от player_id (&"yellow") и pawn_id (&"yellow_0").
##
## Гаранция: в рамките на едно изпълнение всяко извикване на generate() дава
## различен ID (монотонен брояч). Уникалност между изпълнения е осигурена от
## timestamp, но не е гарантирана при много бързо рестартиране.

## Монотонен брояч — нараства само напред за уникалност в рамките на сесията.
static var _counter: int = 0


## Генерира уникален match_id.
## Гарантирано различен от всеки предишен ID в рамките на едно изпълнение.
static func generate() -> StringName:
	var ts: int = Time.get_ticks_msec()
	var id := StringName("m_%d_%d" % [ts, _counter])
	_counter += 1
	return id


## Нулира вътрешния брояч. Използва се само в тестове за детерминизъм.
## В production код не се извиква.
static func _reset_counter_for_tests() -> void:
	_counter = 0


## Проверява дали стойността изглежда като генериран match_id (префикс "m_").
static func is_valid(id: StringName) -> bool:
	return (id as String).begins_with("m_")
