class_name ModifierPipeline
extends RefCounted
## Прилага всички активни AnimalPassive модификатори при разрешаване на ефект
## (docs/V1_ARCHITECTURE.md, §4.7 / §4.8).
##
## Получава списък от AnimalPassive инстанции и прилага всеки от тях
## последователно върху числовия параметър преди power-up ефектът да е
## валидиран и приложен. Празен pipeline (V1 без реален animal content) връща
## base стойностите непроменени — всеки AnimalPassive.modify_* по подразбиране
## е identity (game/domain/modifiers/animal_passive.gd).

var _passives: Array[AnimalPassive] = []


func _init(passives: Array[AnimalPassive] = []) -> void:
	_passives = passives.duplicate()


func add(passive: AnimalPassive) -> void:
	if passive != null:
		_passives.append(passive)


func modify_teleport_distance(base: int) -> int:
	var value := base
	for passive in _passives:
		value = passive.modify_teleport_distance(value)
	return value


func modify_push_distance(base: int) -> int:
	var value := base
	for passive in _passives:
		value = passive.modify_push_distance(value)
	return value


func modify_shield_duration(base: int) -> int:
	var value := base
	for passive in _passives:
		value = passive.modify_shield_duration(value)
	return value


func modify_gift_spawn_weight(base: float) -> float:
	var value := base
	for passive in _passives:
		value = passive.modify_gift_spawn_weight(value)
	return value
