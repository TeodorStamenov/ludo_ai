extends TestCase
## Симулационен тест: устойчивост на RNG и domain инварианти при много мачове.
##
## Симулира хиляди последователни команди с детерминистичен stub engine,
## за да провери:
##   - RNG остава детерминистичен при дълги поредици.
##   - Резултатите от зар са в [1, 6] без изключения.
##   - Много последователни match seed-ове произвеждат различни резултати.
##   - Последователността не дрейфва при reset и повторение.
##
## Не изисква пълна GameEngine имплементация — тестовете са валидни дори
## когато GameEngine е stub.


const MATCH_COUNT := 100
const COMMANDS_PER_MATCH := 50


class SimStubEngine extends GameEngine:
	func apply_command(state: GameState, _cmd: GameCommand, rng: RandomSource) -> Dictionary:
		var roll := rng.next_int(1, 6)
		var evt := DomainEvent.new()
		evt.event_type = &"DiceRolled"
		return {
			"accepted": true,
			"state": state,
			"events": [evt],
			"error": "",
			"roll": roll,
		}


func _simulate_match(seed_val: int, n_commands: int) -> Array:
	var rng := SeededRandomSource.new(seed_val)
	var state := GameState.new()
	var engine := SimStubEngine.new()
	var rolls: Array = []
	for i in n_commands:
		var cmd := RollDiceCommand.new(&"p1")
		cmd.sequence = i + 1
		var result := engine.apply_command(state, cmd, rng)
		rolls.append(result.get("roll", 0))
	return rolls


func test_all_rolls_in_valid_range_over_many_matches() -> void:
	for m in MATCH_COUNT:
		var rolls := _simulate_match(m * 137 + 1, COMMANDS_PER_MATCH)
		for roll in rolls:
			if roll < 1 or roll > 6:
				assert_true(false,
						"Match %d: невалиден зар %d — трябва да е в [1, 6]" % [m, roll])
				return


func test_different_match_seeds_produce_different_sequences() -> void:
	var sequences: Dictionary = {}
	var collisions := 0
	for m in 50:
		var seed_val := m * 1000 + 42
		var rolls := _simulate_match(seed_val, 10)
		var key := str(rolls)
		if key in sequences:
			collisions += 1
		else:
			sequences[key] = seed_val
	assert_true(collisions < 5,
			"Различните seedове трябва да произведат различни поредици (collisions: %d)" % collisions)


func test_same_seed_is_stable_across_repeated_simulation() -> void:
	const SEED := 42424242
	var run1 := _simulate_match(SEED, COMMANDS_PER_MATCH)
	var run2 := _simulate_match(SEED, COMMANDS_PER_MATCH)
	assert_eq(run1, run2,
			"Повторна симулация с еднакъв seed трябва да даде идентичен резултат")


func test_rng_reset_between_matches_produces_independent_results() -> void:
	var results_first_match := _simulate_match(1, 20)
	var results_second_match := _simulate_match(2, 20)
	assert_ne(results_first_match, results_second_match,
			"Последователните мачове с различни seedове не трябва да са еднакви")


func test_rng_state_restoration_mid_sequence() -> void:
	var rng := SeededRandomSource.new(55555)
	for _i in 25:
		rng.next_int(1, 6)
	var checkpoint := rng.get_state()

	var from_checkpoint: Array = []
	for _i in 30:
		from_checkpoint.append(rng.next_int(1, 6))

	rng.set_state(checkpoint)
	var replayed: Array = []
	for _i in 30:
		replayed.append(rng.next_int(1, 6))

	assert_eq(from_checkpoint, replayed,
			"Повторното изпълнение от checkpoint трябва да е идентично")


func test_total_roll_distribution_roughly_uniform() -> void:
	var counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
	var total := 0
	for m in 20:
		var rolls := _simulate_match(m * 31 + 7, 100)
		for roll in rolls:
			counts[roll] = counts.get(roll, 0) + 1
			total += 1

	var expected_avg := total / 6
	for face in counts:
		var count: int = counts[face]
		var deviation := absi(count - expected_avg)
		assert_true(deviation < expected_avg * 0.5,
				"Лицето %d: %d поява при очаквани ~%d (отклонение %d%%)" % [
					face, count, expected_avg,
					int(100.0 * deviation / expected_avg)])


func test_simulation_engine_accepted_is_always_true() -> void:
	var engine := SimStubEngine.new()
	var state := GameState.new()
	var rng := SeededRandomSource.new(1)
	for i in 100:
		var cmd := RollDiceCommand.new(&"p1")
		cmd.sequence = i + 1
		var result := engine.apply_command(state, cmd, rng)
		assert_true(result.get("accepted", false),
				"Stub engine трябва да приема всяка команда")
