class_name DomainEvent
extends RefCounted
## Базов клас за всички domain събития (docs/V1_ARCHITECTURE.md, §4.4 / §11).
##
## Събитията описват вече настъпили факти (минало свършено време).
## Едно движение може да произведе няколко в ред, напр.:
##   PawnMoved → GiftCollected → PowerUpResolved → PawnMoved → TurnChanged
##
## Envelope полета (§4.4 / §11) — общи за всяко събитие:
##   event_type       — дискриминатор за сериализация / AnimationQueue / journal
##   command_sequence — връзка към приетата GameCommand (replay / presentation gate)
##
## Presentation ги проиграва последователно чрез AnimationQueue.
## Statistics/save ги наблюдават, без да дублират правилата.
##
## Domain не използва Node / Vector2 / NodePath. GameEngine създава събитията;
## MatchSession.stamp-ва command_sequence след приета команда.
##
## Конкретни типове (подкласове / бъдещи задачи #69+):
##   MatchStartedEvent (events/match_started_event.gd),
##   DiceRolledEvent (events/dice_rolled_event.gd),
##   ValidMovesChangedEvent (events/valid_moves_changed_event.gd),
##   PawnMovedEvent (events/pawn_moved_event.gd),
##   PawnExitedBaseEvent (events/pawn_exited_base_event.gd),
##   PawnCapturedEvent (events/pawn_captured_event.gd),
##   PawnSentHomeEvent (events/pawn_sent_home_event.gd),
##   PawnStackFormedEvent (events/pawn_stack_formed_event.gd),
##   PawnFinishedEvent (events/pawn_finished_event.gd),
##   GiftSpawned, GiftCollected, PowerUpResolved, ShieldApplied,
##   TurnChangedEvent (events/turn_changed_event.gd),
##   PlayerRankedEvent (events/player_ranked_event.gd),
##   MatchFinished


## Sequence преди stamp / преди първа приета команда (виж GameState.COMMAND_SEQUENCE_START).
const COMMAND_SEQUENCE_UNSET: int = 0

## Известни event_type стойности (§4.4 + scaffold списък). Подкласовете ги задават; base остава празен.
const TYPE_MATCH_STARTED: StringName = &"MatchStarted"
const TYPE_DICE_ROLLED: StringName = &"DiceRolled"
const TYPE_VALID_MOVES_CHANGED: StringName = &"ValidMovesChanged"
const TYPE_PAWN_MOVED: StringName = &"PawnMoved"
const TYPE_PAWN_EXITED_BASE: StringName = &"PawnExitedBase"
const TYPE_PAWN_CAPTURED: StringName = &"PawnCaptured"
const TYPE_PAWN_SENT_HOME: StringName = &"PawnSentHome"
const TYPE_PAWN_STACK_FORMED: StringName = &"PawnStackFormed"
const TYPE_PAWN_FINISHED: StringName = &"PawnFinished"
const TYPE_GIFT_SPAWNED: StringName = &"GiftSpawned"
const TYPE_GIFT_COLLECTED: StringName = &"GiftCollected"
const TYPE_POWER_UP_RESOLVED: StringName = &"PowerUpResolved"
const TYPE_SHIELD_APPLIED: StringName = &"ShieldApplied"
const TYPE_TURN_CHANGED: StringName = &"TurnChanged"
const TYPE_PLAYER_RANKED: StringName = &"PlayerRanked"
const TYPE_MATCH_FINISHED: StringName = &"MatchFinished"

## Пълен списък на известните типове (редът следва §4.4 + допълнителни scaffold факти).
const ALL_TYPES: Array[StringName] = [
	TYPE_MATCH_STARTED,
	TYPE_DICE_ROLLED,
	TYPE_VALID_MOVES_CHANGED,
	TYPE_PAWN_MOVED,
	TYPE_PAWN_EXITED_BASE,
	TYPE_PAWN_CAPTURED,
	TYPE_PAWN_SENT_HOME,
	TYPE_PAWN_STACK_FORMED,
	TYPE_PAWN_FINISHED,
	TYPE_GIFT_SPAWNED,
	TYPE_GIFT_COLLECTED,
	TYPE_POWER_UP_RESOLVED,
	TYPE_SHIELD_APPLIED,
	TYPE_TURN_CHANGED,
	TYPE_PLAYER_RANKED,
	TYPE_MATCH_FINISHED,
]


## Дискриминатор на типа събитие (TYPE_*); празен за чист базов инстанс.
var event_type: StringName = &""
## Пореден номер на командата, която е произвела събитието; UNSET преди stamp.
var command_sequence: int = COMMAND_SEQUENCE_UNSET


## Фабрика за пълно конфигуриран базов envelope (без subclass payload).
static func create(
		p_event_type: StringName = &"",
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> DomainEvent:
	var event := DomainEvent.new()
	event.event_type = p_event_type
	event.command_sequence = p_command_sequence
	return event


## True ако event_type е в ALL_TYPES.
static func is_known_type(p_event_type: StringName) -> bool:
	return ALL_TYPES.has(p_event_type)


## True ако събитието вече е stamp-нато с command_sequence ≥ 1.
func is_stamped() -> bool:
	return command_sequence > COMMAND_SEQUENCE_UNSET


## Задава command_sequence (използва се от MatchSession / тестове след приета команда).
func stamp(p_command_sequence: int) -> void:
	command_sequence = p_command_sequence


## True ако полетата са в договорните self-contained граници (§4.4 / §11).
## Празен envelope (преди попълване) е валиден. Неизвестен непразен event_type → false.
## Отрицателен command_sequence → false.
func is_valid() -> bool:
	if command_sequence < COMMAND_SEQUENCE_UNSET:
		return false
	if event_type != &"" and not is_known_type(event_type):
		return false
	return true


## JSON-safe Dictionary: StringName → String. Без Vector2 / NodePath / presentation полета.
func to_dict() -> Dictionary:
	return {
		"event_type": String(event_type),
		"command_sequence": command_sequence,
	}


## Десериализация на базовия envelope. Липсващи полета → подразбиращи се стойности.
## Не диспечира към subclass — това е отговорност на бъдещ event journal / factory.
static func from_dict(data: Dictionary) -> DomainEvent:
	var event := DomainEvent.new()
	event.event_type = StringName(str(data.get("event_type", "")))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_dict(to_dict())


## True ако всички сериализируеми envelope полета съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null:
		return false
	return (
			event_type == other.event_type
			and command_sequence == other.command_sequence
	)
