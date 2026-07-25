class_name DiceRolledEvent
extends DomainEvent
## Изхвърлен е зар с конкретна стойност (docs/V1_ARCHITECTURE.md, §4.4 / §6.4 / §11).
##
## Описва вече настъпил факт: RollDiceCommand е приет и GameEngine е генерирал
## резултата чрез авторитетния RNG. Носи player_id и value — не намерение.
##
## Presentation (DiceView) получава резултата оттук и проиграва анимация;
## не генерира gameplay случайността (§6.4).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "player_id" + "value".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_rolled_dict.


## Играчът, хвърлил зара (PlayerId); празен преди попълване.
var player_id: StringName = &""
## Хвърлен резултат 1–6; DiceState.VALUE_NONE (0) преди попълване / изчистен.
var value: int = DiceState.VALUE_NONE


func _init(p_player_id: StringName = &"", p_value: int = DiceState.VALUE_NONE) -> void:
	player_id = p_player_id
	value = p_value
	event_type = TYPE_DICE_ROLLED


## Фабрика с player_id + value + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_rolled(
		p_player_id: StringName,
		p_value: int,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> DiceRolledEvent:
	var event := DiceRolledEvent.new(p_player_id, p_value)
	event.command_sequence = p_command_sequence
	return event


## True ако envelope-ът е валиден, player_id е валиден PlayerId
## и value е лице на зара 1–6 (DiceState.is_face_value).
## Празен / неизвестен player_id или VALUE_NONE / извън 1–6 → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PlayerId.is_valid(player_id):
		return false
	return DiceState.is_face_value(value)


## True ако хвърлянето е 6 (излизане от база + допълнителен ход).
func is_six() -> bool:
	return value == DiceState.EXTRA_TURN_VALUE


## JSON-safe Dictionary: envelope + player_id + value.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["player_id"] = String(player_id)
	data["value"] = value
	return data


## Десериализация към DiceRolledEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_DICE_ROLLED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_rolled_dict(data: Dictionary) -> DiceRolledEvent:
	var event := DiceRolledEvent.new(
			StringName(str(data.get("player_id", ""))),
			int(data.get("value", DiceState.VALUE_NONE)))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_DICE_ROLLED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_rolled_dict(to_dict())


## True ако envelope, player_id и value съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is DiceRolledEvent):
		return false
	if not super.equals(other):
		return false
	var other_rolled := other as DiceRolledEvent
	return player_id == other_rolled.player_id and value == other_rolled.value
