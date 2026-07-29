class_name ShieldAppliedEvent
extends DomainEvent
## Пионка получава щит: не може да бъде взета до началото на следващия ход на
## притежателя (docs/V1_ARCHITECTURE.md §4.4; docs/V1_GAME_DESIGN.md §4.3; #209).
##
## turns=1 е базовата продължителност: TurnRules._tick_owner_shields намалява
## shield_turns_remaining с 1 всеки път, когато стане ред на притежателя —
## щитът изтича точно преди AWAITING_ROLL на следващия негов собствен ход.
## Animal passive (Кокошка) може да удължи (ModifierPipeline.modify_shield_duration).


var pawn_id: StringName = &""
var turns: int = 0


func _init(p_pawn_id: StringName = &"", p_turns: int = 0) -> void:
	pawn_id = p_pawn_id
	turns = p_turns
	event_type = TYPE_SHIELD_APPLIED


static func create_applied(
		p_pawn_id: StringName,
		p_turns: int,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> ShieldAppliedEvent:
	var event := ShieldAppliedEvent.new(p_pawn_id, p_turns)
	event.command_sequence = p_command_sequence
	return event


func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	return turns > 0


func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	data["turns"] = turns
	return data


static func from_applied_dict(data: Dictionary) -> ShieldAppliedEvent:
	var event := ShieldAppliedEvent.new(
			StringName(str(data.get("pawn_id", ""))),
			int(data.get("turns", 0)))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_SHIELD_APPLIED
	return event


func duplicate_event() -> DomainEvent:
	return from_applied_dict(to_dict())


func equals(other: DomainEvent) -> bool:
	if other == null or not (other is ShieldAppliedEvent):
		return false
	if not super.equals(other):
		return false
	var o := other as ShieldAppliedEvent
	return pawn_id == o.pawn_id and turns == o.turns
