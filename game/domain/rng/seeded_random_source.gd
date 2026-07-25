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
## Export / restore (issue #31):
##   get_state() → JSON-safe Dictionary {"seed", "state"} като String —
##   независимо копие за GameState.rng_state / MatchSession.to_snapshot().
##   String encoding е задължителен: JSON number е IEEE-754 double и губи
##   точност за 64-bit RandomNumberGenerator.state (над 2^53).
##   set_state(dict) ← приема String / int (и float за малки стойности).


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


## Експортира текущото RNG състояние като JSON-safe Dictionary.
## Ключове: "seed" и "state" — String, за да оцелеят 64-bit стойности през JSON.
## Връщаното копие е независимо — мутацията му не влияе на RNG.
func get_state() -> Dictionary:
	return {
		"seed": str(_rng.seed),
		"state": str(_rng.state),
	}


## Възстановява RNG от payload, върнат от get_state() (или JSON round-trip).
## Важно: seed се задава преди state — задаването на seed нулира state в Godot.
func set_state(state: Dictionary) -> void:
	assert(state.has("seed"),
			"SeededRandomSource.set_state: липсва задължителен ключ 'seed'")
	assert(state.has("state"),
			"SeededRandomSource.set_state: липсва задължителен ключ 'state'")
	_rng.seed = _coerce_int(state["seed"])
	_rng.state = _coerce_int(state["state"])


## Нормализира seed/state от String (JSON-safe export), int или float.
static func _coerce_int(value: Variant) -> int:
	match typeof(value):
		TYPE_STRING:
			return (value as String).to_int()
		TYPE_INT:
			return value as int
		TYPE_FLOAT:
			return int(value)
		_:
			return int(value)
