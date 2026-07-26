class_name RollDiceCommand
extends GameCommand
## Заявка за хвърляне на зара от даден играч (docs/V1_ARCHITECTURE.md, §4.3 / §11).
##
## Носи player_id (намерение); GameEngine генерира резултата чрез инжектирания
## RandomSource. Клиентът не изпраща „зарът е 6“ — само RollDiceCommand.
##
## Валидно само в TurnState.AWAITING_ROLL за активния играч (валидацията на фазата
## е в GameEngine; тук се проверява self-contained форматът на командата).
##
## Сериализация (journal / replay):
##   само envelope полетата от GameCommand (няма допълнителен payload).
##   GameCommand.from_dict не диспечира към този subclass — ползвай from_roll_dict.


func _init(p_player_id: StringName = &"") -> void:
	player_id = p_player_id
	command_type = TYPE_ROLL_DICE


## Фабрика с player_id + envelope. Отделно име от GameCommand.create —
## GDScript изисква съвпадаща сигнатура при override.
static func create_for_player(
		p_player_id: StringName,
		p_match_id: StringName = &"",
		p_sequence: int = SEQUENCE_UNSET,
		p_auth_token: String = ""
) -> RollDiceCommand:
	var cmd := RollDiceCommand.new(p_player_id)
	cmd.match_id = p_match_id
	cmd.sequence = p_sequence
	cmd.auth_token = p_auth_token
	return cmd


## True ако envelope-ът е валиден и player_id е непразен валиден PlayerId.
## Празен / неизвестен player_id → false (хвърлянето винаги е ход на seat).
func is_valid() -> bool:
	if not super.is_valid():
		return false
	return PlayerId.is_valid(player_id)


## JSON-safe Dictionary: само envelope (без dice value / result).
func to_dict() -> Dictionary:
	return super.to_dict()


## Десериализация към RollDiceCommand. command_type винаги се форсира към TYPE_ROLL_DICE.
## Отделно от GameCommand.from_dict (което не диспечира към subclass).
static func from_roll_dict(data: Dictionary) -> RollDiceCommand:
	var cmd := RollDiceCommand.new(StringName(str(data.get("player_id", ""))))
	cmd.match_id = StringName(str(data.get("match_id", "")))
	cmd.sequence = int(data.get("sequence", SEQUENCE_UNSET))
	cmd.auth_token = str(data.get("auth_token", ""))
	cmd.command_type = TYPE_ROLL_DICE
	return cmd


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_command() -> GameCommand:
	return from_roll_dict(to_dict())


## True ако envelope полетата съвпадат и other е RollDiceCommand.
func equals(other: GameCommand) -> bool:
	if other == null or not (other is RollDiceCommand):
		return false
	return super.equals(other)
