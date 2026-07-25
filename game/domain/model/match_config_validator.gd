class_name MatchConfigValidator
extends RefCounted
## Валидатор за MatchConfig (docs/V1_ARCHITECTURE.md §5.1,
## docs/V1_GAME_DESIGN.md §3.3 / §8.2).
##
## Проверява договорните граници на конфигурацията преди MatchSession.start /
## MatchFactory.create. Връща структуриран Result с стабилни error codes —
## UI и логове могат да покажат *защо* config е отхвърлен, не само bool.
##
## MatchConfig.is_valid() делегира тук. Domain-only: без Node, файлове или content/.

## Стабилни кодове на грешки (сериализируеми / UI-friendly).
const ERR_NULL_CONFIG := &"null_config"
const ERR_UNSUPPORTED_SCHEMA := &"unsupported_schema"
const ERR_INVALID_MODE := &"invalid_mode"
const ERR_EMPTY_BOARD_ID := &"empty_board_id"
const ERR_INVALID_THEME := &"invalid_theme"
const ERR_CAMPAIGN_LEVEL_REQUIRED := &"campaign_level_required"
const ERR_CAMPAIGN_LEVEL_FORBIDDEN := &"campaign_level_forbidden"
const ERR_INVALID_LEVEL_MODIFIER := &"invalid_level_modifier"
const ERR_INVALID_SEAT_COUNT := &"invalid_seat_count"
const ERR_INVALID_SEAT := &"invalid_seat"
const ERR_DUPLICATE_PLAYER_ID := &"duplicate_player_id"
const ERR_NON_OPPOSITE_SEATS := &"non_opposite_seats"


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


## True ако config минава всички договорни проверки.
static func is_valid(config: MatchConfig) -> bool:
	return validate(config).ok


## Пълна валидация — събира всички открити грешки (не спира на първата).
static func validate(config: MatchConfig) -> Result:
	var result := Result.new()
	if config == null:
		result.add_error(ERR_NULL_CONFIG, "MatchConfig е null")
		return result

	_validate_schema(config, result)
	_validate_mode(config, result)
	_validate_board_id(config, result)
	_validate_theme_and_campaign(config, result)
	_validate_seats(config, result)
	return result


## Само theme / campaign / modifiers (удобство за Match Setup UI).
static func are_theme_and_campaign_fields_valid(config: MatchConfig) -> bool:
	if config == null:
		return false
	var result := Result.new()
	_validate_mode(config, result)
	_validate_theme_and_campaign(config, result)
	return result.ok


static func _validate_schema(config: MatchConfig, result: Result) -> void:
	if not MatchConfig.is_schema_supported(config.schema_version):
		result.add_error(ERR_UNSUPPORTED_SCHEMA,
				"неподдържан schema_version %d (очакван %d)" % [
					config.schema_version, MatchConfig.SCHEMA_VERSION])


static func _validate_mode(config: MatchConfig, result: Result) -> void:
	if config.mode != MatchConfig.Mode.FREE_PLAY and config.mode != MatchConfig.Mode.CAMPAIGN:
		result.add_error(ERR_INVALID_MODE,
				"mode %d е извън [FREE_PLAY, CAMPAIGN]" % config.mode)


static func _validate_board_id(config: MatchConfig, result: Result) -> void:
	if config.board_id.is_empty():
		result.add_error(ERR_EMPTY_BOARD_ID, "board_id не може да е празен")


static func _validate_theme_and_campaign(config: MatchConfig, result: Result) -> void:
	if not ThemeId.is_valid(config.theme_id):
		result.add_error(ERR_INVALID_THEME,
				"непознат theme_id '%s'" % String(config.theme_id))

	if config.mode == MatchConfig.Mode.CAMPAIGN:
		if config.campaign_level_id.is_empty():
			result.add_error(ERR_CAMPAIGN_LEVEL_REQUIRED,
					"CAMPAIGN изисква непразен campaign_level_id")
	elif config.mode == MatchConfig.Mode.FREE_PLAY:
		if not config.campaign_level_id.is_empty():
			result.add_error(ERR_CAMPAIGN_LEVEL_FORBIDDEN,
					"FREE_PLAY не допуска campaign_level_id")

	for mod in config.level_modifiers:
		var mod_id := StringName(mod)
		if not LevelModifierId.is_valid(mod_id):
			result.add_error(ERR_INVALID_LEVEL_MODIFIER,
					"непознат level_modifier '%s'" % String(mod_id))


static func _validate_seats(config: MatchConfig, result: Result) -> void:
	if not MatchConfig.is_supported_seat_count(config.seats.size()):
		result.add_error(ERR_INVALID_SEAT_COUNT,
				"брой активни места %d не е в [%d, %d]" % [
					config.seats.size(), MatchConfig.MIN_SEATS, MatchConfig.MAX_SEATS])

	var ids_seen: Dictionary = {}
	for i in config.seats.size():
		var seat: MatchConfig.SeatConfig = config.seats[i]
		if seat == null or not seat.is_seat_valid():
			result.add_error(ERR_INVALID_SEAT,
					"невалидно място на индекс %d" % i)
			continue
		if seat.player_id in ids_seen:
			result.add_error(ERR_DUPLICATE_PLAYER_ID,
					"дублиран player_id '%s'" % String(seat.player_id))
		else:
			ids_seen[seat.player_id] = true

	# При 2 играчи се изискват срещуположни бази (docs/V1_GAME_DESIGN.md §3.3).
	if config.seats.size() == 2:
		var a: MatchConfig.SeatConfig = config.seats[0]
		var b: MatchConfig.SeatConfig = config.seats[1]
		if a != null and b != null:
			if not MatchConfig.are_opposite_seats(a.player_id, b.player_id):
				result.add_error(ERR_NON_OPPOSITE_SEATS,
						"2P изисква срещуположни бази (GREEN↔YELLOW или ORANGE↔CYAN)")
