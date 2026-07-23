extends TestCase
## Симулационен тест: детерминистичен replay инвариант.
##
## Критичен инвариант (docs/V1_ARCHITECTURE.md, раздел 12):
##   Еднакъв seed + еднакви команди = еднакво GameState и еднакви DomainEvent-и.
##
## Тестовете използват DeterministicStubEngine — stub имплементация, която
## прилага командата и обновява RNG по детерминистичен начин, за да провери,
## че replay механизмът работи без нужда от пълна GameEngine имплементация.


class DeterministicStubEngine extends GameEngine:
	## Stub engine, която детерминистично консумира RNG при всяка команда.
	## Връща DiceRolled събитие с резултата от RNG.
	var call_count: int = 0

	func apply_command(state: GameState, _command: GameCommand, rng: RandomSource) -> Dictionary:
		call_count += 1
		var roll := rng.next_int(1, 6)
		var evt := DomainEvent.new()
		evt.event_type = &"DiceRolled"
		evt.command_sequence = call_count
		return {
			"accepted": true,
			"state": state,
			"events": [evt],
			"error": "",
			"_roll": roll,
		}


func _make_rng(seed_val: int) -> SeededRandomSource:
	return SeededRandomSource.new(seed_val)


func _run_sequence(engine: DeterministicStubEngine, rng: SeededRandomSource,
		state: GameState, n: int) -> Array:
	var results: Array = []
	for i in n:
		var cmd := RollDiceCommand.new(&"p1")
		cmd.sequence = i + 1
		var result := engine.apply_command(state, cmd, rng)
		results.append(result.get("_roll", 0))
	return results


func test_same_seed_produces_same_event_sequence() -> void:
	var state := GameState.new()
	var engine_a := DeterministicStubEngine.new()
	var engine_b := DeterministicStubEngine.new()
	var rng_a := _make_rng(12345)
	var rng_b := _make_rng(12345)

	var sequence_a := _run_sequence(engine_a, rng_a, state, 20)
	var sequence_b := _run_sequence(engine_b, rng_b, state, 20)

	assert_eq(sequence_a, sequence_b,
			"Еднакъв seed трябва да произведе идентична поредица от резултати")


func test_different_seeds_produce_different_sequences() -> void:
	var state := GameState.new()
	var engine_a := DeterministicStubEngine.new()
	var engine_b := DeterministicStubEngine.new()
	var rng_a := _make_rng(1)
	var rng_b := _make_rng(2)

	var seq_a := _run_sequence(engine_a, rng_a, state, 30)
	var seq_b := _run_sequence(engine_b, rng_b, state, 30)

	assert_ne(seq_a, seq_b,
			"Различни seedове трябва да произведат различни поредици")


func test_rng_state_save_and_restore_enables_replay() -> void:
	var rng := _make_rng(777)
	for _i in 10:
		rng.next_int(1, 6)

	var saved_state := rng.get_state()

	var part_a: Array = []
	for _i in 20:
		part_a.append(rng.next_int(1, 6))

	rng.set_state(saved_state)

	var part_b: Array = []
	for _i in 20:
		part_b.append(rng.next_int(1, 6))

	assert_eq(part_a, part_b,
			"Възстановен RNG state трябва да произведе идентична поредица")


func test_replay_from_same_initial_state_is_identical() -> void:
	var state := GameState.new()
	const SEED := 54321

	var rng1 := _make_rng(SEED)
	var rng2 := _make_rng(SEED)
	var initial_rng_state := rng1.get_state()

	rng1.set_state(initial_rng_state)
	rng2.set_state(initial_rng_state)

	var engine1 := DeterministicStubEngine.new()
	var engine2 := DeterministicStubEngine.new()

	var seq1 := _run_sequence(engine1, rng1, state, 15)
	var seq2 := _run_sequence(engine2, rng2, state, 15)

	assert_eq(seq1, seq2,
			"Replay от същото начално RNG state трябва да е идентичен")


func test_rng_state_dict_has_required_keys() -> void:
	var rng := _make_rng(42)
	var state := rng.get_state()
	assert_true(state.has("seed"), "RNG state трябва да съдържа 'seed'")
	assert_true(state.has("state"), "RNG state трябва да съдържа 'state'")


func test_engine_call_count_matches_command_count() -> void:
	var state := GameState.new()
	var engine := DeterministicStubEngine.new()
	var rng := _make_rng(1)
	_run_sequence(engine, rng, state, 7)
	assert_eq(engine.call_count, 7,
			"Engine трябва да е извикан точно толкова пъти, колкото команди")


func test_dice_rolls_in_valid_range_over_replay() -> void:
	var state := GameState.new()
	var engine := DeterministicStubEngine.new()
	var rng := _make_rng(999)
	var results := _run_sequence(engine, rng, state, 50)
	for roll in results:
		assert_true(roll >= 1 and roll <= 6,
				"Всеки резултат от зар трябва да е в [1, 6], получено: %d" % roll)
