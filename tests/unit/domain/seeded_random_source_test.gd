class_name SeededRandomSourceTest
extends TestCase
## Unit тестове за SeededRandomSource (Task #30 / docs/V1_ARCHITECTURE.md §4.5).
##
## Покрива:
##   - Domain слой: extends RefCounted (през RandomSource), път game/domain/rng/.
##   - Договорните методи next_int / pick / get_state / set_state.
##   - Детерминизъм: еднакъв seed → еднаква последователност.
##   - Save/restore: get_state → set_state продължава същия поток.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_seeded_random_source_extends_ref_counted() -> void:
	var rng := SeededRandomSource.new(1)
	assert_true(rng is RefCounted,
			"SeededRandomSource трябва да extends RefCounted (през RandomSource)")


func test_seeded_random_source_is_not_node() -> void:
	var rng: Object = SeededRandomSource.new(1)
	assert_false(rng is Node,
			"SeededRandomSource не трябва да extends Node — domain слой е без сцени")


func test_seeded_random_source_extends_random_source() -> void:
	var rng := SeededRandomSource.new(1)
	assert_true(rng is RandomSource,
			"SeededRandomSource трябва да наследява RandomSource")


func test_seeded_random_source_script_path_is_in_domain_rng() -> void:
	var rng := SeededRandomSource.new(1)
	var path: String = rng.get_script().resource_path
	assert_true(path.contains("game/domain/rng/"),
			"SeededRandomSource трябва да е в game/domain/rng/")


# ── Договор: next_int ─────────────────────────────────────────────────────────

func test_next_int_respects_closed_interval() -> void:
	var rng := SeededRandomSource.new(42)
	for _i in 100:
		var v := rng.next_int(1, 6)
		assert_true(v >= 1 and v <= 6,
				"next_int(1, 6) трябва да е в [1, 6], got %d" % v)


func test_next_int_when_min_equals_max() -> void:
	var rng := SeededRandomSource.new(7)
	for _i in 10:
		assert_eq(rng.next_int(4, 4), 4,
				"next_int(n, n) трябва да върне n")


func test_next_int_same_seed_produces_same_sequence() -> void:
	var rng1 := SeededRandomSource.new(777)
	var rng2 := SeededRandomSource.new(777)
	for _i in 20:
		assert_eq(rng1.next_int(1, 6), rng2.next_int(1, 6),
				"Еднакъв seed трябва да дава идентична next_int последователност")


func test_next_int_different_seeds_diverge() -> void:
	var rng1 := SeededRandomSource.new(1)
	var rng2 := SeededRandomSource.new(2)
	var same := true
	for _i in 20:
		if rng1.next_int(0, 1000) != rng2.next_int(0, 1000):
			same = false
			break
	assert_false(same,
			"Различни seed-ове трябва да дават различни последователности")


# ── Договор: pick ─────────────────────────────────────────────────────────────

func test_pick_returns_element_from_array() -> void:
	var rng := SeededRandomSource.new(99)
	var arr: Array = [10, 20, 30, 40]
	for _i in 50:
		var picked: Variant = rng.pick(arr)
		assert_true(picked in arr,
				"pick() трябва да връща елемент от масива")


func test_pick_single_element_array() -> void:
	var rng := SeededRandomSource.new(3)
	assert_eq(rng.pick([&"only"]), &"only",
			"pick върху едноелементен масив трябва да върне единствения елемент")


func test_pick_same_seed_produces_same_sequence() -> void:
	var arr: Array = ["a", "b", "c", "d"]
	var rng1 := SeededRandomSource.new(314)
	var rng2 := SeededRandomSource.new(314)
	for _i in 20:
		assert_eq(rng1.pick(arr), rng2.pick(arr),
				"Еднакъв seed трябва да дава идентична pick последователност")


# ── Договор: get_state / set_state ────────────────────────────────────────────

func test_get_state_contains_seed_and_state() -> void:
	var rng := SeededRandomSource.new(555)
	var state := rng.get_state()
	assert_true(state is Dictionary, "get_state трябва да връща Dictionary")
	assert_true(state.has("seed"), "get_state трябва да съдържа ключ 'seed'")
	assert_true(state.has("state"), "get_state трябва да съдържа ключ 'state'")
	assert_eq(state["seed"], "555",
			"get_state().seed трябва да е String с конструкторния seed")


func test_state_save_restore_continues_same_sequence() -> void:
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
			"Възстановеният RNG трябва да продължи със същата последователност")


func test_set_state_on_fresh_instance_matches_original() -> void:
	var original := SeededRandomSource.new(12345)
	for _i in 8:
		original.next_int(1, 6)
	var snapshot := original.get_state()

	var expected: Array = []
	for _i in 15:
		expected.append(original.next_int(1, 6))

	var restored := SeededRandomSource.new(0)
	restored.set_state(snapshot)
	var actual: Array = []
	for _i in 15:
		actual.append(restored.next_int(1, 6))

	assert_eq(actual, expected,
			"set_state върху нова инстанция трябва да възпроизведе същия поток")


# ── Детерминизъм (архитектурен инвариант) ─────────────────────────────────────

func test_determinism_invariant_same_seed_same_output() -> void:
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

	assert_eq(sequence_a, sequence_b,
			"Инвариант: еднакъв seed → еднакъв изход")


func test_mixed_next_int_and_pick_are_deterministic() -> void:
	var arr: Array = [1, 2, 3]
	var rng_a := SeededRandomSource.new(2026)
	var rng_b := SeededRandomSource.new(2026)
	var seq_a: Array = []
	var seq_b: Array = []
	for _i in 10:
		seq_a.append(rng_a.next_int(1, 6))
		seq_a.append(rng_a.pick(arr))
		seq_b.append(rng_b.next_int(1, 6))
		seq_b.append(rng_b.pick(arr))
	assert_eq(seq_a, seq_b,
			"Смесен next_int/pick поток трябва да е детерминиран при еднакъв seed")
