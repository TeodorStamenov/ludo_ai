class_name RandomSource
extends RefCounted
## Интерфейс за инжектируем детерминиран RNG (docs/V1_ARCHITECTURE.md, §4.5).
##
## Domain получава RandomSource отвън — никога не създава собствен
## RandomNumberGenerator. Това прави gameplay детерминиран и тестируем
## без Godot сцена.
##
## Договор:
##   next_int(min, max) — цяло число в затворения интервал [min, max]
##   pick(array)        — елемент от непразен масив
##   get_state()        — сериализируемо вътрешно състояние
##   set_state(state)   — възстановяване от get_state()
##
## Един seed от MatchConfig управлява:
##   - зар;
##   - интервали и клетки за подаръци;
##   - съдържание на подаръци;
##   - случайни параметри на power-up.
##
## Козметичните вариации на анимации ползват отделен presentation RNG
## и не минават оттук.
##
## Базовите методи са фиксиран test double (винаги min / първи елемент),
## удобен за unit тестове на правила без случайност.
##
## Production имплементация: SeededRandomSource (rng/seeded_random_source.gd).


## Връща цяло число в затворения интервал [min_val, max_val].
## Базовата имплементация винаги връща min_val (фиксиран test double).
func next_int(min_val: int, max_val: int) -> int:
	assert(min_val <= max_val,
			"RandomSource.next_int: min_val (%d) трябва да е <= max_val (%d)" % [
				min_val, max_val])
	return min_val


## Избира елемент от масива. Масивът не трябва да е празен.
## Базовата имплементация винаги връща първия елемент (фиксиран test double).
func pick(array: Array) -> Variant:
	assert(not array.is_empty(), "RandomSource.pick() called on empty array")
	return array[0]


## Връща сериализируемо представяне на текущото вътрешно RNG състояние.
## Базовата имплементация няма състояние.
func get_state() -> Dictionary:
	return {}


## Възстановява RNG от предишно записано get_state().
## Базовата имплементация е no-op.
func set_state(_state: Dictionary) -> void:
	pass
