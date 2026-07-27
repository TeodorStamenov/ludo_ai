class_name EventQueue
extends RefCounted
## Буферира DomainEvent-и и ги предоставя на Presentation за последователна
## обработка (docs/V1_ARCHITECTURE.md, раздел 5 / §4.4).
##
## MatchSession enqueue-ва батч след приета команда.
## GamePresenter/AnimationQueue консумират FIFO чрез dequeue() или
## take_sequence(sequence). След events_presented(sequence) MatchSession
## вика acknowledge(sequence), за да изчисти остатъци от представената
## поредица (ако Presentation е ползвала signal payload вместо dequeue).
##
## Presentation gate (§5.2): докато има pending sequence, следваща команда
## не влиза — в буфера има най-много една неприета поредица.

signal drained

var _buffer: Array = []
var _consumed: int = 0


func enqueue(events: Array) -> void:
	if events.is_empty():
		return
	for entry in events:
		if entry == null:
			continue
		if not (entry is DomainEvent):
			push_error(
					"EventQueue.enqueue: expected DomainEvent, got %s"
					% type_string(typeof(entry)))
			continue
		_buffer.append(entry)


func dequeue() -> DomainEvent:
	if _buffer.is_empty():
		return null
	_consumed += 1
	var event: DomainEvent = _buffer.pop_front() as DomainEvent
	if _buffer.is_empty():
		drained.emit()
	return event


func peek() -> DomainEvent:
	if _buffer.is_empty():
		return null
	return _buffer[0] as DomainEvent


## Премахва и връща всички водещи събития с дадения command_sequence.
## Спира при първото събитие с друг sequence — пази FIFO между батчове.
func take_sequence(sequence: int) -> Array:
	var out: Array = []
	while not _buffer.is_empty():
		var front: DomainEvent = _buffer[0] as DomainEvent
		if front == null or front.command_sequence != sequence:
			break
		out.append(dequeue())
	return out


## Изчиства представената поредица след MatchSession.events_presented.
func acknowledge(sequence: int) -> int:
	return take_sequence(sequence).size()


func is_empty() -> bool:
	return _buffer.is_empty()


func size() -> int:
	return _buffer.size()


func clear() -> void:
	_buffer.clear()


func total_consumed() -> int:
	return _consumed
