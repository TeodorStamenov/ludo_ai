class_name RandomSourceTest
extends TestCase
## Unit тестове за интерфейса RandomSource (Task #29 / docs/V1_ARCHITECTURE.md §4.5).
##
## Покрива:
##   - Domain слой: extends RefCounted, път game/domain/rng/.
##   - Договорните методи next_int / pick / get_state / set_state.
##   - Фиксираното поведение на базовия клас като test double.
##   - Полиморфизъм: SeededRandomSource е RandomSource.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_random_source_extends_ref_counted() -> void:
	var rng := RandomSource.new()
	assert_true(rng is RefCounted,
			"RandomSource трябва да extends RefCounted")


func test_random_source_is_not_node() -> void:
	var rng: Object = RandomSource.new()
	assert_false(rng is Node,
			"RandomSource не трябва да extends Node — domain слой е без сцени")


func test_random_source_script_path_is_in_domain_rng() -> void:
	var rng := RandomSource.new()
	var path: String = rng.get_script().resource_path
	assert_true(path.contains("game/domain/rng/"),
			"RandomSource трябва да е в game/domain/rng/")


# ── Договор: next_int ─────────────────────────────────────────────────────────

func test_next_int_returns_min_as_fixed_double() -> void:
	var rng := RandomSource.new()
	assert_eq(rng.next_int(1, 6), 1,
			"Базовият RandomSource трябва винаги да връща min_val")
	assert_eq(rng.next_int(3, 10), 3,
			"Базовият RandomSource трябва винаги да връща min_val")


func test_next_int_when_min_equals_max() -> void:
	var rng := RandomSource.new()
	assert_eq(rng.next_int(4, 4), 4,
			"next_int(n, n) трябва да върне n")


func test_next_int_is_stable_across_calls() -> void:
	var rng := RandomSource.new()
	var values: Array = []
	for _i in 20:
		values.append(rng.next_int(2, 9))
	for v in values:
		assert_eq(v, 2,
				"Фиксираният test double трябва да е стабилен при многократни извиквания")


# ── Договор: pick ─────────────────────────────────────────────────────────────

func test_pick_returns_first_element_as_fixed_double() -> void:
	var rng := RandomSource.new()
	var arr: Array = [10, 20, 30]
	assert_eq(rng.pick(arr), 10,
			"Базовият RandomSource.pick трябва винаги да връща първия елемент")


func test_pick_single_element_array() -> void:
	var rng := RandomSource.new()
	assert_eq(rng.pick([&"only"]), &"only",
			"pick върху едноелементен масив трябва да върне единствения елемент")


func test_pick_is_stable_across_calls() -> void:
	var rng := RandomSource.new()
	var arr: Array = ["a", "b", "c"]
	for _i in 10:
		assert_eq(rng.pick(arr), "a",
				"Фиксираният test double трябва винаги да връща първия елемент")


# ── Договор: get_state / set_state ────────────────────────────────────────────

func test_get_state_returns_empty_dictionary() -> void:
	var rng := RandomSource.new()
	var state := rng.get_state()
	assert_true(state is Dictionary, "get_state трябва да връща Dictionary")
	assert_eq(state.size(), 0,
			"Базовият RandomSource няма вътрешно състояние")


func test_set_state_is_noop_and_does_not_change_fixed_behavior() -> void:
	var rng := RandomSource.new()
	rng.set_state({"seed": 99, "state": 12345})
	assert_eq(rng.next_int(1, 6), 1,
			"set_state на базовия клас не трябва да променя фиксираното поведение")
	assert_eq(rng.pick([7, 8, 9]), 7,
			"set_state на базовия клас не трябва да променя pick()")


func test_get_state_after_set_state_remains_empty() -> void:
	var rng := RandomSource.new()
	rng.set_state({"seed": 1, "state": 2})
	assert_eq(rng.get_state(), {},
			"Базовият RandomSource остава без състояние след set_state")


# ── Полиморфизъм ──────────────────────────────────────────────────────────────

func test_seeded_random_source_is_random_source() -> void:
	var seeded := SeededRandomSource.new(42)
	assert_true(seeded is RandomSource,
			"SeededRandomSource трябва да наследява RandomSource")


func test_random_source_typed_variable_accepts_seeded() -> void:
	var rng: RandomSource = SeededRandomSource.new(7)
	var roll: int = rng.next_int(1, 6)
	assert_true(roll >= 1 and roll <= 6,
			"Полиморфно извикване през RandomSource трябва да работи, got %d" % roll)


func test_random_source_typed_pick_accepts_seeded() -> void:
	var rng: RandomSource = SeededRandomSource.new(11)
	var arr: Array = [1, 2, 3, 4]
	var picked: Variant = rng.pick(arr)
	assert_true(picked in arr,
			"Полиморфно pick() през RandomSource трябва да връща елемент от масива")
