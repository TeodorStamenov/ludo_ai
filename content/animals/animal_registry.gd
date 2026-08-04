class_name AnimalRegistry
extends RefCounted
## Свързва animal_id с authoring записа му (content/animals/*.tres; #233).
##
## Presentation (GameScreen) взима оттук спрайта/иконата за seat-а вместо да
## хардкодва пътища към текстури. Същият прецедент като PowerUpRegistry
## (game/domain/power_ups/power_up_registry.gd): фиксирана таблица в _init(),
## без DirAccess сканиране — пълноценен content loader с валидация при старт
## остава отделна задача (content/README.md).
##
## Живее в content/, не в game/domain/: content зависи от domain, но domain
## никога не зависи от content (docs/V1_ARCHITECTURE.md §7).
##
## Животни без наличен запис (напр. заек/куче — още нямат арт) връщат null от
## definition_for(); викащият пада към DEFAULT (виж sprite_for).

const _DEFINITION_PATHS: Dictionary = {
	AnimalId.PIG: "res://content/animals/pig.tres",
	AnimalId.COW: "res://content/animals/cow.tres",
	AnimalId.HEN: "res://content/animals/hen.tres",
	AnimalId.SHEEP: "res://content/animals/sheep.tres",
}

## animal_id (StringName) → AnimalDefinition
var _definitions: Dictionary = {}


func _init() -> void:
	for animal_id in _DEFINITION_PATHS:
		var definition := load(_DEFINITION_PATHS[animal_id]) as AnimalDefinition
		if definition != null:
			_definitions[animal_id] = definition


## Записът за animal_id, или null ако още няма авторизирано съдържание.
func definition_for(animal_id: StringName) -> AnimalDefinition:
	return _definitions.get(animal_id) as AnimalDefinition


func has_definition(animal_id: StringName) -> bool:
	return definition_for(animal_id) != null


## Спрайтът за animal_id с fallback към DEFAULT животното — Presentation
## винаги получава използваема текстура, дори за животно без собствен запис.
func sprite_for(animal_id: StringName) -> Texture2D:
	var definition := definition_for(animal_id)
	if definition == null:
		definition = definition_for(AnimalId.DEFAULT)
	if definition == null:
		return null
	return definition.sprite


## Всички заредени записи (за валидация през AnimalDefinitionValidator).
func all_definitions() -> Array:
	return _definitions.values()
