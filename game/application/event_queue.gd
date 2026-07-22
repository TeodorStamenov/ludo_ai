class_name EventQueue
extends RefCounted
## Буферира DomainEvent-и и ги предоставя на Presentation за последователна
## обработка (docs/V1_ARCHITECTURE.md, раздел 5).
##
## MatchSession добавя батч DomainEvent-и след приета команда.
## GamePresenter/AnimationQueue ги консумира един по един и потвърждава
## events_presented(sequence) преди MatchSession да приеме следваща команда.

signal drained

var _buffer: Array = []
var _consumed: int = 0


func enqueue(events: Array) -> void:
	_buffer.append_array(events)


func dequeue() -> DomainEvent:
	if _buffer.is_empty():
		return null
	_consumed += 1
	var event: DomainEvent = _buffer.pop_front()
	if _buffer.is_empty():
		drained.emit()
	return event


func peek() -> DomainEvent:
	if _buffer.is_empty():
		return null
	return _buffer[0]


func is_empty() -> bool:
	return _buffer.is_empty()


func size() -> int:
	return _buffer.size()


func clear() -> void:
	_buffer.clear()


func total_consumed() -> int:
	return _consumed
