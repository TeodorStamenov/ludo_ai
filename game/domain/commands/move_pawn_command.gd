class_name MovePawnCommand
extends GameCommand
## Заявка за преместване на пионка (docs/V1_ARCHITECTURE.md, §4.3 / §11).
##
## Носи player_id и pawn_id (намерение); GameEngine изчислява дестинацията от
## текущия TurnState (хвърлен зар) и BoardDefinition. Клиентът не изпраща
## целева клетка / path_index — само коя пионка да се премести.
##
## Валидно само в TurnState.AWAITING_MOVE за активния играч (валидацията на
## фазата и legal moves е в GameEngine; тук се проверява self-contained форматът).
##
## Human и AI изпращат еднакъв MovePawnCommand (§16.4).
##
## Сериализация (journal / replay):
##   envelope полетата от GameCommand + "pawn_id".
##   GameCommand.from_dict не диспечира към този subclass — ползвай from_move_dict.

var pawn_id: StringName = &""


func _init(p_player_id: StringName = &"", p_pawn_id: StringName = &"") -> void:
	player_id = p_player_id
	pawn_id = p_pawn_id
	command_type = TYPE_MOVE_PAWN


## Фабрика с player_id + pawn_id + envelope. Отделно име от GameCommand.create —
## GDScript изисква съвпадаща сигнатура при override.
static func create_for_pawn(
		p_player_id: StringName,
		p_pawn_id: StringName,
		p_match_id: StringName = &"",
		p_sequence: int = SEQUENCE_UNSET,
		p_auth_token: String = ""
) -> MovePawnCommand:
	var cmd := MovePawnCommand.new(p_player_id, p_pawn_id)
	cmd.match_id = p_match_id
	cmd.sequence = p_sequence
	cmd.auth_token = p_auth_token
	return cmd


## True ако envelope-ът е валиден, player_id е непразен валиден PlayerId,
## pawn_id е валиден PawnId и принадлежи на player_id.
## Празен / неизвестен id или чужда пионка → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PlayerId.is_valid(player_id):
		return false
	if not PawnId.is_valid(pawn_id):
		return false
	return PawnId.get_player_id(pawn_id) == player_id


## JSON-safe Dictionary: envelope + pawn_id (без destination / result).
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["pawn_id"] = String(pawn_id)
	return data


## Десериализация към MovePawnCommand. command_type винаги се форсира към TYPE_MOVE_PAWN.
## Отделно от GameCommand.from_dict (което не диспечира към subclass).
static func from_move_dict(data: Dictionary) -> MovePawnCommand:
	var cmd := MovePawnCommand.new(
			StringName(str(data.get("player_id", ""))),
			StringName(str(data.get("pawn_id", ""))))
	cmd.match_id = StringName(str(data.get("match_id", "")))
	cmd.sequence = int(data.get("sequence", SEQUENCE_UNSET))
	cmd.auth_token = str(data.get("auth_token", ""))
	cmd.command_type = TYPE_MOVE_PAWN
	return cmd


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_command() -> GameCommand:
	return from_move_dict(to_dict())


## True ако envelope и pawn_id съвпадат и other е MovePawnCommand.
func equals(other: GameCommand) -> bool:
	if other == null or not (other is MovePawnCommand):
		return false
	if not super.equals(other):
		return false
	return pawn_id == (other as MovePawnCommand).pawn_id
