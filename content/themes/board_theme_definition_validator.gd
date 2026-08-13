@tool
class_name BoardThemeDefinitionValidator
extends RefCounted
## Валидатор за BoardThemeDefinition (docs/V1_ARCHITECTURE.md §7;
## content/themes/README.md).
##
## @tool задължителен — BoardThemeDefinition.is_valid() го извиква, а
## BoardThemeDefinition е @tool (вижте обяснението там за "placeholder
## instance" грешката иначе).
##
## Проверява само функционалния минимум, без който дъската буквално не може
## да се изобрази: theme_id + CENTER/PATH текстури + текстура за всеки играч
## на дъската (PlayerId.ALL). gift_visual/ambience_audio/sfx_set НЕ се
## валидират — presentation полета, същият прецедент като
## AnimalDefinitionValidator (sprite/colorblind_icon остават извън обхват).
##
## Живее в content/, не в game/domain/: content зависи от domain (ThemeId,
## PlayerId), но domain никога не зависи от content (§7).

## Стабилни кодове на грешки (сериализируеми / UI-friendly).
const ERR_NULL_DEFINITION := &"null_definition"
const ERR_INVALID_THEME_ID := &"invalid_theme_id"
const ERR_MISSING_CENTER_TEXTURE := &"missing_center_texture"
const ERR_MISSING_PATH_TEXTURE := &"missing_path_texture"
const ERR_MISSING_PLAYER_TEXTURE := &"missing_player_texture"

## Кодове на ниво ростер (колекция от записи).
const ERR_INVALID_ENTRY := &"invalid_entry"
const ERR_DUPLICATE_THEME_ID := &"duplicate_theme_id"
const ERR_MISSING_THEME := &"missing_theme"


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
static func is_valid(definition: BoardThemeDefinition) -> bool:
	return validate(definition).ok


## Пълна валидация на един запис — събира всички открити грешки
## (не спира на първата).
static func validate(definition: BoardThemeDefinition) -> Result:
	var result := Result.new()
	if definition == null:
		result.add_error(ERR_NULL_DEFINITION, "BoardThemeDefinition е null")
		return result

	if not ThemeId.is_valid(definition.theme_id):
		result.add_error(ERR_INVALID_THEME_ID,
				"непознат theme_id '%s'" % String(definition.theme_id))

	if definition.center_texture == null:
		result.add_error(ERR_MISSING_CENTER_TEXTURE, "center_texture липсва")
	if definition.path_texture == null:
		result.add_error(ERR_MISSING_PATH_TEXTURE, "path_texture липсва")

	for player_id in PlayerId.ALL:
		if definition.texture_for_player(player_id) == null:
			result.add_error(ERR_MISSING_PLAYER_TEXTURE,
					"липсва player_textures['%s']" % String(player_id))

	return result


## Валидация на целия набор теми: всеки запис поотделно + уникалност на
## theme_id + покритие на всички v1 теми (ThemeId.ALL).
static func validate_roster(definitions: Array) -> Result:
	var result := Result.new()
	var ids_seen: Dictionary = {}

	for i in definitions.size():
		var definition := definitions[i] as BoardThemeDefinition
		var entry_result := validate(definition)
		if entry_result.is_invalid():
			result.add_error(ERR_INVALID_ENTRY,
					"невалиден запис на индекс %d: %s" % [
						i, entry_result.first_error_message()])
			continue
		if definition.theme_id in ids_seen:
			result.add_error(ERR_DUPLICATE_THEME_ID,
					"дублиран theme_id '%s'" % String(definition.theme_id))
		else:
			ids_seen[definition.theme_id] = true

	for theme_id in ThemeId.ALL:
		if not (theme_id in ids_seen):
			result.add_error(ERR_MISSING_THEME,
					"липсва запис за theme_id '%s'" % String(theme_id))

	return result


## Кратък низ за telemetry / логове (код + първо съобщение).
static func describe_first_violation(definition: BoardThemeDefinition) -> String:
	var result := validate(definition)
	if result.is_ok():
		return ""
	return "%s: %s" % [String(result.first_error_code()), result.first_error_message()]
