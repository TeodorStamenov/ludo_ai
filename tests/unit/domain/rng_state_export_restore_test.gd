class_name RngStateExportRestoreTest
extends TestCase
## Unit тестове за export / restore на RNG state (Task #31 /
## docs/V1_ARCHITECTURE.md §4.5).
##
## Покрива:
##   - JSON-safe get_state() payload ({"seed", "state"} като String — 64-bit safe).
##   - Независимо копие при export (мутация не пипа живия RNG).
##   - set_state() възстановява next_int / pick потока точно.
##   - JSON stringify → parse → set_state round-trip без загуба.
##   - Coercion на String / int / float seed payload.
##   - Кръстосано възстановяване върху нова инстанция.


# ── Формат на export payload ──────────────────────────────────────────────────

func test_exported_state_has_required_keys() -> void:
	var rng := SeededRandomSource.new(42)
	var exported := rng.get_state()
	assert_true(exported.has("seed"), "export трябва да съдържа 'seed'")
	assert_true(exported.has("state"), "export трябва да съдържа 'state'")
	assert_eq(exported.size(), 2,
			"export payload трябва да съдържа само seed и state")


func test_exported_values_are_strings_for_json_safety() -> void:
	var rng := SeededRandomSource.new(99)
	rng.next_int(1, 6)
	var exported := rng.get_state()
	assert_eq(typeof(exported["seed"]), TYPE_STRING,
			"seed трябва да е String — JSON number губи 64-bit точност")
	assert_eq(typeof(exported["state"]), TYPE_STRING,
			"state трябва да е String — JSON number губи 64-bit точност")


func test_exported_seed_matches_constructor_seed() -> void:
	var rng := SeededRandomSource.new(123456)
	assert_eq(rng.get_state()["seed"], "123456")


func test_export_advances_state_after_draws() -> void:
	var rng := SeededRandomSource.new(7)
	var before: String = str(rng.get_state()["state"])
	rng.next_int(0, 100)
	var after: String = str(rng.get_state()["state"])
	assert_ne(before, after,
			"export.state трябва да се променя след next_int")


# ── Независимост на export копието ────────────────────────────────────────────

func test_mutating_exported_dict_does_not_affect_rng() -> void:
	var rng := SeededRandomSource.new(55)
	for _i in 3:
		rng.next_int(1, 6)
	var exported := rng.get_state()
	var original_seed: String = str(exported["seed"])
	var original_state: String = str(exported["state"])

	exported["seed"] = "0"
	exported["state"] = "0"
	exported["injected"] = true

	var live := rng.get_state()
	assert_eq(live["seed"], original_seed,
			"мутация на export dict не трябва да пипа живия seed")
	assert_eq(live["state"], original_state,
			"мутация на export dict не трябва да пипа живия state")
	assert_false(live.has("injected"))


# ── Restore продължава същия поток ────────────────────────────────────────────

func test_restore_continues_next_int_sequence() -> void:
	var rng := SeededRandomSource.new(777)
	for _i in 12:
		rng.next_int(1, 6)
	var snapshot := rng.get_state()

	var expected: Array = []
	for _i in 20:
		expected.append(rng.next_int(1, 6))

	rng.set_state(snapshot)
	var actual: Array = []
	for _i in 20:
		actual.append(rng.next_int(1, 6))

	assert_eq(actual, expected,
			"restore трябва да продължи next_int потока от checkpoint")


func test_restore_continues_pick_sequence() -> void:
	var arr: Array = ["a", "b", "c", "d", "e"]
	var rng := SeededRandomSource.new(31415)
	for _i in 5:
		rng.pick(arr)
	var snapshot := rng.get_state()

	var expected: Array = []
	for _i in 15:
		expected.append(rng.pick(arr))

	rng.set_state(snapshot)
	var actual: Array = []
	for _i in 15:
		actual.append(rng.pick(arr))

	assert_eq(actual, expected,
			"restore трябва да продължи pick потока от checkpoint")


func test_restore_mixed_next_int_and_pick_stream() -> void:
	var arr: Array = [10, 20, 30]
	var rng := SeededRandomSource.new(2026)
	for _i in 4:
		rng.next_int(1, 6)
		rng.pick(arr)
	var snapshot := rng.get_state()

	var expected: Array = []
	for _i in 10:
		expected.append(rng.next_int(1, 6))
		expected.append(rng.pick(arr))

	rng.set_state(snapshot)
	var actual: Array = []
	for _i in 10:
		actual.append(rng.next_int(1, 6))
		actual.append(rng.pick(arr))

	assert_eq(actual, expected,
			"restore трябва да пази смесен next_int/pick поток")


# ── Кръстосано възстановяване върху нова инстанция ────────────────────────────

func test_restore_onto_fresh_instance_matches_original() -> void:
	var original := SeededRandomSource.new(98765)
	for _i in 9:
		original.next_int(0, 1000)
	var snapshot := original.get_state()

	var expected: Array = []
	for _i in 25:
		expected.append(original.next_int(0, 1000))

	var restored := SeededRandomSource.new(0)
	restored.set_state(snapshot)
	var actual: Array = []
	for _i in 25:
		actual.append(restored.next_int(0, 1000))

	assert_eq(actual, expected,
			"set_state върху нова инстанция трябва да възпроизведе същия поток")


func test_multiple_restore_cycles_remain_stable() -> void:
	var rng := SeededRandomSource.new(111)
	for _i in 6:
		rng.next_int(1, 6)
	var snapshot := rng.get_state()

	var reference: Array = []
	for _i in 12:
		reference.append(rng.next_int(1, 6))

	for cycle in 5:
		rng.set_state(snapshot)
		var replayed: Array = []
		for _i in 12:
			replayed.append(rng.next_int(1, 6))
		assert_eq(replayed, reference,
				"restore cycle %d трябва да даде същата последователност" % cycle)


# ── JSON round-trip (save / snapshot payload) ─────────────────────────────────

func test_json_round_trip_preserves_64bit_state() -> void:
	var rng := SeededRandomSource.new(424242)
	for _i in 8:
		rng.next_int(1, 6)
	var exported := rng.get_state()

	# 64-bit state трябва да е извън точната float зона (> 2^53), иначе
	# тестът не би хванал регресия към JSON number encoding.
	var state_int: int = str(exported["state"]).to_int()
	assert_true(absi(state_int) > 9007199254740992,
			"fixture state трябва да е > 2^53, got %d" % state_int)

	var expected: Array = []
	for _i in 18:
		expected.append(rng.next_int(1, 6))

	var json_text := JSON.stringify(exported)
	assert_false(json_text.is_empty(), "JSON.stringify на export не трябва да е празен")
	assert_true(json_text.contains("\""),
			"seed/state трябва да са JSON strings, не numbers")

	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "JSON.parse трябва да върне Dictionary")
	var parsed_dict: Dictionary = parsed
	assert_eq(typeof(parsed_dict["seed"]), TYPE_STRING)
	assert_eq(typeof(parsed_dict["state"]), TYPE_STRING)
	assert_eq(parsed_dict["state"], exported["state"],
			"64-bit state трябва да оцелее JSON round-trip без загуба")

	var restored := SeededRandomSource.new(0)
	restored.set_state(parsed_dict)
	var actual: Array = []
	for _i in 18:
		actual.append(restored.next_int(1, 6))

	assert_eq(actual, expected,
			"JSON export → parse → set_state трябва да е без загуба на потока")


func test_set_state_accepts_int_payload() -> void:
	var original := SeededRandomSource.new(50)
	for _i in 7:
		original.next_int(1, 6)
	var snapshot := original.get_state()

	var expected: Array = []
	for _i in 10:
		expected.append(original.next_int(1, 6))

	var int_payload := {
		"seed": str(snapshot["seed"]).to_int(),
		"state": str(snapshot["state"]).to_int(),
	}
	var restored := SeededRandomSource.new(0)
	restored.set_state(int_payload)
	var actual: Array = []
	for _i in 10:
		actual.append(restored.next_int(1, 6))

	assert_eq(actual, expected,
			"set_state трябва да приема и int seed/state (in-memory)")


func test_set_state_coerces_float_seed() -> void:
	# seed обикновено е в точната float зона; state НЕ се подава като float.
	var original := SeededRandomSource.new(50)
	for _i in 3:
		original.next_int(1, 6)
	var snapshot := original.get_state()

	var expected: Array = []
	for _i in 8:
		expected.append(original.next_int(1, 6))

	var mixed_payload := {
		"seed": float(str(snapshot["seed"]).to_int()),
		"state": snapshot["state"],
	}
	var restored := SeededRandomSource.new(0)
	restored.set_state(mixed_payload)
	var actual: Array = []
	for _i in 8:
		actual.append(restored.next_int(1, 6))

	assert_eq(actual, expected,
			"set_state трябва да coerce-ва float seed към int")


# ── Полиморфизъм през RandomSource ────────────────────────────────────────────

func test_export_restore_via_random_source_typed_api() -> void:
	var rng: RandomSource = SeededRandomSource.new(333)
	for _i in 5:
		rng.next_int(1, 6)
	var snapshot := rng.get_state()

	var expected: Array = []
	for _i in 8:
		expected.append(rng.next_int(1, 6))

	var other: RandomSource = SeededRandomSource.new(1)
	other.set_state(snapshot)
	var actual: Array = []
	for _i in 8:
		actual.append(other.next_int(1, 6))

	assert_eq(actual, expected,
			"export/restore през RandomSource API трябва да работи полиморфно")
