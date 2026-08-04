class_name AnimalIdTest
extends TestCase
## Unit тестове за AnimalId (Task #24 / docs/V1_GAME_DESIGN.md §4.5,
## content/animals/).
##
## Покрива:
##   - Шестте v1 животни с стабилни StringName ID-та.
##   - DEFAULT и STARTER набори.
##   - is_valid() / is_starter().
##   - Domain слой: extends RefCounted, път game/domain/ids/.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_animal_id_extends_ref_counted() -> void:
	var a := AnimalId.new()
	assert_true(a is RefCounted,
			"AnimalId трябва да extends RefCounted")


func test_animal_id_is_not_node() -> void:
	var a: Object = AnimalId.new()
	assert_false(a is Node,
			"AnimalId не трябва да extends Node")


func test_animal_id_script_path_is_in_domain_ids() -> void:
	var a := AnimalId.new()
	var path: String = a.get_script().resource_path
	assert_true(path.contains("game/domain/ids/"),
			"AnimalId трябва да е в game/domain/ids/")


# ── Константи ─────────────────────────────────────────────────────────────────

func test_animal_constants_have_expected_values() -> void:
	assert_eq(AnimalId.PIG, &"pig")
	assert_eq(AnimalId.RABBIT, &"rabbit")
	assert_eq(AnimalId.DOG, &"dog")
	assert_eq(AnimalId.COW, &"cow")
	assert_eq(AnimalId.HEN, &"hen")
	assert_eq(AnimalId.SHEEP, &"sheep")


func test_default_is_pig() -> void:
	assert_eq(AnimalId.DEFAULT, AnimalId.PIG)


func test_count_is_six() -> void:
	assert_eq(AnimalId.COUNT, 6)
	assert_eq(AnimalId.ALL.size(), 6)


func test_all_entries_are_valid() -> void:
	for id in AnimalId.ALL:
		assert_true(AnimalId.is_valid(id),
				"ALL трябва да съдържа само валидни id: %s" % id)


func test_starter_has_exactly_two_animals() -> void:
	assert_eq(AnimalId.STARTER.size(), 2)
	assert_true(AnimalId.STARTER.has(AnimalId.PIG))
	assert_true(AnimalId.STARTER.has(AnimalId.RABBIT))


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_v1_animals() -> void:
	assert_true(AnimalId.is_valid(AnimalId.PIG))
	assert_true(AnimalId.is_valid(AnimalId.RABBIT))
	assert_true(AnimalId.is_valid(AnimalId.DOG))
	assert_true(AnimalId.is_valid(AnimalId.COW))
	assert_true(AnimalId.is_valid(AnimalId.HEN))


func test_is_valid_rejects_empty_and_unknown() -> void:
	assert_false(AnimalId.is_valid(&""))
	assert_false(AnimalId.is_valid(&"dragon"))
	assert_false(AnimalId.is_valid(&"monkey"))
	assert_false(AnimalId.is_valid(&"chicken"),
			"кокошката е hen, не chicken")


# ── is_starter ────────────────────────────────────────────────────────────────

func test_is_starter_for_unlocked_at_start() -> void:
	assert_true(AnimalId.is_starter(AnimalId.PIG))
	assert_true(AnimalId.is_starter(AnimalId.RABBIT))


func test_is_starter_false_for_campaign_unlocks() -> void:
	assert_false(AnimalId.is_starter(AnimalId.DOG))
	assert_false(AnimalId.is_starter(AnimalId.COW))
	assert_false(AnimalId.is_starter(AnimalId.HEN))
	assert_false(AnimalId.is_starter(AnimalId.SHEEP))


func test_is_starter_false_for_unknown() -> void:
	assert_false(AnimalId.is_starter(&""))
	assert_false(AnimalId.is_starter(&"dragon"))
