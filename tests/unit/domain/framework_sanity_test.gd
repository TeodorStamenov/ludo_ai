class_name FrameworkSanityTest
extends TestCase
## Базова проверка, че GUT test framework-ът е зареден и работи правилно.
##
## Не тества domain логика — единствената цел е да потвърди, че:
##   - extends TestCase / GutTest се разпознава от runner-а;
##   - основните assert методи работят (pass/fail/pending);
##   - before_each / after_each / before_all / after_all се изпълняват без грешки.
##
## Валидно при двата режима на изпълнение:
##   - GUT CLI:      ./run_tests.sh domain   (addons/gut/gut_cmdln.gd)
##   - Legacy runner: ./run_tests.sh legacy  (tests/test_runner.gd)
##
## Забележка: setUp() / tearDown() са хукове само на legacy runner-а и не се
## тестват тук, за да остане файлът валиден и при двата execution path-а.


var _before_each_called: bool = false


func before_all() -> void:
	pass


func after_all() -> void:
	pass


func before_each() -> void:
	_before_each_called = true


func after_each() -> void:
	pass


# ── Assert primitives ────────────────────────────────────────────────────────

func test_assert_true_passes_for_true() -> void:
	assert_true(true, "assert_true(true) must pass")


func test_assert_false_passes_for_false() -> void:
	assert_false(false, "assert_false(false) must pass")


func test_assert_eq_integers() -> void:
	assert_eq(1 + 1, 2, "Basic integer arithmetic must hold")


func test_assert_eq_strings() -> void:
	assert_eq("hello" + " " + "world", "hello world", "String concatenation must hold")


func test_assert_ne_different_values() -> void:
	assert_ne(1, 2, "1 and 2 are not equal")


func test_assert_null_on_null() -> void:
	assert_null(null, "null must be null")


func test_assert_not_null_on_object() -> void:
	var obj := RefCounted.new()
	assert_not_null(obj, "New RefCounted must not be null")


func test_assert_gt_and_lt() -> void:
	assert_gt(5, 3, "5 > 3")
	assert_lt(3, 5, "3 < 5")


func test_assert_between_inclusive() -> void:
	assert_between(4, 1, 6, "4 is between 1 and 6 inclusive")


# ── Lifecycle hooks ──────────────────────────────────────────────────────────

func test_before_each_was_called() -> void:
	assert_true(_before_each_called, "before_each() must be called before each test")


# ── Type checks ──────────────────────────────────────────────────────────────

func test_is_instance_of_ref_counted() -> void:
	var r := RefCounted.new()
	assert_true(r is RefCounted, "RefCounted.new() must be an instance of RefCounted")


func test_array_operations() -> void:
	var arr: Array = [1, 2, 3]
	assert_eq(arr.size(), 3, "Array size must be 3")
	arr.append(4)
	assert_eq(arr.size(), 4, "Array size must be 4 after append")
	assert_true(4 in arr, "4 must be in array after append")


func test_dictionary_operations() -> void:
	var d: Dictionary = {"key": "value"}
	assert_true(d.has("key"), "Dictionary must have 'key'")
	assert_eq(d["key"], "value", "Dictionary value must match")


# ── Pending marker (smoke-tests that pending is tracked) ─────────────────────

func test_pending_marker_is_supported() -> void:
	pending("This test is intentionally pending — confirms pending() works")
