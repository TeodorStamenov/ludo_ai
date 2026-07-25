class_name StartMatchCommand
extends GameCommand
## Стартира нов мач с дадена конфигурация (docs/V1_ARCHITECTURE.md, §4.3 / §5.1 / §11).
##
## Носи MatchConfig; GameEngine инициализира GameState от нея.
## Командата носи намерение (config), не резултат — без dice value / accepted / events.
##
## player_id обикновено е празен: стартът не е ход на конкретен seat.
## Match Setup и Campaign произвеждат един и същ MatchConfig и го подават тук (§16.7).
##
## Сериализация (journal / replay):
##   envelope полетата от GameCommand + "config" (MatchConfig.to_dict()).
##   GameCommand.from_dict не диспечира към този subclass — ползвай from_config_dict.

var config: MatchConfig = null


func _init(p_config: MatchConfig = null) -> void:
	config = p_config
	command_type = TYPE_START_MATCH


## Фабрика с MatchConfig + envelope. player_id остава празен (не е ход на seat).
## Отделно име от GameCommand.create — GDScript изисква съвпадаща сигнатура при override.
static func create_with_config(
		p_config: MatchConfig,
		p_match_id: StringName = &"",
		p_sequence: int = SEQUENCE_UNSET,
		p_auth_token: String = ""
) -> StartMatchCommand:
	var cmd := StartMatchCommand.new(p_config)
	cmd.match_id = p_match_id
	cmd.sequence = p_sequence
	cmd.auth_token = p_auth_token
	return cmd


## True ако envelope-ът е валиден и config е не-null валиден MatchConfig.
## Null / невалиден config → false (командата не е готова за apply).
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if config == null:
		return false
	return config.is_valid()


## JSON-safe Dictionary: envelope + вложен config payload.
## Липсващ config → празен Dictionary (round-trip → null config).
func to_dict() -> Dictionary:
	var data := super.to_dict()
	if config != null:
		data["config"] = config.to_dict()
	else:
		data["config"] = {}
	return data


## Десериализация към StartMatchCommand. Липсващ/празен config → null.
## command_type винаги се форсира към TYPE_START_MATCH.
## Отделно от GameCommand.from_dict (което не диспечира към subclass).
static func from_config_dict(data: Dictionary) -> StartMatchCommand:
	var cmd := StartMatchCommand.new(null)
	cmd.match_id = StringName(str(data.get("match_id", "")))
	cmd.player_id = StringName(str(data.get("player_id", "")))
	cmd.sequence = int(data.get("sequence", SEQUENCE_UNSET))
	cmd.auth_token = str(data.get("auth_token", ""))
	cmd.command_type = TYPE_START_MATCH
	var cfg_data = data.get("config", {})
	if cfg_data is Dictionary and not (cfg_data as Dictionary).is_empty():
		cmd.config = MatchConfig.from_dict(cfg_data)
	else:
		cmd.config = null
	return cmd


## Дълбоко копие през сериализация — без споделена референция към MatchConfig.
func duplicate_command() -> GameCommand:
	return from_config_dict(to_dict())


## True ако envelope и MatchConfig payload съвпадат.
func equals(other: GameCommand) -> bool:
	if other == null or not (other is StartMatchCommand):
		return false
	if not super.equals(other):
		return false
	var other_start := other as StartMatchCommand
	if config == null and other_start.config == null:
		return true
	if config == null or other_start.config == null:
		return false
	return config.equals(other_start.config)
