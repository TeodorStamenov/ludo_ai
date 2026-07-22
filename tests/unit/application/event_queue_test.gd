extends TestCase
## Unit тестове за EventQueue.


func _make_event(type: StringName) -> DomainEvent:
	var e := DomainEvent.new()
	e.event_type = type
	return e


func test_empty_queue() -> void:
	var q := EventQueue.new()
	assert_true(q.is_empty())
	assert_eq(q.size(), 0)
	assert_null(q.dequeue())
	assert_null(q.peek())


func test_enqueue_and_dequeue_single() -> void:
	var q := EventQueue.new()
	var e := _make_event(&"DiceRolled")
	q.enqueue([e])
	assert_false(q.is_empty())
	assert_eq(q.size(), 1)
	var out := q.dequeue()
	assert_not_null(out)
	assert_eq(out.event_type, &"DiceRolled")
	assert_true(q.is_empty())


func test_fifo_order() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"A"), _make_event(&"B"), _make_event(&"C")])
	assert_eq(q.dequeue().event_type, &"A")
	assert_eq(q.dequeue().event_type, &"B")
	assert_eq(q.dequeue().event_type, &"C")
	assert_true(q.is_empty())


func test_peek_does_not_consume() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"PawnMoved")])
	var peeked := q.peek()
	assert_not_null(peeked)
	assert_eq(q.size(), 1, "peek must not consume")
	var dequeued := q.dequeue()
	assert_eq(dequeued.event_type, peeked.event_type)


func test_multiple_batches_maintain_order() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"X1"), _make_event(&"X2")])
	q.enqueue([_make_event(&"Y1")])
	assert_eq(q.size(), 3)
	assert_eq(q.dequeue().event_type, &"X1")
	assert_eq(q.dequeue().event_type, &"X2")
	assert_eq(q.dequeue().event_type, &"Y1")


func test_drained_signal_emitted() -> void:
	var q := EventQueue.new()
	var fired := false
	q.drained.connect(func(): fired = true)
	q.enqueue([_make_event(&"TurnChanged")])
	q.dequeue()
	assert_true(fired, "drained signal must fire when last event consumed")


func test_clear_empties_queue() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"A"), _make_event(&"B")])
	q.clear()
	assert_true(q.is_empty())
	assert_eq(q.size(), 0)


func test_total_consumed_counter() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"A"), _make_event(&"B")])
	q.dequeue()
	q.dequeue()
	assert_eq(q.total_consumed(), 2)
