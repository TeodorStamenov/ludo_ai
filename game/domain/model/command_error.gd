class_name CommandError
extends RefCounted
## Структурирана грешка при отхвърлена GameCommand
## (docs/V1_ARCHITECTURE.md, §4.3 / §12).
##
## GameEngine.apply_command / validate_and_apply връща CommandError в
## CommandResult.error когато командата е невалидна. При reject state и RNG
## остават непроменени (§12).
##
## code е стабилен StringName за UI / логове / journal / multiplayer reject;
## message е debug текст (не локализиран UI copy — Presentation мапва code).
##
## Domain не използва Node / Vector2 / NodePath.

## Стабилни кодове — типични причини за reject (§4.3 / §12 / game design §3).
const CODE_NOT_IMPLEMENTED: StringName = &"not_implemented"
const CODE_INVALID_COMMAND: StringName = &"invalid_command"
const CODE_WRONG_MATCH: StringName = &"wrong_match"
const CODE_WRONG_PLAYER: StringName = &"wrong_player"
const CODE_WRONG_PHASE: StringName = &"wrong_phase"
const CODE_ILLEGAL_MOVE: StringName = &"illegal_move"
const CODE_UNKNOWN_PAWN: StringName = &"unknown_pawn"
const CODE_MATCH_NOT_ACTIVE: StringName = &"match_not_active"
const CODE_MATCH_FINISHED: StringName = &"match_finished"
const CODE_SEQUENCE_MISMATCH: StringName = &"sequence_mismatch"

## Пълен списък на известните кодове (редът е стабилен за тестове / docs).
const ALL_CODES: Array[StringName] = [
	CODE_NOT_IMPLEMENTED,
	CODE_INVALID_COMMAND,
	CODE_WRONG_MATCH,
	CODE_WRONG_PLAYER,
	CODE_WRONG_PHASE,
	CODE_ILLEGAL_MOVE,
	CODE_UNKNOWN_PAWN,
	CODE_MATCH_NOT_ACTIVE,
	CODE_MATCH_FINISHED,
	CODE_SEQUENCE_MISMATCH,
]


## Стабилен код на грешката (CODE_*); празен преди попълване.
var code: StringName = &""
## Debug / journal съобщение; празен низ е позволен.
var message: String = ""


## Фабрика за пълно конфигуриран CommandError.
static func create(p_code: StringName, p_message: String = "") -> CommandError:
	var err := CommandError.new()
	err.code = p_code
	err.message = p_message
	return err


## Convenience за stub / още неимплементиран Engine път.
static func not_implemented(p_message: String = "not_implemented") -> CommandError:
	return create(CODE_NOT_IMPLEMENTED, p_message)


## Convenience за команда, която fails is_valid() / счупен envelope.
static func invalid_command(p_message: String = "") -> CommandError:
	return create(CODE_INVALID_COMMAND, p_message)


## Convenience: ход/зар от грешен играч (не е active seat).
static func wrong_player(p_message: String = "") -> CommandError:
	return create(CODE_WRONG_PLAYER, p_message)


## Convenience: команда не е позволена в текущата TurnPhase.
static func wrong_phase(p_message: String = "") -> CommandError:
	return create(CODE_WRONG_PHASE, p_message)


## Convenience: ход нарушава правила (не в valid_pawn_ids, stack>2, …).
static func illegal_move(p_message: String = "") -> CommandError:
	return create(CODE_ILLEGAL_MOVE, p_message)


## True ако code е в ALL_CODES.
static func is_known_code(p_code: StringName) -> bool:
	return ALL_CODES.has(p_code)


## True ако code е известен (непразен) стабилен код.
## Празен / неизвестен code → false. message няма договорни граници.
func is_valid() -> bool:
	if code == &"":
		return false
	return is_known_code(code)


## JSON-safe Dictionary: StringName → String. Без Vector2 / NodePath.
func to_dict() -> Dictionary:
	return {
		"code": String(code),
		"message": message,
	}


## Десериализация. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> CommandError:
	return create(
			StringName(str(data.get("code", ""))),
			str(data.get("message", "")))


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_error() -> CommandError:
	return from_dict(to_dict())


## True ако code и message съвпадат.
func equals(other: CommandError) -> bool:
	if other == null:
		return false
	return code == other.code and message == other.message
