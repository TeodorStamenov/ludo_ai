class_name GiftSpawnedEvent
extends DomainEvent
## Подарък се е появил на клетка от общото трасе
## (docs/V1_ARCHITECTURE.md, §4.4 / §4.7; docs/V1_GAME_DESIGN.md §4.1; #201-#205).
##
## Описва вече настъпил факт: GiftRules е избрал свободна клетка от main_loop
## (никога база/home stretch/център — #203) и е добавил GiftState в
## GameState.gifts[]. Носи gift_id и cell_id; съдържанието остава скрито до
## GiftCollectedEvent (§4.1: "Съдържанието на подаръка е скрито до взимането му").
##
## Presentation (GiftView) слуша това и появява затворената кутия на cell_id.


## Появилият се подарък (GiftId); празен преди попълване.
var gift_id: StringName = &""
## Клетката от main_loop, на която се появява (CellId); празна преди попълване.
var cell_id: StringName = &""


func _init(p_gift_id: StringName = &"", p_cell_id: StringName = &"") -> void:
	gift_id = p_gift_id
	cell_id = p_cell_id
	event_type = TYPE_GIFT_SPAWNED


## Фабрика с payload + envelope command_sequence.
static func create_spawned(
		p_gift_id: StringName,
		p_cell_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> GiftSpawnedEvent:
	var event := GiftSpawnedEvent.new(p_gift_id, p_cell_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от GiftState в момента на появяването.
static func create_from_state(
		gift: GiftState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> GiftSpawnedEvent:
	if gift == null:
		return create_spawned(&"", &"", p_command_sequence)
	return create_spawned(gift.gift_id, gift.cell_id, p_command_sequence)


## True ако envelope-ът е валиден, gift_id/cell_id са валидни, и клетката не е център.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not GiftId.is_valid(gift_id):
		return false
	if not CellId.is_valid(cell_id):
		return false
	return not CellId.is_center(cell_id)


## JSON-safe Dictionary: envelope + gift_id + cell_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["gift_id"] = String(gift_id)
	data["cell_id"] = String(cell_id)
	return data


## Десериализация към GiftSpawnedEvent. event_type винаги форсиран към TYPE_GIFT_SPAWNED.
static func from_spawned_dict(data: Dictionary) -> GiftSpawnedEvent:
	var event := GiftSpawnedEvent.new(
			StringName(str(data.get("gift_id", ""))),
			StringName(str(data.get("cell_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_GIFT_SPAWNED
	return event


func duplicate_event() -> DomainEvent:
	return from_spawned_dict(to_dict())


func equals(other: DomainEvent) -> bool:
	if other == null or not (other is GiftSpawnedEvent):
		return false
	if not super.equals(other):
		return false
	var other_spawned := other as GiftSpawnedEvent
	return gift_id == other_spawned.gift_id and cell_id == other_spawned.cell_id
