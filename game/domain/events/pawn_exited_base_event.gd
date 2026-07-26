class_name PawnExitedBaseEvent
extends DomainEvent
## Пионка е излязла от базата на spawn клетката (docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/CURRENT_YELLOW_BEHAVIOR.md, YEL-030).
##
## Описва вече настъпил факт: MovePawnCommand е приет при зар 6 и GameEngine е
## преместил пионката от BASE към MAIN_PATH на spawn (path_index = 0).
## Носи pawn_id, from_cell_id (база) и spawn_cell_id — не намерение и не screen позиция.
##
## Специализиран факт спрямо PawnMoved: излизането от базата може да се анимира
## отделно (BoardView / PawnView). Presentation не мести пионка самостоятелно (§3 / §6.2).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "pawn_id" + "from_cell_id" + "spawn_cell_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_exited_dict.


## Пионката, която е излязла (PawnId); празен преди попълване.
var pawn_id: StringName = &""
## Клетка в базата преди излизането (CellId); празен преди попълване.
var from_cell_id: StringName = &""
## Spawn клетката след излизането (CellId); празен преди попълване.
var spawn_cell_id: StringName = &""


func _init(
		p_pawn_id: StringName = &"",
		p_from_cell_id: StringName = &"",
		p_spawn_cell_id: StringName = &""
) -> void:
	pawn_id = p_pawn_id
	from_cell_id = p_from_cell_id
	spawn_cell_id = p_spawn_cell_id
	event_type = TYPE_PAWN_EXITED_BASE


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_exited(
		p_pawn_id: StringName,
		p_from_cell_id: StringName,
		p_spawn_cell_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnExitedBaseEvent:
	var event := PawnExitedBaseEvent.new(p_pawn_id, p_from_cell_id, p_spawn_cell_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от before/after PawnState — from = before.cell_id, spawn = after.cell_id.
## Изисква съвпадащ pawn_id, before в BASE и after на spawn (MAIN_PATH, path_index 0).
## null, различни id или невалиден преход → празен payload (невалиден факт).
static func create_from_states(
		before: PawnState,
		after: PawnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnExitedBaseEvent:
	if before == null or after == null or before.pawn_id != after.pawn_id:
		return create_exited(&"", &"", &"", p_command_sequence)
	if not before.is_in_base():
		return create_exited(&"", &"", &"", p_command_sequence)
	if not after.is_on_main_path() or after.path_index != PawnState.PATH_INDEX_AT_SPAWN:
		return create_exited(&"", &"", &"", p_command_sequence)
	return create_exited(
			after.pawn_id,
			before.cell_id,
			after.cell_id,
			p_command_sequence)


## True ако envelope-ът е валиден, pawn_id / клетките са валидни и from ≠ spawn.
## Празен / неизвестен id → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	if not CellId.is_valid(from_cell_id):
		return false
	if not CellId.is_valid(spawn_cell_id):
		return false
	if from_cell_id == spawn_cell_id:
		return false
	return true


## PlayerId на излязлата пионка (от pawn_id).
func get_player_id() -> StringName:
	return PawnId.get_player_id(pawn_id)


## JSON-safe Dictionary: envelope + pawn_id + from_cell_id + spawn_cell_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	data["from_cell_id"] = String(from_cell_id)
	data["spawn_cell_id"] = String(spawn_cell_id)
	return data


## Десериализация към PawnExitedBaseEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_EXITED_BASE.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_exited_dict(data: Dictionary) -> PawnExitedBaseEvent:
	var event := PawnExitedBaseEvent.new(
			StringName(str(data.get("pawn_id", ""))),
			StringName(str(data.get("from_cell_id", ""))),
			StringName(str(data.get("spawn_cell_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PAWN_EXITED_BASE
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_exited_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PawnExitedBaseEvent):
		return false
	if not super.equals(other):
		return false
	var other_exited := other as PawnExitedBaseEvent
	return (
			pawn_id == other_exited.pawn_id
			and from_cell_id == other_exited.from_cell_id
			and spawn_cell_id == other_exited.spawn_cell_id
	)
