class_name SeededRandomSource
extends RandomSource
## Детерминиран RNG с начален seed (docs/V1_ARCHITECTURE.md, раздел 4.5).
##
## Еднакъв seed + еднакви команди = еднакво GameState и еднакви DomainEvent-и.
## Това е критичен инвариант за replay, debug и бъдещ authoritative сървър.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	_rng.seed = p_seed


func next_int(min_val: int, max_val: int) -> int:
	return _rng.randi_range(min_val, max_val)


func pick(array: Array) -> Variant:
	assert(not array.is_empty(), "SeededRandomSource.pick() called on empty array")
	return array[_rng.randi() % array.size()]


func get_state() -> Dictionary:
	return {
		"seed": _rng.seed,
		"state": _rng.state,
	}


func set_state(state: Dictionary) -> void:
	_rng.seed = state.get("seed", 0)
	_rng.state = state.get("state", 0)
