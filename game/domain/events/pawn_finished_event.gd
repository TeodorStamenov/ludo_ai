class_name PawnFinishedEvent
extends DomainEvent
## Пионка е маркирана FINISHED на място в собствения ѝ home stretch (V1.1;
## docs/V1_ARCHITECTURE.md, §4.4 / §11; docs/V1_GAME_DESIGN.md, §3.1 / §3.2).
##
## Играчът прибира пионка веднага щом всичките му 4 пионки са влезли в
## home stretch (safe/exit/finish zone — 4-те цветни клетки преди центъра).
## Флаг-превключване БЕЗ движение: final_cell_id == from_cell_id — пионката
## остава на клетката, на която вече е стояла (FinishRules.resolve_home_stretch_completion).
## Никога не сочи към CellId.CENTER.
##
## Специализиран факт спрямо PawnMoved: FINISHED е чисто флаг-превключване,
## затова е отделно събитие, не PawnMoved с zone=FINISHED. Типична верига:
## PawnMoved (влизане в home stretch клетка) → … → PawnFinished (щом и 4-те
## са там) → PlayerRanked.
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "pawn_id" + "from_cell_id" + "final_cell_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_finished_dict.


## Прибраната пионка (PawnId); празен преди попълване.
var pawn_id: StringName = &""
## Home stretch клетката преди флага (CellId); празен преди попълване.
var from_cell_id: StringName = &""
## Клетката, на която пионката остава завинаги — идентична с from_cell_id
## (флаг-превключване без движение); празен преди попълване.
var final_cell_id: StringName = &""


func _init(
		p_pawn_id: StringName = &"",
		p_from_cell_id: StringName = &"",
		p_final_cell_id: StringName = &""
) -> void:
	pawn_id = p_pawn_id
	from_cell_id = p_from_cell_id
	final_cell_id = p_final_cell_id
	event_type = TYPE_PAWN_FINISHED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_finished(
		p_pawn_id: StringName,
		p_from_cell_id: StringName,
		p_final_cell_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnFinishedEvent:
	var event := PawnFinishedEvent.new(p_pawn_id, p_from_cell_id, p_final_cell_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от before/after PawnState — before в HOME_STRETCH, after FINISHED
## на СЪЩАТА клетка (флаг-превключване без движение).
## null, различни id, невалиден преход или движение → празен payload (невалиден факт).
static func create_from_states(
		before: PawnState,
		after: PawnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnFinishedEvent:
	if before == null or after == null or before.pawn_id != after.pawn_id:
		return create_finished(&"", &"", &"", p_command_sequence)
	if not before.is_in_home_stretch():
		return create_finished(&"", &"", &"", p_command_sequence)
	if not after.is_finished():
		return create_finished(&"", &"", &"", p_command_sequence)
	if before.cell_id != after.cell_id:
		return create_finished(&"", &"", &"", p_command_sequence)
	return create_finished(
			after.pawn_id,
			before.cell_id,
			after.cell_id,
			p_command_sequence)


## True ако envelope-ът е валиден, pawn_id / клетката е валидна и
## from_cell_id == final_cell_id (флаг-превключване без движение).
## Празен / неизвестен id → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	if not CellId.is_valid(from_cell_id):
		return false
	if not CellId.is_valid(final_cell_id):
		return false
	if from_cell_id != final_cell_id:
		return false
	return true


## PlayerId на прибраната пионка (от pawn_id).
func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


## JSON-safe Dictionary: envelope + pawn_id + from_cell_id + final_cell_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	data["from_cell_id"] = String(from_cell_id)
	data["final_cell_id"] = String(final_cell_id)
	return data


## Десериализация към PawnFinishedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_FINISHED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_finished_dict(data: Dictionary) -> PawnFinishedEvent:
	var event := PawnFinishedEvent.new(
			StringName(str(data.get("pawn_id", ""))),
			StringName(str(data.get("from_cell_id", ""))),
			StringName(str(data.get("final_cell_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PAWN_FINISHED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_finished_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PawnFinishedEvent):
		return false
	if not super.equals(other):
		return false
	var other_finished := other as PawnFinishedEvent
	return (
			pawn_id == other_finished.pawn_id
			and from_cell_id == other_finished.from_cell_id
			and final_cell_id == other_finished.final_cell_id
	)
