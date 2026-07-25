class_name PresentationRandomSource
extends RefCounted
## Отделен RNG за козметични вариации на анимации
## (docs/V1_ARCHITECTURE.md, §4.5).
##
## Замества глобалните randf() / randf_range() / randi_range() във views
## (DiceView, PawnView, GiftView и др.), без да пипа gameplay случайността.
##
## Инварианти:
##   - НЕ наследява RandomSource — нарочно, за да не може да се подаде към
##     GameEngine.validate_and_apply / MatchSession.
##   - НЕ се сериализира в GameState.rng_state и не влияе върху мача.
##   - Собствен RandomNumberGenerator — изолиран от SeededRandomSource.
##
## API е ориентирано към presentation нужди (float диапазони, chance),
## не към domain договора next_int/pick/get_state.


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## p_seed == 0 → randomize() (production козметика).
## Ненулев seed → детерминирана последователност (тестове / debug).
func _init(p_seed: int = 0) -> void:
	if p_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = p_seed


## Връща цяло число в затворения интервал [min_val, max_val].
func next_int(min_val: int, max_val: int) -> int:
	assert(min_val <= max_val,
			"PresentationRandomSource.next_int: min_val (%d) трябва да е <= max_val (%d)" % [
				min_val, max_val])
	return _rng.randi_range(min_val, max_val)


## Връща float в затворения интервал [min_val, max_val].
## Използва се за spin/wobble/jump вариации в анимации.
func next_float(min_val: float = 0.0, max_val: float = 1.0) -> float:
	assert(min_val <= max_val,
			"PresentationRandomSource.next_float: min_val (%s) трябва да е <= max_val (%s)" % [
				str(min_val), str(max_val)])
	return _rng.randf_range(min_val, max_val)


## Връща true с приблизителна вероятност probability ∈ [0.0, 1.0].
func chance(probability: float) -> bool:
	assert(probability >= 0.0 and probability <= 1.0,
			"PresentationRandomSource.chance: probability трябва да е в [0, 1], got %s" %
			str(probability))
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return _rng.randf() < probability


## Избира елемент от масива. Масивът не трябва да е празен.
func pick(array: Array) -> Variant:
	assert(not array.is_empty(), "PresentationRandomSource.pick() called on empty array")
	return array[next_int(0, array.size() - 1)]


## Текущият seed (за debug / тестове). Не е част от match snapshot.
func get_seed() -> int:
	return _rng.seed as int
