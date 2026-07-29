class_name PowerUpResolvedEvent
extends DomainEvent
## Power-up ефект е разрешен (docs/V1_ARCHITECTURE.md, §4.4 / §4.7; #207).
##
## Описва вече настъпил факт: PowerUpRegistry.resolver_for(power_up_id) е
## изпълнил ефекта (GameEngine._resolve_gift_pickup_if_any). Носи power_up_id,
## triggering_pawn_id и resolved_event_count — брой вторични domain events,
## произведени от самия ефект (те вече са добавени поотделно в основния
## events масив; тук е само summary marker за presentation/HUD).
##
## Типична верига: PawnMoved → GiftCollected → [ефектни събития] → PowerUpResolved → …


## Пионката, взела подаръка и задействала ефекта (PawnId); празна преди попълване.
var triggering_pawn_id: StringName = &""
## Разрешеният ефект (PowerUpId); празен преди попълване.
var power_up_id: StringName = &""
## Брой вторични събития, произведени от самия ефект (0 е валидно — напр. Shield
## не движи пионки).
var resolved_event_count: int = 0


func _init(
		p_power_up_id: StringName = &"",
		p_triggering_pawn_id: StringName = &"",
		p_resolved_event_count: int = 0
) -> void:
	power_up_id = p_power_up_id
	triggering_pawn_id = p_triggering_pawn_id
	resolved_event_count = p_resolved_event_count
	event_type = TYPE_POWER_UP_RESOLVED


## Фабрика с payload + envelope command_sequence.
static func create_resolved(
		p_power_up_id: StringName,
		p_triggering_pawn_id: StringName,
		p_resolved_event_count: int,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PowerUpResolvedEvent:
	var event := PowerUpResolvedEvent.new(
			p_power_up_id, p_triggering_pawn_id, p_resolved_event_count)
	event.command_sequence = p_command_sequence
	return event


## True ако envelope-ът е валиден, power_up_id/triggering_pawn_id са валидни
## и resolved_event_count не е отрицателен.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PowerUpId.is_valid(power_up_id):
		return false
	if not PawnId.is_valid(triggering_pawn_id):
		return false
	return resolved_event_count >= 0


func get_player_id() -> StringName:
	return PawnId.get_player_id(triggering_pawn_id)


## JSON-safe Dictionary: envelope + power_up_id + triggering_pawn_id + resolved_event_count.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["power_up_id"] = String(power_up_id)
	data["triggering_pawn_id"] = String(triggering_pawn_id)
	data["resolved_event_count"] = resolved_event_count
	return data


## Десериализация към PowerUpResolvedEvent. event_type форсиран към TYPE_POWER_UP_RESOLVED.
static func from_resolved_dict(data: Dictionary) -> PowerUpResolvedEvent:
	var event := PowerUpResolvedEvent.new(
			StringName(str(data.get("power_up_id", ""))),
			StringName(str(data.get("triggering_pawn_id", ""))),
			int(data.get("resolved_event_count", 0)))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_POWER_UP_RESOLVED
	return event


func duplicate_event() -> DomainEvent:
	return from_resolved_dict(to_dict())


func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PowerUpResolvedEvent):
		return false
	if not super.equals(other):
		return false
	var o := other as PowerUpResolvedEvent
	return (
			power_up_id == o.power_up_id
			and triggering_pawn_id == o.triggering_pawn_id
			and resolved_event_count == o.resolved_event_count
	)
