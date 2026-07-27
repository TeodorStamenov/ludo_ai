class_name GameCommand
extends RefCounted
## Базов клас за всички команди към GameEngine
## (docs/V1_ARCHITECTURE.md, §4.3 / §11 / §16.3).
##
## Командата носи намерение, но не резултат.
## Например клиентът не изпраща „зарът е 6“, а RollDiceCommand;
## резултатът се генерира от авторитетния RNG в GameEngine.
##
## Envelope полета (§11) — общи за всяка команда:
##   match_id, player_id, sequence — валидация / replay / divergence
##   auth_token — резервирано за v2 multiplayer (празен във v1)
##   command_type — дискриминатор за сериализация / journal
##
## Конкретни имплементации:
##   - StartMatchCommand  (commands/start_match_command.gd)
##   - RollDiceCommand    (commands/roll_dice_command.gd)
##   - MovePawnCommand    (commands/move_pawn_command.gd)
##
## Domain не използва Node / Vector2 / NodePath. Presentation и controllers
## създават командата; GameState.stamp_command() попълва match_id + sequence.

## Sequence преди stamp / преди първа приета команда (виж GameState.COMMAND_SEQUENCE_START).
const SEQUENCE_UNSET: int = 0

## Известни command_type стойности (подкласовете ги задават; base остава празен).
const TYPE_START_MATCH: StringName = &"StartMatch"
const TYPE_ROLL_DICE: StringName = &"RollDice"
const TYPE_MOVE_PAWN: StringName = &"MovePawn"


## Мач, към който е насочена командата (MatchId); празен преди stamp.
var match_id: StringName = &""
## Играчът, изпратил намерението (PlayerId); може да е празен (напр. StartMatch).
var player_id: StringName = &""
## Пореден номер в мача; SEQUENCE_UNSET преди stamp; след stamp ≥ 1.
var sequence: int = SEQUENCE_UNSET
## Резерв за v2 auth; във v1 винаги празен низ.
var auth_token: String = ""
## Дискриминатор на типа команда (TYPE_*); празен за чист базов инстанс.
var command_type: StringName = &""


## Фабрика за пълно конфигуриран базов envelope (без subclass payload).
static func create(
		p_match_id: StringName = &"",
		p_player_id: StringName = &"",
		p_sequence: int = SEQUENCE_UNSET,
		p_command_type: StringName = &"",
		p_auth_token: String = ""
) -> GameCommand:
	var cmd := GameCommand.new()
	cmd.match_id = p_match_id
	cmd.player_id = p_player_id
	cmd.sequence = p_sequence
	cmd.command_type = p_command_type
	cmd.auth_token = p_auth_token
	return cmd


## True ако командата вече е stamp-ната с match envelope (match_id + sequence ≥ 1).
func is_stamped() -> bool:
	return match_id != &"" and sequence > SEQUENCE_UNSET


## Задава envelope полетата (използва се от Application / тестове; GameState.stamp_command
## задава match_id + sequence от текущия state).
func stamp(p_match_id: StringName, p_sequence: int) -> void:
	match_id = p_match_id
	sequence = p_sequence


## True ако полетата са в договорните self-contained граници (§4.3 / §11).
## Невалиден/отрицателен sequence, счупен match_id или player_id → false.
## Празен envelope (преди stamp) е валиден — командата носи само намерение.
func is_valid() -> bool:
	if sequence < SEQUENCE_UNSET:
		return false
	if match_id != &"" and not MatchId.is_valid(match_id):
		return false
	if player_id != &"" and not PlayerId.is_valid(player_id):
		return false
	return true


## JSON-safe Dictionary: StringName → String. Без Vector2 / NodePath / dice result.
func to_dict() -> Dictionary:
	return {
		"match_id": String(match_id),
		"player_id": String(player_id),
		"sequence": sequence,
		"auth_token": auth_token,
		"command_type": String(command_type),
	}


## Десериализация на базовия envelope. Липсващи полета → подразбиращи се стойности.
## Не диспечира към subclass — това е отговорност на GameplayJournal.command_from_dict.
static func from_dict(data: Dictionary) -> GameCommand:
	var cmd := GameCommand.new()
	cmd.match_id = StringName(str(data.get("match_id", "")))
	cmd.player_id = StringName(str(data.get("player_id", "")))
	cmd.sequence = int(data.get("sequence", SEQUENCE_UNSET))
	cmd.auth_token = str(data.get("auth_token", ""))
	cmd.command_type = StringName(str(data.get("command_type", "")))
	return cmd


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_command() -> GameCommand:
	return from_dict(to_dict())


## True ако всички сериализируеми envelope полета съвпадат.
func equals(other: GameCommand) -> bool:
	if other == null:
		return false
	return (
			match_id == other.match_id
			and player_id == other.player_id
			and sequence == other.sequence
			and auth_token == other.auth_token
			and command_type == other.command_type
	)
