extends TestCase
## Unit тестове за AnimalDefinition (content/animals/animal_definition.gd; #223).
##
## Покрива: Resource-базов authoring формат (огледало на PowerUpDefinition/
## GiftDefinition), is_valid() инварианти, create_passive() factory.


func test_animal_definition_extends_resource() -> void:
	var definition := AnimalDefinition.new()
	assert_not_null(definition)
	assert_true(definition is Resource,
			"AnimalDefinition трябва да extends Resource (authoring формат, #7)")


func test_animal_definition_script_path_is_in_content_animals() -> void:
	var path: String = AnimalDefinition.new().get_script().resource_path
	assert_true(path.contains("content/animals/"),
			"AnimalDefinition трябва да е в content/animals/")


func test_default_fields_are_empty_and_invalid() -> void:
	var definition := AnimalDefinition.new()
	assert_eq(definition.animal_id, &"")
	assert_eq(definition.display_name, "")
	assert_null(definition.passive_script)
	assert_null(definition.sprite)
	assert_true(definition.animations.is_empty())
	assert_null(definition.colorblind_icon)
	assert_false(definition.is_valid())


# --- is_valid() ---

func test_is_valid_accepts_full_valid_definition() -> void:
	assert_true(_valid_definition().is_valid())


func test_is_valid_rejects_invalid_animal_id() -> void:
	var definition := _valid_definition()
	definition.animal_id = &"not_an_animal"
	assert_false(definition.is_valid())


func test_is_valid_rejects_empty_animal_id() -> void:
	var definition := _valid_definition()
	definition.animal_id = &""
	assert_false(definition.is_valid())


func test_is_valid_accepts_all_v1_animal_ids() -> void:
	for id in AnimalId.ALL:
		var definition := _valid_definition()
		definition.animal_id = id
		assert_true(definition.is_valid(), "animal_id %s трябва да е валиден" % id)


func test_is_valid_rejects_empty_display_name() -> void:
	var definition := _valid_definition()
	definition.display_name = ""
	assert_false(definition.is_valid())


func test_is_valid_rejects_missing_passive_script() -> void:
	var definition := _valid_definition()
	definition.passive_script = null
	assert_false(definition.is_valid())


func test_is_valid_ignores_missing_presentation_fields() -> void:
	# sprite/animations/colorblind_icon са presentation-only — не участват в
	# is_valid() (същият прецедент като PowerUpDefinition.visual).
	var definition := _valid_definition()
	definition.sprite = null
	definition.animations = {}
	definition.colorblind_icon = null
	assert_true(definition.is_valid())


# --- create_passive() ---

func test_create_passive_returns_null_when_script_missing() -> void:
	var definition := _valid_definition()
	definition.passive_script = null
	assert_null(definition.create_passive())


func test_create_passive_instantiates_valid_passive_script() -> void:
	var definition := _valid_definition()
	definition.passive_script = _StubPassive
	var passive := definition.create_passive()
	assert_not_null(passive)
	assert_true(passive is AnimalPassive)
	assert_eq(passive.modify_push_distance(2), 5,
			"трябва да е реалният _StubPassive instance, не базов AnimalPassive")


func test_create_passive_returns_null_for_script_not_extending_animal_passive() -> void:
	var definition := _valid_definition()
	definition.passive_script = _NotAPassive
	assert_null(definition.create_passive())


func _valid_definition() -> AnimalDefinition:
	var definition := AnimalDefinition.new()
	definition.animal_id = AnimalId.PIG
	definition.display_name = "Pig"
	definition.passive_script = _StubPassive
	return definition


## Тестов passive script — за проверка на create_passive() instantiation/type-check.
class _StubPassive extends AnimalPassive:
	func modify_push_distance(base: int) -> int:
		return base + 3


## Скрипт, който НЕ extends AnimalPassive — create_passive() трябва да го отхвърли.
class _NotAPassive extends RefCounted:
	pass
