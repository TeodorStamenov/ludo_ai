class_name PowerUpDefinition
extends Resource
## Authoring формат за power-up ефект (docs/V1_ARCHITECTURE.md §7 / §4.7;
## content/power_ups/README.md; #196).
##
## .tres файловете тук се валидират и зареждат от Application слоя при старт —
## registry свързва power_up_id с PowerUpResolver instance от resolver_script
## (§4.7: "Няма match power_up_id из различни UI скриптове"). Domain никога не
## зарежда тези файлове сам.
##
## visual е ефектът при активация (тема-независим) — визуалният skin на
## самата (все още незакрита) кутия е в BoardThemeDefinition.gift_visual (§7),
## не тук.

@export var power_up_id: StringName = &""
@export var display_name: String = ""
## Скрипт клас, extends PowerUpResolver (game/domain/power_ups/).
@export var resolver_script: GDScript = null
@export var visual: PackedScene = null


func is_valid() -> bool:
	if power_up_id == &"":
		return false
	if display_name.is_empty():
		return false
	return resolver_script != null


## Инстанцира resolver_script-а. null при невалиден/липсващ скрипт.
func create_resolver() -> PowerUpResolver:
	if resolver_script == null:
		return null
	var instance: Object = resolver_script.new()
	if not (instance is PowerUpResolver):
		return null
	return instance as PowerUpResolver
