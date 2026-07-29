class_name GiftCollectedEvent
extends DomainEvent
## Пионка е спряла точно върху клетка с подарък и го е взела
## (docs/V1_ARCHITECTURE.md, §4.4 / §4.7; docs/V1_GAME_DESIGN.md §4.2; #204/#206).
##
## Описва вече настъпил факт: пионка е ЗАВЪРШИЛА ход точно на клетка с подарък
## (прескачането не взима — #204, гарантирано защото GameEngine проверява само
## финалната клетка след апликиран ход). Съдържанието (power_up_id) вече е
## изтеглено чрез RNG (§4.7 стъпка 3) — активацията е незабавна, без право на
## отказ (§4.2). Типична верига: PawnMoved → GiftCollected → PowerUpResolved → …


## Взетият подарък (GiftId); празен преди попълване.
var gift_id: StringName = &""
## Клетката, на която е стоял подаръкът (CellId); празна преди попълване.
var cell_id: StringName = &""
## Пионката, взела подаръка (PawnId); празна преди попълване.
var pawn_id: StringName = &""
## Изтегленото съдържание (PowerUpId); празно преди попълване.
var power_up_id: StringName = &""


func _init(
		p_gift_id: StringName = &"",
		p_cell_id: StringName = &"",
		p_pawn_id: StringName = &"",
		p_power_up_id: StringName = &""
) -> void:
	gift_id = p_gift_id
	cell_id = p_cell_id
	pawn_id = p_pawn_id
	power_up_id = p_power_up_id
	event_type = TYPE_GIFT_COLLECTED


## Фабрика с payload + envelope command_sequence.
static func create_collected(
		p_gift_id: StringName,
		p_cell_id: StringName,
		p_pawn_id: StringName,
		p_power_up_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> GiftCollectedEvent:
	var event := GiftCollectedEvent.new(p_gift_id, p_cell_id, p_pawn_id, p_power_up_id)
	event.command_sequence = p_command_sequence
	return event


## True ако envelope-ът е валиден и всички id-та (gift/cell/pawn/power-up) са валидни.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not GiftId.is_valid(gift_id):
		return false
	if not CellId.is_valid(cell_id) or CellId.is_center(cell_id):
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	return PowerUpId.is_valid(power_up_id)


func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


## JSON-safe Dictionary: envelope + gift_id + cell_id + pawn_id + power_up_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["gift_id"] = String(gift_id)
	data["cell_id"] = String(cell_id)
	data["pawn_id"] = String(pawn_id)
	data["power_up_id"] = String(power_up_id)
	return data


## Десериализация към GiftCollectedEvent. event_type форсиран към TYPE_GIFT_COLLECTED.
static func from_collected_dict(data: Dictionary) -> GiftCollectedEvent:
	var event := GiftCollectedEvent.new(
			StringName(str(data.get("gift_id", ""))),
			StringName(str(data.get("cell_id", ""))),
			StringName(str(data.get("pawn_id", ""))),
			StringName(str(data.get("power_up_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_GIFT_COLLECTED
	return event


func duplicate_event() -> DomainEvent:
	return from_collected_dict(to_dict())


func equals(other: DomainEvent) -> bool:
	if other == null or not (other is GiftCollectedEvent):
		return false
	if not super.equals(other):
		return false
	var o := other as GiftCollectedEvent
	return (
			gift_id == o.gift_id
			and cell_id == o.cell_id
			and pawn_id == o.pawn_id
			and power_up_id == o.power_up_id
	)
