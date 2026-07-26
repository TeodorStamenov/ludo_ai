class_name PawnCapturedEvent
extends DomainEvent
## Противникова пионка е взета при стъпване върху нея (docs/V1_ARCHITECTURE.md,
## §4.4 / §11; docs/V1_GAME_DESIGN.md, §3.1).
##
## Описва вече настъпил факт: MovePawnCommand е приет, GameEngine е открил
## единична незащитена противникова пионка на дестинацията и е приложил capture.
## Носи capturing_pawn_id и captured_pawn_id — не намерение и не screen позиция.
##
## Клетката на взимането идва от предшестващия PawnMoved (to_cell_id);
## връщането в базата е отделен факт (PawnSentHome).
## Типична верига: PawnMoved → PawnCaptured → PawnSentHome → …
##
## Presentation (BoardView / PawnView) получава събитието и анимира меко
## „прибиране вкъщи“; не решава дали capture е валиден (§3 / §6.2).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "capturing_pawn_id" + "captured_pawn_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_captured_dict.


## Пионката, която е извършила взимането (PawnId); празен преди попълване.
var capturing_pawn_id: StringName = &""
## Взетата противникова пионка (PawnId); празен преди попълване.
var captured_pawn_id: StringName = &""


func _init(
		p_capturing_pawn_id: StringName = &"",
		p_captured_pawn_id: StringName = &""
) -> void:
	capturing_pawn_id = p_capturing_pawn_id
	captured_pawn_id = p_captured_pawn_id
	event_type = TYPE_PAWN_CAPTURED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_captured(
		p_capturing_pawn_id: StringName,
		p_captured_pawn_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnCapturedEvent:
	var event := PawnCapturedEvent.new(p_capturing_pawn_id, p_captured_pawn_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от PawnState в момента на взимането — и двете на една клетка на MAIN_PATH,
## различни играчи. null, съвпадащи id/играч, различна клетка или не-MAIN_PATH
## → празен payload (невалиден факт).
static func create_from_states(
		capturing: PawnState,
		captured: PawnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PawnCapturedEvent:
	if capturing == null or captured == null:
		return create_captured(&"", &"", p_command_sequence)
	if capturing.pawn_id == captured.pawn_id:
		return create_captured(&"", &"", p_command_sequence)
	if PawnId.get_player_id(capturing.pawn_id) == PawnId.get_player_id(captured.pawn_id):
		return create_captured(&"", &"", p_command_sequence)
	if capturing.cell_id != captured.cell_id:
		return create_captured(&"", &"", p_command_sequence)
	if not capturing.is_on_main_path() or not captured.is_on_main_path():
		return create_captured(&"", &"", p_command_sequence)
	return create_captured(
			capturing.pawn_id,
			captured.pawn_id,
			p_command_sequence)


## True ако envelope-ът е валиден, и двете pawn_id са валидни и принадлежат
## на различни играчи (не може да вземеш своя пионка).
## Празен / неизвестен id или съвпадащ играч → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PawnId.is_valid(capturing_pawn_id):
		return false
	if not PawnId.is_valid(captured_pawn_id):
		return false
	if capturing_pawn_id == captured_pawn_id:
		return false
	if get_capturing_player_id() == get_captured_player_id():
		return false
	return true


## PlayerId на пионката, извършила взимането.
func get_capturing_player_id() -> StringName:
	return PawnId.get_player_id(capturing_pawn_id)


## PlayerId на взетата пионка.
func get_captured_player_id() -> StringName:
	return PawnId.get_player_id(captured_pawn_id)


## JSON-safe Dictionary: envelope + capturing_pawn_id + captured_pawn_id.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["capturing_pawn_id"] = String(capturing_pawn_id)
	data["captured_pawn_id"] = String(captured_pawn_id)
	return data


## Десериализация към PawnCapturedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PAWN_CAPTURED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_captured_dict(data: Dictionary) -> PawnCapturedEvent:
	var event := PawnCapturedEvent.new(
			StringName(str(data.get("capturing_pawn_id", ""))),
			StringName(str(data.get("captured_pawn_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PAWN_CAPTURED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_captured_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PawnCapturedEvent):
		return false
	if not super.equals(other):
		return false
	var other_captured := other as PawnCapturedEvent
	return (
			capturing_pawn_id == other_captured.capturing_pawn_id
			and captured_pawn_id == other_captured.captured_pawn_id
	)
