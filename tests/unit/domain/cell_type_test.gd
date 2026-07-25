class_name CellTypeTest
extends TestCase
## Unit тестове за CellType enum (docs/V1_ARCHITECTURE.md, §4.6).
##
## Покрити инварианти:
##   - Петте типа BASE, PATH, SPAWN, HOME, CENTER със стойности 0–4.
##   - is_valid() приема само 0–4.
##   - type_name() връща стабилни StringName имена.
##   - ALL / COUNT са съгласувани.
##   - Domain: extends RefCounted, път game/domain/model/.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_cell_type_extends_ref_counted() -> void:
	var t := CellType.new()
	assert_true(t is RefCounted,
			"CellType трябва да extends RefCounted, не Node")


func test_cell_type_is_not_node() -> void:
	var t: Object = CellType.new()
	assert_false(t is Node,
			"CellType не трябва да extends Node — domain слой е без сцени")


func test_cell_type_script_path_is_in_domain_model() -> void:
	var t := CellType.new()
	var path: String = t.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"CellType трябва да е в game/domain/model/")


# ── Целочислени стойности ─────────────────────────────────────────────────────

func test_base_value_is_zero() -> void:
	assert_eq(CellType.BASE, 0, "BASE трябва да е 0")


func test_path_value_is_one() -> void:
	assert_eq(CellType.PATH, 1, "PATH трябва да е 1")


func test_spawn_value_is_two() -> void:
	assert_eq(CellType.SPAWN, 2, "SPAWN трябва да е 2")


func test_home_value_is_three() -> void:
	assert_eq(CellType.HOME, 3, "HOME трябва да е 3")


func test_center_value_is_four() -> void:
	assert_eq(CellType.CENTER, 4, "CENTER трябва да е 4")


# ── COUNT и ALL ───────────────────────────────────────────────────────────────

func test_count_is_five() -> void:
	assert_eq(CellType.COUNT, 5, "COUNT трябва да е 5")


func test_all_has_exactly_five_entries() -> void:
	assert_eq(CellType.ALL.size(), 5, "ALL трябва да съдържа точно 5 типа")


func test_all_entries_match_enum_values_in_order() -> void:
	assert_eq(CellType.ALL[0], CellType.BASE,   "ALL[0] трябва да е BASE")
	assert_eq(CellType.ALL[1], CellType.PATH,   "ALL[1] трябва да е PATH")
	assert_eq(CellType.ALL[2], CellType.SPAWN,  "ALL[2] трябва да е SPAWN")
	assert_eq(CellType.ALL[3], CellType.HOME,   "ALL[3] трябва да е HOME")
	assert_eq(CellType.ALL[4], CellType.CENTER, "ALL[4] трябва да е CENTER")


func test_all_entries_are_unique() -> void:
	var seen: Dictionary = {}
	for cell_type in CellType.ALL:
		assert_false(seen.has(cell_type),
				"CellType.ALL съдържа дублирана стойност: %d" % cell_type)
		seen[cell_type] = true


func test_all_size_equals_count() -> void:
	assert_eq(CellType.ALL.size(), CellType.COUNT,
			"ALL.size() трябва да съответства на COUNT")


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_types() -> void:
	for cell_type in CellType.ALL:
		assert_true(CellType.is_valid(cell_type),
				"is_valid трябва да приема тип %d" % cell_type)


func test_is_valid_rejects_negative() -> void:
	assert_false(CellType.is_valid(-1), "is_valid трябва да отхвърли -1")


func test_is_valid_rejects_count() -> void:
	assert_false(CellType.is_valid(CellType.COUNT),
			"is_valid трябва да отхвърли COUNT (%d)" % CellType.COUNT)


func test_is_valid_rejects_large_integer() -> void:
	assert_false(CellType.is_valid(999), "is_valid трябва да отхвърли 999")


# ── type_name ─────────────────────────────────────────────────────────────────

func test_type_name_base() -> void:
	assert_eq(CellType.type_name(CellType.BASE), &"BASE")


func test_type_name_path() -> void:
	assert_eq(CellType.type_name(CellType.PATH), &"PATH")


func test_type_name_spawn() -> void:
	assert_eq(CellType.type_name(CellType.SPAWN), &"SPAWN")


func test_type_name_home() -> void:
	assert_eq(CellType.type_name(CellType.HOME), &"HOME")


func test_type_name_center() -> void:
	assert_eq(CellType.type_name(CellType.CENTER), &"CENTER")


func test_type_name_invalid_returns_unknown() -> void:
	assert_eq(CellType.type_name(-1), &"UNKNOWN")
	assert_eq(CellType.type_name(99), &"UNKNOWN")


func test_type_name_all_types_match_their_names() -> void:
	var expected: Array[StringName] = [
		&"BASE", &"PATH", &"SPAWN", &"HOME", &"CENTER",
	]
	for i in CellType.ALL.size():
		assert_eq(CellType.type_name(CellType.ALL[i]), expected[i],
				"type_name(ALL[%d]) трябва да е &\"%s\"" % [i, expected[i]])
