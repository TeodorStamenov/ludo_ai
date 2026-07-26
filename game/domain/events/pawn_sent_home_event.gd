class_name PawnSentHomeEvent
extends DomainEvent
## Пионка е върната в базата си (docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1).
##
## Описва вече настъпил факт: след capture (или ефект, който връща вкъщи)
## GameEngine е поставил пионката в свободна base клетка. Носи pawn_id,
## from_cell_id (където е била) и base_cell_id — не намерение и не screen позиция.
##
## Отделен факт от PawnCaptured (кой кого е взел). Типична верига:
##   PawnMoved → PawnCaptured → PawnSentHome → …
##
## Presentation (BoardView / PawnView) анимира меко „прибиране вкъщи“;
## не решава дали връщането е валидно (§3 / §6.2).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "pawn_id" + "from_cell_id" + "base_cell_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_sent_home_dict.


## Пионката, върната в базата (PawnId); празен преди попълване.
var pawn_id: StringName = &""
## Клетка преди връщането (CellId); празен преди попълване.
var from_cell_id: StringName = &""
## Base клетката след връщането (CellId); празен преди попълване.
var base_cell_id: StringName = &""


func _init(
		p_pawn_id: StringName = &"",
		p_from_cell_id: StringName = &"",
		p_base_cell_id: StringName = &""
) -> void:
	pawn_id = p_pawn_id
	from_cell_id = p_from_cell_id
	base_cell_id = p_base_cell_id
	event_type = TYPE_PAWN_SENT_HOME


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_sent_home(
		p_pawn_id: StringName,
		p_from_cell_id: StringName,
		p_base_cell_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnSentHomeEvent:
	var event := PawnSentHomeEvent.new(p_pawn_id, p_from_cell_id, p_base_cell_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от before/after PawnState — from = before.cell_id, base = after.cell_id.
## Изисква съвпадащ pawn_id, before на дъската и after в BASE.
## null, различни id или невалиден преход → празен payload (невалиден факт).
static func create_from_states(
		before: PawnState,
		after: PawnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnSentHomeEvent:
	if before == null or after == null or before.pawn_id != after.pawn_id:
		return create_sent_home(&"", &"", &"", p_command_sequence)
	if not before.is_on_board():
		return create_sent_home(&"", &"", &"", p_command_sequence)
	if not after.is_in_base():
		return create_sent_home(&"", &"", &"", p_command_sequence)
	return create_sent_home(
			after.pawn_id,
			before.cell_id,
			after.cell_id,
			p_command_sequence)


## True ако envelope-ът е валиден, pawn_id / клетките са валидни и from ≠ base.
## Празен / неизвестен id → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	if not CellId.is_valid(from_cell_id):
		return false
	if not CellId.is_valid(base_cell_id):
		return false
	if from_cell_id == base_cell_id:
		return false
	return true


## PlayerId на върнатата пионка (от pawn_id).
func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


## JSON-safe Dictionary: envelope + pawn_id + from_cell_id + base_cell_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	data["from_cell_id"] = String(from_cell_id)
	data["base_cell_id"] = String(base_cell_id)
	return data


## Десериализация към PawnSentHomeEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_SENT_HOME.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_sent_home_dict(data: Dictionary) -> PawnSentHomeEvent:
	var event := PawnSentHomeEvent.new(
			StringName(str(data.get("pawn_id", ""))),
			StringName(str(data.get("from_cell_id", ""))),
			StringName(str(data.get("base_cell_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PAWN_SENT_HOME
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_sent_home_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PawnSentHomeEvent):
		return false
	if not super.equals(other):
		return false
	var other_sent := other as PawnSentHomeEvent
	return (
			pawn_id == other_sent.pawn_id
			and from_cell_id == other_sent.from_cell_id
			and base_cell_id == other_sent.base_cell_id
	)
