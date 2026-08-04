extends TestCase
## Unit тестове за AnimalDefinitionValidator (content/animals/; #231).
##
## Покрива:
##   - Архитектура (RefCounted, не Node, Result).
##   - Валиден запис → Result.ok.
##   - Стабилен error code за всяко договорно нарушение.
##   - Натрупване на няколко грешки в един запис (не спира на първата).
##   - validate_roster: уникалност на animal_id + покритие на AnimalId.ALL.
##   - AnimalDefinition.is_valid() делегира към валидатора.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_validator_extends_ref_counted() -> void:
	var v := AnimalDefinitionValidator.new()
	assert_true(v is RefCounted,
			"AnimalDefinitionValidator трябва да extends RefCounted")


func test_validator_is_not_node() -> void:
	var v: Object = AnimalDefinitionValidator.new()
	assert_false(v is Node,
			"AnimalDefinitionValidator не трябва да extends Node")


func test_validator_script_path_is_in_content_animals() -> void:
	var path: String = AnimalDefinitionValidator.new().get_script().resource_path
	assert_true(path.contains("content/animals/"),
			"валидаторът живее до класа, който валидира (domain не зависи от content)")


func test_result_extends_ref_counted() -> void:
	var result := AnimalDefinitionValidator.Result.new()
	assert_true(result is RefCounted,
			"AnimalDefinitionValidator.Result трябва да extends RefCounted")


# ── Валиден запис ─────────────────────────────────────────────────────────────

func test_valid_definition_passes() -> void:
	var result := AnimalDefinitionValidator.validate(_valid_definition())
	assert_true(result.is_ok(), "пълен валиден запис трябва да мине")
	assert_eq(result.error_codes.size(), 0)
	assert_true(AnimalDefinitionValidator.is_valid(_valid_definition()))


func test_valid_for_every_v1_animal_id() -> void:
	for id in AnimalId.ALL:
		var definition := _valid_definition()
		definition.animal_id = id
		assert_true(AnimalDefinitionValidator.is_valid(definition),
				"animal_id %s трябва да е валиден" % id)


func test_missing_presentation_fields_still_valid() -> void:
	# sprite/animations/colorblind_icon са извън обхвата на този валидатор.
	var definition := _valid_definition()
	definition.sprite = null
	definition.animations = {}
	definition.colorblind_icon = null
	assert_true(AnimalDefinitionValidator.is_valid(definition))


# ── Единични нарушения ────────────────────────────────────────────────────────

func test_null_definition_reports_null_error() -> void:
	var result := AnimalDefinitionValidator.validate(null)
	assert_true(result.is_invalid())
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_NULL_DEFINITION))
	assert_eq(result.error_codes.size(), 1,
			"null записът излиза веднага — без последващи проверки")


func test_invalid_animal_id_reports_error() -> void:
	var definition := _valid_definition()
	definition.animal_id = &"not_an_animal"
	var result := AnimalDefinitionValidator.validate(definition)
	assert_true(result.is_invalid())
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_INVALID_ANIMAL_ID))


func test_empty_animal_id_reports_error() -> void:
	var definition := _valid_definition()
	definition.animal_id = &""
	var result := AnimalDefinitionValidator.validate(definition)
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_INVALID_ANIMAL_ID))


func test_empty_display_name_reports_error() -> void:
	var definition := _valid_definition()
	definition.display_name = ""
	var result := AnimalDefinitionValidator.validate(definition)
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_EMPTY_DISPLAY_NAME))


func test_missing_passive_script_reports_error() -> void:
	var definition := _valid_definition()
	definition.passive_script = null
	var result := AnimalDefinitionValidator.validate(definition)
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_MISSING_PASSIVE_SCRIPT))
	assert_false(result.has_error(AnimalDefinitionValidator.ERR_PASSIVE_SCRIPT_TYPE),
			"липсващ script не бива да рапортува и грешен тип")


func test_passive_script_not_extending_animal_passive_reports_error() -> void:
	var definition := _valid_definition()
	definition.passive_script = _NotAPassive
	var result := AnimalDefinitionValidator.validate(definition)
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_PASSIVE_SCRIPT_TYPE))


func test_real_project_passives_are_accepted() -> void:
	# Реалните пасиви (PigPassive/CowPassive) трябва да минават type проверката.
	for script in [PigPassive, CowPassive]:
		var definition := _valid_definition()
		definition.passive_script = script
		assert_true(AnimalDefinitionValidator.is_valid(definition))


# ── Натрупване на грешки ──────────────────────────────────────────────────────

func test_collects_all_violations_without_stopping_at_first() -> void:
	var definition := AnimalDefinition.new()  # всички полета празни
	var result := AnimalDefinitionValidator.validate(definition)
	assert_true(result.is_invalid())
	assert_eq(result.error_codes.size(), 3,
			"празен запис нарушава id + display_name + passive_script")
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_INVALID_ANIMAL_ID))
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_EMPTY_DISPLAY_NAME))
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_MISSING_PASSIVE_SCRIPT))


func test_describe_first_violation_formats_code_and_message() -> void:
	var definition := _valid_definition()
	definition.display_name = ""
	var described := AnimalDefinitionValidator.describe_first_violation(definition)
	assert_true(described.begins_with(
			String(AnimalDefinitionValidator.ERR_EMPTY_DISPLAY_NAME)),
			"описанието започва със стабилния error code")
	assert_eq(AnimalDefinitionValidator.describe_first_violation(_valid_definition()), "",
			"валиден запис няма описание на нарушение")


# ── Ростер (колекция) ─────────────────────────────────────────────────────────

func test_full_roster_passes() -> void:
	var result := AnimalDefinitionValidator.validate_roster(_full_roster())
	assert_true(result.is_ok(), "пълен ростер от всички AnimalId.ALL трябва да мине")
	assert_eq(result.error_codes.size(), 0)


func test_roster_reports_duplicate_animal_id() -> void:
	var roster := _full_roster()
	roster[1].animal_id = roster[0].animal_id
	var result := AnimalDefinitionValidator.validate_roster(roster)
	assert_true(result.is_invalid())
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_DUPLICATE_ANIMAL_ID))


func test_roster_reports_missing_animal() -> void:
	var roster := _full_roster()
	roster.remove_at(roster.size() - 1)
	var result := AnimalDefinitionValidator.validate_roster(roster)
	assert_true(result.is_invalid())
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_MISSING_ANIMAL))


func test_roster_reports_invalid_entry() -> void:
	var roster := _full_roster()
	roster[0].display_name = ""
	var result := AnimalDefinitionValidator.validate_roster(roster)
	assert_true(result.is_invalid())
	assert_true(result.has_error(AnimalDefinitionValidator.ERR_INVALID_ENTRY))


func test_empty_roster_reports_every_missing_animal() -> void:
	var result := AnimalDefinitionValidator.validate_roster([])
	assert_true(result.is_invalid())
	assert_eq(result.error_codes.size(), AnimalId.COUNT,
			"празен ростер → по едно ERR_MISSING_ANIMAL за всяко v1 животно")


# ── Делегиране от AnimalDefinition ────────────────────────────────────────────

func test_animal_definition_is_valid_delegates_to_validator() -> void:
	var valid := _valid_definition()
	assert_eq(valid.is_valid(), AnimalDefinitionValidator.is_valid(valid))

	var invalid := _valid_definition()
	invalid.animal_id = &"not_an_animal"
	assert_false(invalid.is_valid())
	assert_eq(invalid.is_valid(), AnimalDefinitionValidator.is_valid(invalid))


func test_animal_definition_is_valid_rejects_wrong_passive_script_type() -> void:
	# Делегирането добавя type проверката, която самостоятелното is_valid() нямаше.
	var definition := _valid_definition()
	definition.passive_script = _NotAPassive
	assert_false(definition.is_valid())


# ── Помощни ───────────────────────────────────────────────────────────────────

func _valid_definition() -> AnimalDefinition:
	var definition := AnimalDefinition.new()
	definition.animal_id = AnimalId.PIG
	definition.display_name = "Pig"
	definition.passive_script = _StubPassive
	return definition


## По един валиден запис за всяко v1 животно.
func _full_roster() -> Array:
	var roster: Array = []
	for id in AnimalId.ALL:
		var definition := _valid_definition()
		definition.animal_id = id
		definition.display_name = String(id).capitalize()
		roster.append(definition)
	return roster


## Тестов passive script — минава type проверката на валидатора.
class _StubPassive extends AnimalPassive:
	func modify_push_distance(base: int) -> int:
		return base + 3


## Скрипт, който НЕ extends AnimalPassive — валидаторът трябва да го отхвърли.
class _NotAPassive extends RefCounted:
	pass
