class_name RandomSource
extends RefCounted
## Интерфейс за инжектируем детерминиран RNG (docs/V1_ARCHITECTURE.md, раздел 4.5).
##
## Domain получава RandomSource отвън — никога не създава собствен RandomNumberGenerator.
## Това прави целия gameplay детерминиран и тестируем без Godot сцена.
##
## Един seed от MatchConfig управлява:
##   - зар;
##   - интервали и клетки за подаръци;
##   - съдържание на подаръци;
##   - случайни параметри на power-up.
##
## Козметичните вариации на анимации използват отделен presentation RNG
## и не минават оттук.
##
## Имплементации:
##   - SeededRandomSource  — production (rng/seeded_random_source.gd)
##   - [stub за тестове]   — фиксирани стойности при unit тестване
##
## Пълната имплементация е обхваната от задача
## "Създаване на интерфейс RandomSource".


## Връща произволно цяло число в затворения интервал [min_val, max_val].
func next_int(min_val: int, max_val: int) -> int:
	return min_val  # override в имплементацията


## Избира произволен елемент от масива. Масивът не трябва да е празен.
func pick(array: Array) -> Variant:
	return array[0]  # override в имплементацията


## Връща сериализируемо представяне на текущото вътрешно RNG състояние.
func get_state() -> Dictionary:
	return {}  # override в имплементацията


## Възстановява RNG от предишно записано get_state().
func set_state(state: Dictionary) -> void:
	pass  # override в имплементацията
