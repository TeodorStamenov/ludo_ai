class_name ValidMovesChangedEvent
extends DomainEvent
## Наборът валидни ходове (пионки) е променен (docs/V1_ARCHITECTURE.md, §4.2 / §4.4 / §6.1).
##
## Описва вече настъпил факт: GameEngine е преизчислил TurnState.valid_pawn_ids
## (напр. след DiceRolled → AWAITING_MOVE, или при изчистване на действията).
## Носи player_id и valid_pawn_ids — не намерение и не дестинации.
##
## Presentation (GamePresenter) преобразува събитието в подсветяване на пионки
## в BoardView; не решава дали ход е валиден (§6.1).
##
## Празен valid_pawn_ids е валиден факт — „няма избираеми пионки“ / изчистване.
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "player_id" + "valid_pawn_ids".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_changed_dict.


## Играчът, за когото валидните ходове са обновени (PlayerId); празен преди попълване.
var player_id: StringName = &""
## Пионки, за които MovePawnCommand е валидна (StringName pawn_id); копие, не споделена реф.
var valid_pawn_ids: Array = []


func _init(p_player_id: StringName = &"", p_valid_pawn_ids: Array = []) -> void:
	player_id = p_player_id
	valid_pawn_ids = _normalize_pawn_ids(p_valid_pawn_ids)
	event_type = TYPE_VALID_MOVES_CHANGED


## Фабрика с player_id + valid_pawn_ids + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_changed(
		p_player_id: StringName,
		p_valid_pawn_ids: Array = [],
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> ValidMovesChangedEvent:
	var event := ValidMovesChangedEvent.new(p_player_id, p_valid_pawn_ids)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от TurnState snapshot — копира valid_pawn_ids за дадения player_id.
static func create_from_turn(
		p_player_id: StringName,
		turn: TurnState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> ValidMovesChangedEvent:
	var pawns: Array = []
	if turn != null:
		pawns = turn.valid_pawn_ids
	return create_changed(p_player_id, pawns, p_command_sequence)


## True ако envelope-ът е валиден, player_id е валиден PlayerId,
## всички pawn_id са валидни, без дубликати и принадлежат на player_id.
## Празен valid_pawn_ids е позволен (изчистване / няма ходове).
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PlayerId.is_valid(player_id):
		return false
	return _are_pawn_ids_valid_for_player(player_id, valid_pawn_ids)


## True ако има поне една избираема пионка.
func has_moves() -> bool:
	return not valid_pawn_ids.is_empty()


## True ако pawn_id е в valid_pawn_ids.
func contains_pawn(pawn_id: StringName) -> bool:
	var needle := String(pawn_id)
	for entry in valid_pawn_ids:
		if str(entry) == needle:
			return true
	return false


## JSON-safe Dictionary: envelope + player_id + valid_pawn_ids (String масив).
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["player_id"] = String(player_id)
	var pawns: Array = []
	for pawn_id in valid_pawn_ids:
		pawns.append(str(pawn_id))
	data["valid_pawn_ids"] = pawns
	return data


## Десериализация към ValidMovesChangedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_VALID_MOVES_CHANGED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_changed_dict(data: Dictionary) -> ValidMovesChangedEvent:
	var pawns = data.get("valid_pawn_ids", [])
	var pawn_list: Array = []
	if pawns is Array:
		pawn_list = pawns
	var event := ValidMovesChangedEvent.new(
			StringName(str(data.get("player_id", ""))),
			pawn_list)
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_VALID_MOVES_CHANGED
	return event


## Дълбоко копие през сериализация — без споделена референция към масива.
func duplicate_event() -> DomainEvent:
	return from_changed_dict(to_dict())


## True ако envelope, player_id и valid_pawn_ids съвпадат (редът има значение).
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is ValidMovesChangedEvent):
		return false
	if not super.equals(other):
		return false
	var other_changed := other as ValidMovesChangedEvent
	if player_id != other_changed.player_id:
		return false
	if valid_pawn_ids.size() != other_changed.valid_pawn_ids.size():
		return false
	for i in valid_pawn_ids.size():
		if str(valid_pawn_ids[i]) != str(other_changed.valid_pawn_ids[i]):
			return false
	return true


static func _normalize_pawn_ids(pawn_ids: Array) -> Array:
	var copy: Array = []
	for entry in pawn_ids:
		copy.append(StringName(str(entry)))
	return copy


static func _are_pawn_ids_valid_for_player(p_player_id: StringName, pawn_ids: Array) -> bool:
	var seen: Dictionary = {}
	for entry in pawn_ids:
		var pawn_id := StringName(str(entry))
		if not PawnId.is_valid(pawn_id):
			return false
		if PawnId.get_player_id(pawn_id) != p_player_id:
			return false
		var key := String(pawn_id)
		if seen.has(key):
			return false
		seen[key] = true
	return true
