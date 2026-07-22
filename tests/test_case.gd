class_name TestCase
extends RefCounted
## Базов клас за всички unit тестови файлове.
##
## Наследяващите класове дефинират методи с префикс test_.
## setUp() и tearDown() се извикват около всеки test_ метод ако съществуват.

var _current_label: String = ""
var _case_failed: bool = false


func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		_case_failed = true
		var suffix := (": " + msg) if msg else ""
		push_error("ASSERT FAILED [%s] assert_true%s" % [_current_label, suffix])


func assert_false(value: bool, msg: String = "") -> void:
	assert_true(not value, msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		_case_failed = true
		var suffix := (": " + msg) if msg else ""
		push_error("ASSERT FAILED [%s] assert_eq — expected %s, got %s%s" % [
			_current_label, str(b), str(a), suffix
		])


func assert_ne(a: Variant, b: Variant, msg: String = "") -> void:
	if a == b:
		_case_failed = true
		var suffix := (": " + msg) if msg else ""
		push_error("ASSERT FAILED [%s] assert_ne — expected != %s%s" % [
			_current_label, str(b), suffix
		])


func assert_not_null(value: Variant, msg: String = "") -> void:
	assert_true(value != null, msg if msg else "expected non-null")


func assert_null(value: Variant, msg: String = "") -> void:
	assert_true(value == null, msg if msg else "expected null")
