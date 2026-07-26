class_name PawnFinishedEvent
extends DomainEvent
## Пионка е прибрана в центъра (docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 / §3.2 — точен зар от home stretch).
##
## Описва вече настъпил факт: MovePawnCommand е приет и GameEngine е преместил
## пионката от HOME_STRETCH в FINISHED (cell_id = CellId.CENTER). Носи pawn_id,
## from_cell_id (последната home клетка) и center_cell_id — не намерение и не
## screen позиция.
##
## Специализиран факт спрямо PawnMoved: прибирането може да се анимира отделно
## (BoardView / PawnView). Presentation не директно решава дали finish е валиден
## (§3 / §6.2). Типична верига: PawnMoved → PawnFinished → … / PlayerRanked.
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "pawn_id" + "from_cell_id" + "center_cell_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_finished_dict.


## Пионката, която е прибрана (PawnId); празен преди попълване.
var pawn_id: StringName = &""
## Клетка в home stretch преди прибирането (CellId); празен преди попълване.
var from_cell_id: StringName = &""
## Централната клетка след прибирането (CellId); валидният факт сочи към CellId.CENTER.
var center_cell_id: StringName = &""


func _init(
		p_pawn_id: StringName = &"",
		p_from_cell_id: StringName = &"",
		p_center_cell_id: StringName = &""
) -> void:
	pawn_id = p_pawn_id
	from_cell_id = p_from_cell_id
	center_cell_id = p_center_cell_id
	event_type = TYPE_PAWN_FINISHED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_finished(
		p_pawn_id: StringName,
		p_from_cell_id: StringName,
		p_center_cell_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnFinishedEvent:
	var event := PawnFinishedEvent.new(p_pawn_id, p_from_cell_id, p_center_cell_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от before/after PawnState — from = before.cell_id, center = after.cell_id.
## Изисква съвпадащ pawn_id, before в HOME_STRETCH и after в FINISHED (център).
## null, различни id или невалиден преход → празен payload (невалиден факт).
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
	return create_finished(
			after.pawn_id,
			before.cell_id,
			after.cell_id,
			p_command_sequence)


## True ако envelope-ът е валиден, pawn_id / клетките са валидни,
## center е CellId.CENTER и from ≠ center.
## Празен / неизвестен id → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	if not CellId.is_valid(from_cell_id):
		return false
	if not CellId.is_valid(center_cell_id):
		return false
	if center_cell_id != CellId.CENTER:
		return false
	if from_cell_id == center_cell_id:
		return false
	return true


## PlayerId на прибраната пионка (от pawn_id).
func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


## JSON-safe Dictionary: envelope + pawn_id + from_cell_id + center_cell_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	data["from_cell_id"] = String(from_cell_id)
	data["center_cell_id"] = String(center_cell_id)
	return data


## Десериализация към PawnFinishedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_FINISHED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_finished_dict(data: Dictionary) -> PawnFinishedEvent:
	var event := PawnFinishedEvent.new(
			StringName(str(data.get("pawn_id", ""))),
			StringName(str(data.get("from_cell_id", ""))),
			StringName(str(data.get("center_cell_id", ""))))
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
			and center_cell_id == other_finished.center_cell_id
	)
