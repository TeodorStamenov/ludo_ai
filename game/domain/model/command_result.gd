class_name CommandResult
extends RefCounted
## Резултат от GameEngine.apply_command / validate_and_apply
## (docs/V1_ARCHITECTURE.md, §4.3 / §12).
##
## Публичен договор „команда → ново наблюдаемо състояние + събития“:
##   accepted : bool
##   state    : GameState
##   events   : Array[DomainEvent]
##   error    : CommandError?  (null при accept)
##
## Инварианти (§12):
##   - accept → error == null; events са факти от приложената команда;
##   - reject → error != null; events празни; state е непромененият вход
##     (MatchSession не вика capture_rng при reject).
##
## Domain не използва Node / Vector2 / NodePath.


## True ако командата е приложена успешно.
var accepted: bool = false
## Наблюдаемо състояние след apply (или непромененото при reject).
var state: GameState = null
## DomainEvent факти в ред на възникване; празен при reject.
var events: Array = []
## Структурирана грешка при reject; null при accept.
var error: CommandError = null


## Фабрика за пълно конфигуриран CommandResult (events се копира по референция на елементите).
static func create(
		p_accepted: bool,
		p_state: GameState,
		p_events: Array = [],
		p_error: CommandError = null
) -> CommandResult:
	var result := CommandResult.new()
	result.accepted = p_accepted
	result.state = p_state
	result.events = p_events.duplicate()
	result.error = p_error
	return result


## Convenience: приета команда — без error, с optional events.
static func ok(p_state: GameState, p_events: Array = []) -> CommandResult:
	return create(true, p_state, p_events, null)


## Convenience: отхвърлена команда — празни events + CommandError (§12).
static func rejected(p_state: GameState, p_error: CommandError) -> CommandResult:
	return create(false, p_state, [], p_error)


## Convenience за stub / още неимплементиран Engine път.
static func not_implemented(p_state: GameState, p_message: String = "not_implemented") -> CommandResult:
	return rejected(p_state, CommandError.not_implemented(p_message))


func is_rejected() -> bool:
	return not accepted


func has_error() -> bool:
	return error != null


func event_count() -> int:
	return events.size()


## True ако accept/reject инвариантите и вложените модели са в договорните граници
## (§4.3 / §12). state е задължителен; при reject events трябва да са празни.
func is_valid() -> bool:
	if state == null:
		return false
	if accepted:
		if error != null:
			return false
		for entry in events:
			if not (entry is DomainEvent):
				return false
			if not (entry as DomainEvent).is_valid():
				return false
		return true
	if error == null or not error.is_valid():
		return false
	if not events.is_empty():
		return false
	return true


## JSON-safe Dictionary: вложени to_dict(); error е null Dictionary-стойност при accept.
## Без Vector2 / NodePath. DomainEvent.from_dict не диспечира subclass — виж from_dict.
func to_dict() -> Dictionary:
	var event_dicts: Array = []
	for entry in events:
		if entry is DomainEvent:
			event_dicts.append((entry as DomainEvent).to_dict())
	var state_dict: Dictionary = {}
	if state != null:
		state_dict = state.to_dict()
	var error_dict: Variant = null
	if error != null:
		error_dict = error.to_dict()
	return {
		"accepted": accepted,
		"state": state_dict,
		"events": event_dicts,
		"error": error_dict,
	}


## Десериализация. Липсващи полета → подразбиращи се стойности.
## events се възстановяват като базови DomainEvent (без subclass payload).
static func from_dict(data: Dictionary) -> CommandResult:
	var result := CommandResult.new()
	result.accepted = bool(data.get("accepted", false))
	var state_data: Variant = data.get("state", {})
	if state_data is Dictionary:
		result.state = GameState.from_dict(state_data)
	result.events.clear()
	for entry in data.get("events", []):
		if entry is Dictionary:
			result.events.append(DomainEvent.from_dict(entry))
	var error_data: Variant = data.get("error", null)
	if error_data is Dictionary:
		result.error = CommandError.from_dict(error_data)
	else:
		result.error = null
	return result


## Дълбоко копие — без споделени референции към state / events / error.
func duplicate_result() -> CommandResult:
	var events_copy: Array = []
	for entry in events:
		if entry is DomainEvent:
			events_copy.append((entry as DomainEvent).duplicate_event())
	var state_copy: GameState = null
	if state != null:
		state_copy = state.duplicate_state()
	var error_copy: CommandError = null
	if error != null:
		error_copy = error.duplicate_error()
	return create(accepted, state_copy, events_copy, error_copy)


## True ако accepted / state / events / error съвпадат (вкл. вложени equals).
func equals(other: CommandResult) -> bool:
	if other == null:
		return false
	if accepted != other.accepted:
		return false
	if state == null:
		if other.state != null:
			return false
	elif other.state == null or not state.equals(other.state):
		return false
	if error == null:
		if other.error != null:
			return false
	elif other.error == null or not error.equals(other.error):
		return false
	if events.size() != other.events.size():
		return false
	for i in events.size():
		var a: Variant = events[i]
		var b: Variant = other.events[i]
		if not (a is DomainEvent) or not (b is DomainEvent):
			return false
		if not (a as DomainEvent).equals(b as DomainEvent):
			return false
	return true
