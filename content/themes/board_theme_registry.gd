@tool
class_name BoardThemeRegistry
extends RefCounted
## Свързва theme_id с authoring записа му (content/themes/*.tres).
##
## @tool задължителен — BoardView (@tool) го инстанцира; вижте обяснението в
## board_theme_definition.gd за "placeholder instance" грешката без @tool.
##
## BoardView взима оттук текстурите за клетките вместо да хардкодва CHIP_*
## пътища. Същият прецедент като AnimalRegistry (content/animals/): фиксирана
## таблица в _init(), без DirAccess сканиране — пълноценен content loader с
## валидация при старт остава отделна задача (content/README.md).
##
## Живее в content/, не в game/domain/: content зависи от domain, но domain
## никога не зависи от content (docs/V1_ARCHITECTURE.md §7).
##
## Добавяне на нова тема = нов ред тук + нов .tres с текстури/звук — без
## промяна в BoardView.

const _DEFINITION_PATHS: Dictionary = {
	ThemeId.JUNGLE: "res://content/themes/jungle.tres",
}

## theme_id (StringName) → BoardThemeDefinition
var _definitions: Dictionary = {}


func _init() -> void:
	for theme_id in _DEFINITION_PATHS:
		var definition := load(_DEFINITION_PATHS[theme_id]) as BoardThemeDefinition
		if definition != null:
			_definitions[theme_id] = definition


## Записът за theme_id, или null ако още няма авторизирано съдържание.
func definition_for(theme_id: StringName) -> BoardThemeDefinition:
	return _definitions.get(theme_id) as BoardThemeDefinition


func has_definition(theme_id: StringName) -> bool:
	return definition_for(theme_id) != null


## Записът за theme_id с fallback към ThemeId.DEFAULT — BoardView винаги
## получава използваема тема, дори за theme_id без собствен .tres.
func definition_for_or_default(theme_id: StringName) -> BoardThemeDefinition:
	var definition := definition_for(theme_id)
	if definition != null:
		return definition
	return definition_for(ThemeId.DEFAULT)


## Всички заредени записи (за валидация през BoardThemeDefinitionValidator).
func all_definitions() -> Array:
	return _definitions.values()
