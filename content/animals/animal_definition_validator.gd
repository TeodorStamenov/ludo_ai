class_name AnimalDefinitionValidator
extends RefCounted
## Валидатор за AnimalDefinition (docs/V1_ARCHITECTURE.md §7 / §4.8;
## content/animals/README.md; #231).
##
## .tres записите се редактират на ръка — валидаторът е предпазната мрежа
## срещу грешка при въвеждане (сгрешен animal_id, забравен/грешен
## passive_script, дублирано или липсващо животно в ростера). Връща
## структуриран Result със стабилни error codes: content loader-ът и логовете
## могат да покажат *защо* записът е отхвърлен, не само bool.
##
## AnimalDefinition.is_valid() делегира тук (същият прецедент като
## MatchConfig.is_valid() / BoardDefinition.is_valid()).
##
## Живее в content/, не в game/domain/: content зависи от domain (AnimalId,
## AnimalPassive), но domain никога не зависи от content (§7).
##
## Визуалните полета (sprite / animations / colorblind_icon) НЕ се валидират —
## тяхната пълнота е обхваната от задачата за визуалните дефиниции.

## Стабилни кодове на грешки (сериализируеми / UI-friendly).
const ERR_NULL_DEFINITION := &"null_definition"
const ERR_INVALID_ANIMAL_ID := &"invalid_animal_id"
const ERR_EMPTY_DISPLAY_NAME := &"empty_display_name"
const ERR_MISSING_PASSIVE_SCRIPT := &"missing_passive_script"
const ERR_PASSIVE_SCRIPT_TYPE := &"passive_script_type"

## Кодове на ниво ростер (колекция от записи).
const ERR_INVALID_ENTRY := &"invalid_entry"
const ERR_DUPLICATE_ANIMAL_ID := &"duplicate_animal_id"
const ERR_MISSING_ANIMAL := &"missing_animal"


## Резултат от валидация: ok + наредени error codes (+ съобщения за дебъг).
class Result extends RefCounted:
	var ok: bool = true
	var error_codes: Array[StringName] = []
	var error_messages: Array[String] = []

	func is_ok() -> bool:
		return ok

	func is_invalid() -> bool:
		return not ok

	func has_error(code: StringName) -> bool:
		return error_codes.has(code)

	func first_error_code() -> StringName:
		if error_codes.is_empty():
			return &""
		return error_codes[0]

	func first_error_message() -> String:
		if error_messages.is_empty():
			return ""
		return error_messages[0]

	func add_error(code: StringName, message: String) -> void:
		ok = false
		error_codes.append(code)
		error_messages.append(message)


## True ако записът минава всички договорни проверки.
static func is_valid(definition: AnimalDefinition) -> bool:
	return validate(definition).ok


## Пълна валидация на един запис — събира всички открити грешки
## (не спира на първата).
static func validate(definition: AnimalDefinition) -> Result:
	var result := Result.new()
	if definition == null:
		result.add_error(ERR_NULL_DEFINITION, "AnimalDefinition е null")
		return result

	_validate_animal_id(definition, result)
	_validate_display_name(definition, result)
	_validate_passive_script(definition, result)
	return result


## Валидация на целия ростер: всеки запис поотделно + уникалност на animal_id
## + покритие на всички v1 животни (AnimalId.ALL).
static func validate_roster(definitions: Array) -> Result:
	var result := Result.new()
	var ids_seen: Dictionary = {}

	for i in definitions.size():
		var definition := definitions[i] as AnimalDefinition
		var entry_result := validate(definition)
		if entry_result.is_invalid():
			result.add_error(ERR_INVALID_ENTRY,
					"невалиден запис на индекс %d: %s" % [
						i, entry_result.first_error_message()])
			continue
		if definition.animal_id in ids_seen:
			result.add_error(ERR_DUPLICATE_ANIMAL_ID,
					"дублиран animal_id '%s'" % String(definition.animal_id))
		else:
			ids_seen[definition.animal_id] = true

	for animal_id in AnimalId.ALL:
		if not (animal_id in ids_seen):
			result.add_error(ERR_MISSING_ANIMAL,
					"липсва запис за animal_id '%s'" % String(animal_id))

	return result


## Кратък низ за telemetry / логове (код + първо съобщение).
static func describe_first_violation(definition: AnimalDefinition) -> String:
	var result := validate(definition)
	if result.is_ok():
		return ""
	return "%s: %s" % [String(result.first_error_code()), result.first_error_message()]


static func _validate_animal_id(definition: AnimalDefinition, result: Result) -> void:
	if not AnimalId.is_valid(definition.animal_id):
		result.add_error(ERR_INVALID_ANIMAL_ID,
				"непознат animal_id '%s'" % String(definition.animal_id))


static func _validate_display_name(definition: AnimalDefinition, result: Result) -> void:
	if definition.display_name.is_empty():
		result.add_error(ERR_EMPTY_DISPLAY_NAME, "display_name не може да е празно")


## passive_script трябва да е наличен И реално да инстанцира AnimalPassive.
## Преизползва AnimalDefinition.create_passive() — без дублирана instantiation логика.
static func _validate_passive_script(definition: AnimalDefinition, result: Result) -> void:
	if definition.passive_script == null:
		result.add_error(ERR_MISSING_PASSIVE_SCRIPT, "passive_script липсва")
		return
	if definition.create_passive() == null:
		result.add_error(ERR_PASSIVE_SCRIPT_TYPE,
				"passive_script не инстанцира AnimalPassive")
