extends TestCase
## Unit тестове за SeededRandomSource.


func test_same_seed_produces_same_sequence() -> void:
	var rng1 := SeededRandomSource.new(777)
	var rng2 := SeededRandomSource.new(777)
	for _i in 20:
		assert_eq(rng1.next_int(1, 6), rng2.next_int(1, 6),
				"Same seed must produce identical sequence")


func test_different_seeds_produce_different_sequences() -> void:
	var rng1 := SeededRandomSource.new(1)
	var rng2 := SeededRandomSource.new(2)
	var same := true
	for _i in 20:
		if rng1.next_int(0, 1000) != rng2.next_int(0, 1000):
			same = false
			break
	assert_false(same, "Different seeds should produce different sequences")


func test_range_bounds_respected() -> void:
	var rng := SeededRandomSource.new(42)
	for _i in 100:
		var v := rng.next_int(1, 6)
		assert_true(v >= 1 and v <= 6, "Dice roll must be in [1, 6], got %d" % v)


func test_pick_returns_element_from_array() -> void:
	var rng := SeededRandomSource.new(99)
	var arr: Array = [10, 20, 30, 40]
	for _i in 50:
		var picked: int = rng.pick(arr)
		assert_true(picked in arr, "pick() must return element from array")


func test_state_save_restore() -> void:
	var rng := SeededRandomSource.new(555)
	for _i in 5:
		rng.next_int(0, 100)
	var saved := rng.get_state()

	var results_after_save: Array = []
	for _i in 10:
		results_after_save.append(rng.next_int(0, 1000))

	rng.set_state(saved)

	var results_after_restore: Array = []
	for _i in 10:
		results_after_restore.append(rng.next_int(0, 1000))

	assert_eq(results_after_save, results_after_restore,
			"Restored RNG must produce identical sequence")


func test_determinism_invariant() -> void:
	const SEED := 12345
	const ROLLS := 50
	var sequence_a: Array = []
	var sequence_b: Array = []

	var rng_a := SeededRandomSource.new(SEED)
	for _i in ROLLS:
		sequence_a.append(rng_a.next_int(1, 6))

	var rng_b := SeededRandomSource.new(SEED)
	for _i in ROLLS:
		sequence_b.append(rng_b.next_int(1, 6))

	assert_eq(sequence_a, sequence_b, "Determinism invariant: same seed → same output")
