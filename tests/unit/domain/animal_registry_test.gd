extends TestCase
## Unit тестове за AnimalRegistry и реалните content/animals/*.tres записи (#233).
##
## Покрива: зареждане на .tres дефинициите, fallback към DEFAULT животно,
## и че всеки авторизиран запис минава AnimalDefinitionValidator.


var _registry: AnimalRegistry


func before_each() -> void:
	_registry = AnimalRegistry.new()


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_registry_extends_ref_counted() -> void:
	assert_true(_registry is RefCounted,
			"AnimalRegistry трябва да extends RefCounted")


func test_registry_is_not_node() -> void:
	var registry: Object = _registry
	assert_false(registry is Node,
			"AnimalRegistry не трябва да extends Node")


# ── Заредени дефиниции ────────────────────────────────────────────────────────

func test_loads_definition_for_every_animal_with_art() -> void:
	for animal_id in [AnimalId.PIG, AnimalId.COW, AnimalId.HEN, AnimalId.SHEEP]:
		var definition := _registry.definition_for(animal_id)
		assert_not_null(definition, "липсва .tres запис за %s" % animal_id)
		assert_eq(definition.animal_id, animal_id,
				"animal_id в записа трябва да съвпада с ключа")


func test_definitions_carry_sprite_and_display_name() -> void:
	for definition in _registry.all_definitions():
		assert_not_null(definition.sprite,
				"%s трябва да носи sprite" % definition.animal_id)
		assert_false(definition.display_name.is_empty(),
				"%s трябва да носи display_name" % definition.animal_id)


func test_every_authored_definition_passes_validator() -> void:
	for definition in _registry.all_definitions():
		var result := AnimalDefinitionValidator.validate(definition)
		assert_true(result.is_ok(),
				"%s не минава валидатора: %s" % [
					definition.animal_id, result.first_error_message()])


func test_animals_without_art_have_no_definition_yet() -> void:
	# Заек и куче още нямат спрайт — регистърът честно връща null.
	assert_false(_registry.has_definition(AnimalId.RABBIT))
	assert_false(_registry.has_definition(AnimalId.DOG))
	assert_null(_registry.definition_for(AnimalId.RABBIT))


# ── sprite_for fallback ───────────────────────────────────────────────────────

func test_sprite_for_returns_own_sprite_when_authored() -> void:
	var cow_sprite := _registry.sprite_for(AnimalId.COW)
	assert_not_null(cow_sprite)
	assert_eq(cow_sprite, _registry.definition_for(AnimalId.COW).sprite)


func test_sprite_for_falls_back_to_default_animal() -> void:
	# Presentation винаги трябва да получи използваема текстура.
	var rabbit_sprite := _registry.sprite_for(AnimalId.RABBIT)
	assert_not_null(rabbit_sprite,
			"животно без запис пада към DEFAULT спрайта, не към null")
	assert_eq(rabbit_sprite, _registry.definition_for(AnimalId.DEFAULT).sprite)


func test_sprite_for_unknown_animal_falls_back_too() -> void:
	assert_not_null(_registry.sprite_for(&"dragon"))


# ── Уникалност на спрайтовете ─────────────────────────────────────────────────

func test_authored_animals_have_distinct_sprites() -> void:
	var seen: Array = []
	for definition in _registry.all_definitions():
		assert_false(definition.sprite in seen,
				"%s преизползва чужд спрайт" % definition.animal_id)
		seen.append(definition.sprite)
