class_name SeededRandomSource
extends RandomSource
## Детерминирана production имплементация на RandomSource
## (docs/V1_ARCHITECTURE.md, §4.5).
##
## Еднакъв seed + еднакви извиквания = еднаква последователност.
## Това е критичен инвариант за replay, save/restore, debug и бъдещ
## authoritative сървър (еднакъв seed + еднакви команди = еднакво
## GameState и DomainEvent-и).
##
## Вътрешно ползва Godot RandomNumberGenerator, изолиран в Domain —
## GameEngine никога не създава собствен RNG.
##
## get_state() / set_state() сериализират seed + вътрешен state, за да
## може MatchSession snapshot да възстанови точно същата последователност.


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	_rng.seed = p_seed


## Връща цяло число в затворения интервал [min_val, max_val].
func next_int(min_val: int, max_val: int) -> int:
	assert(min_val <= max_val,
			"SeededRandomSource.next_int: min_val (%d) трябва да е <= max_val (%d)" % [
				min_val, max_val])
	return _rng.randi_range(min_val, max_val)


## Избира елемент от масива. Масивът не трябва да е празен.
func pick(array: Array) -> Variant:
	assert(not array.is_empty(), "SeededRandomSource.pick() called on empty array")
	return array[next_int(0, array.size() - 1)]


## Връща сериализируемо представяне на текущото вътрешно RNG състояние.
## Ключове: "seed" (начален seed) и "state" (текуща позиция в потока).
func get_state() -> Dictionary:
	return {
		"seed": _rng.seed,
		"state": _rng.state,
	}


## Възстановява RNG от предишно записано get_state().
## Важно: seed се задава преди state — задаването на seed нулира state.
func set_state(state: Dictionary) -> void:
	_rng.seed = int(state.get("seed", 0))
	_rng.state = int(state.get("state", 0))
