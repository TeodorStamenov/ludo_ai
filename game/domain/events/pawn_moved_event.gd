class_name PawnMovedEvent
extends DomainEvent
## Пионка е преместена от една клетка на друга (docs/V1_ARCHITECTURE.md, §4.4 / §6.2 / §11).
##
## Описва вече настъпил факт: MovePawnCommand е приет и GameEngine е изчислил
## дестинацията. Носи pawn_id, from_cell_id, to_cell_id и zone (след хода) —
## не намерение и не screen позиция.
##
## Presentation (BoardView / PawnView) получава събитието и анимира резултата;
## не мести пионка самостоятелно (§3 / §6.2).
##
## Едно движение може да е част от верига, напр.:
##   PawnMoved → GiftCollected → PowerUpResolved → PawnMoved → TurnChanged
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "pawn_id" + "from_cell_id"
##   + "to_cell_id" + "zone".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_moved_dict.


## Преместената пионка (PawnId); празен преди попълване.
var pawn_id: StringName = &""
## Клетка преди хода (CellId); празен преди попълване.
var from_cell_id: StringName = &""
## Клетка след хода (CellId); празен преди попълване.
var to_cell_id: StringName = &""
## Зона на пионката след хода (PawnZone); BASE по подразбиране преди попълване.
var zone: int = PawnZone.BASE


func _init(
		p_pawn_id: StringName = &"",
		p_from_cell_id: StringName = &"",
		p_to_cell_id: StringName = &"",
		p_zone: int = PawnZone.BASE
) -> void:
	pawn_id = p_pawn_id
	from_cell_id = p_from_cell_id
	to_cell_id = p_to_cell_id
	zone = p_zone
	event_type = TYPE_PAWN_MOVED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_moved(
		p_pawn_id: StringName,
		p_from_cell_id: StringName,
		p_to_cell_id: StringName,
		p_zone: int,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnMovedEvent:
	var event := PawnMovedEvent.new(p_pawn_id, p_from_cell_id, p_to_cell_id, p_zone)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от before/after PawnState — from = before.cell_id, to/zone = after.
## Изисква съвпадащ pawn_id; null или различни id → празен payload (невалиден факт).
static func create_from_states(
		before: PawnState,
		after: PawnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnMovedEvent:
	if before == null or after == null or before.pawn_id != after.pawn_id:
		return create_moved(&"", &"", &"", PawnZone.BASE, p_command_sequence)
	return create_moved(
			after.pawn_id,
			before.cell_id,
			after.cell_id,
			after.zone,
			p_command_sequence)


## True ако envelope-ът е валиден, pawn_id / клетките са валидни,
## zone е PawnZone, from ≠ to, и FINISHED сочи към CellId.CENTER.
## Празен / неизвестен id или невалидна зона → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	if not CellId.is_valid(from_cell_id):
		return false
	if not CellId.is_valid(to_cell_id):
		return false
	if not PawnZone.is_valid(zone):
		return false
	if from_cell_id == to_cell_id:
		return false
	if zone == PawnZone.FINISHED and to_cell_id != CellId.CENTER:
		return false
	return true


## PlayerId на преместената пионка (от pawn_id).
func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


## True ако след хода пионката е прибрана в центъра.
func is_finished() -> bool:
	return zone == PawnZone.FINISHED


## True ако след хода пионката е на общото трасе.
func is_on_main_path() -> bool:
	return zone == PawnZone.MAIN_PATH


## JSON-safe Dictionary: envelope + pawn_id + from/to cell_id + zone.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	data["from_cell_id"] = String(from_cell_id)
	data["to_cell_id"] = String(to_cell_id)
	data["zone"] = zone
	return data


## Десериализация към PawnMovedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_MOVED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_moved_dict(data: Dictionary) -> PawnMovedEvent:
	var event := PawnMovedEvent.new(
			StringName(str(data.get("pawn_id", ""))),
			StringName(str(data.get("from_cell_id", ""))),
			StringName(str(data.get("to_cell_id", ""))),
			int(data.get("zone", PawnZone.BASE)))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PAWN_MOVED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_moved_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PawnMovedEvent):
		return false
	if not super.equals(other):
		return false
	var other_moved := other as PawnMovedEvent
	return (
			pawn_id == other_moved.pawn_id
			and from_cell_id == other_moved.from_cell_id
			and to_cell_id == other_moved.to_cell_id
			and zone == other_moved.zone
	)
