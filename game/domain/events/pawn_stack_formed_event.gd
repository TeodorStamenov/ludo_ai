class_name PawnStackFormedEvent
extends DomainEvent
## Две собствени пионки образуват купчина на клетка (docs/V1_ARCHITECTURE.md,
## §4.4 / §11; docs/V1_GAME_DESIGN.md, §3.2).
##
## Описва вече настъпил факт: MovePawnCommand е приет, GameEngine е открил, че
## пристигащата пионка е застанала върху друга своя на MAIN_PATH и е образувана
## купчина от 2 (имунна срещу взимане). Носи cell_id, arriving_pawn_id и
## resident_pawn_id — не намерение и не screen позиция.
##
## Типична верига: PawnMoved → PawnStackFormed → …
## (клетъчният ход остава в PawnMoved; тук е самият факт „купчина“.)
##
## Presentation (BoardView / PawnView) получава събитието и анимира stack;
## не решава дали купчината е валидна (§3 / §6.2).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "cell_id" + "arriving_pawn_id"
##   + "resident_pawn_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_stack_formed_dict.


## Клетката, на която е образувана купчината (CellId); празен преди попълване.
var cell_id: StringName = &""
## Пионката, която току-що е стъпила върху клетката (PawnId); празен преди попълване.
var arriving_pawn_id: StringName = &""
## Пионката, която вече е била на клетката (PawnId); празен преди попълване.
var resident_pawn_id: StringName = &""


func _init(
		p_cell_id: StringName = &"",
		p_arriving_pawn_id: StringName = &"",
		p_resident_pawn_id: StringName = &""
) -> void:
	cell_id = p_cell_id
	arriving_pawn_id = p_arriving_pawn_id
	resident_pawn_id = p_resident_pawn_id
	event_type = TYPE_PAWN_STACK_FORMED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_stack_formed(
		p_cell_id: StringName,
		p_arriving_pawn_id: StringName,
		p_resident_pawn_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnStackFormedEvent:
	var event := PawnStackFormedEvent.new(
			p_cell_id, p_arriving_pawn_id, p_resident_pawn_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от PawnState в момента на образуване — и двете на една MAIN_PATH клетка,
## един и същ играч, различни пионки. null, съвпадащи id, различен играч/клетка
## или не-MAIN_PATH → празен payload (невалиден факт).
static func create_from_states(
		arriving: PawnState,
		resident: PawnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnStackFormedEvent:
	if arriving == null or resident == null:
		return create_stack_formed(&"", &"", &"", p_command_sequence)
	if arriving.pawn_id == resident.pawn_id:
		return create_stack_formed(&"", &"", &"", p_command_sequence)
	if PawnId.get_player_id(arriving.pawn_id) != PawnId.get_player_id(resident.pawn_id):
		return create_stack_formed(&"", &"", &"", p_command_sequence)
	if arriving.cell_id != resident.cell_id:
		return create_stack_formed(&"", &"", &"", p_command_sequence)
	if not arriving.is_on_main_path() or not resident.is_on_main_path():
		return create_stack_formed(&"", &"", &"", p_command_sequence)
	return create_stack_formed(
			arriving.cell_id,
			arriving.pawn_id,
			resident.pawn_id,
			p_command_sequence)


## True ако envelope-ът е валиден, cell_id е валиден, и двете pawn_id са валидни,
## различни и принадлежат на един и същ играч (купчина е само от свои).
## Празен / неизвестен id или различен играч → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not CellId.is_valid(cell_id):
		return false
	if not PawnId.is_valid(arriving_pawn_id):
		return false
	if not PawnId.is_valid(resident_pawn_id):
		return false
	if arriving_pawn_id == resident_pawn_id:
		return false
	if get_player_id() != PawnId.get_player_id(resident_pawn_id):
		return false
	return true


## PlayerId на купчината (от arriving_pawn_id; съвпада с resident при валиден факт).
func get_player_id() -> StringName:
	return PawnId.get_player_id(arriving_pawn_id)


## JSON-safe Dictionary: envelope + cell_id + arriving_pawn_id + resident_pawn_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["cell_id"] = String(cell_id)
	data["arriving_pawn_id"] = String(arriving_pawn_id)
	data["resident_pawn_id"] = String(resident_pawn_id)
	return data


## Десериализация към PawnStackFormedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_STACK_FORMED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_stack_formed_dict(data: Dictionary) -> PawnStackFormedEvent:
	var event := PawnStackFormedEvent.new(
			StringName(str(data.get("cell_id", ""))),
			StringName(str(data.get("arriving_pawn_id", ""))),
			StringName(str(data.get("resident_pawn_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PAWN_STACK_FORMED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_stack_formed_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PawnStackFormedEvent):
		return false
	if not super.equals(other):
		return false
	var other_stack := other as PawnStackFormedEvent
	return (
			cell_id == other_stack.cell_id
			and arriving_pawn_id == other_stack.arriving_pawn_id
			and resident_pawn_id == other_stack.resident_pawn_id
	)
