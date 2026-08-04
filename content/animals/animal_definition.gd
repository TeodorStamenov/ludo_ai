class_name AnimalDefinition
extends Resource
## Authoring формат за животно-пионка (docs/V1_ARCHITECTURE.md §7 / §4.8;
## content/animals/README.md; #223).
##
## .tres файловете тук се валидират и зареждат от Application слоя при старт —
## Domain никога не зарежда тези файлове сам (§7). animal_id свързва записа с
## MatchConfig.SeatConfig.animal_id (AnimalId).
##
## passive_script е скриптовият клас за пасивното умение на животното
## (game/domain/modifiers/animal_passive.gd) — числов модификатор върху
## съществуваща механика (телепорт/избутване/щит/тегло на подарък), никога
## нова система или game loop (§4.8).
##
## sprite/animations/colorblind_icon са presentation-only — не участват в
## is_valid() (същият прецедент като PowerUpDefinition.visual).

@export var animal_id: StringName = &""
@export var display_name: String = ""
## Скрипт клас, extends AnimalPassive (game/domain/modifiers/animal_passive.gd).
@export var passive_script: GDScript = null
@export var sprite: Texture2D = null
@export var animations: Dictionary = {}
@export var colorblind_icon: Texture2D = null


## Делегира към AnimalDefinitionValidator (#231) — там са стабилните error
## codes; тук остава само удобният bool (същият прецедент като
## MatchConfig.is_valid() / BoardDefinition.is_valid()).
func is_valid() -> bool:
	return AnimalDefinitionValidator.validate(self).ok


## Инстанцира passive_script-а. null при липсващ/невалиден (не extends AnimalPassive) скрипт.
func create_passive() -> AnimalPassive:
	if passive_script == null:
		return null
	var instance: Object = passive_script.new()
	if not (instance is AnimalPassive):
		return null
	return instance as AnimalPassive
