extends TestCase
## Unit тестове за EventQueue — FIFO и sequence-aware последователна обработка.


func _make_event(type: StringName, sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET) -> DomainEvent:
	var e := DomainEvent.new()
	e.event_type = type
	e.command_sequence = sequence
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
	q.enqueue([_make_event(&"PawnMoved"), _make_event(&"GiftCollected"), _make_event(&"TurnChanged")])
	assert_eq(q.dequeue().event_type, &"PawnMoved")
	assert_eq(q.dequeue().event_type, &"GiftCollected")
	assert_eq(q.dequeue().event_type, &"TurnChanged")
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
	q.enqueue([_make_event(&"DiceRolled", 1), _make_event(&"ValidMovesChanged", 1)])
	q.enqueue([_make_event(&"TurnChanged", 2)])
	assert_eq(q.size(), 3)
	assert_eq(q.dequeue().event_type, &"DiceRolled")
	assert_eq(q.dequeue().event_type, &"ValidMovesChanged")
	assert_eq(q.dequeue().event_type, &"TurnChanged")


func test_drained_signal_emitted() -> void:
	var q := EventQueue.new()
	var captured := {"fired": false}
	q.drained.connect(func(): captured.fired = true)
	q.enqueue([_make_event(&"TurnChanged")])
	q.dequeue()
	assert_true(captured.fired, "drained signal must fire when last event consumed")


func test_clear_empties_queue() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"DiceRolled"), _make_event(&"TurnChanged")])
	q.clear()
	assert_true(q.is_empty())
	assert_eq(q.size(), 0)


func test_total_consumed_counter() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"DiceRolled"), _make_event(&"TurnChanged")])
	q.dequeue()
	q.dequeue()
	assert_eq(q.total_consumed(), 2)


func test_enqueue_skips_non_domain_events() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"DiceRolled"), "not-an-event", null, 42])
	assert_eq(q.size(), 1, "only DomainEvent entries must be buffered")
	assert_eq(q.dequeue().event_type, &"DiceRolled")


func test_take_sequence_returns_leading_batch_only() -> void:
	var q := EventQueue.new()
	q.enqueue([
			_make_event(&"PawnMoved", 1),
			_make_event(&"PawnCaptured", 1),
			_make_event(&"TurnChanged", 2),
	])
	var batch: Array = q.take_sequence(1)
	assert_eq(batch.size(), 2)
	assert_eq((batch[0] as DomainEvent).event_type, &"PawnMoved")
	assert_eq((batch[1] as DomainEvent).event_type, &"PawnCaptured")
	assert_eq(q.size(), 1)
	assert_eq(q.peek().event_type, &"TurnChanged")
	assert_eq(q.peek().command_sequence, 2)


func test_take_sequence_empty_when_head_mismatches() -> void:
	var q := EventQueue.new()
	q.enqueue([_make_event(&"TurnChanged", 2)])
	var batch: Array = q.take_sequence(1)
	assert_eq(batch.size(), 0)
	assert_eq(q.size(), 1, "mismatched take_sequence must not consume")


func test_acknowledge_clears_presented_sequence() -> void:
	var q := EventQueue.new()
	q.enqueue([
			_make_event(&"DiceRolled", 3),
			_make_event(&"ValidMovesChanged", 3),
	])
	var removed := q.acknowledge(3)
	assert_eq(removed, 2)
	assert_true(q.is_empty())
	assert_eq(q.total_consumed(), 2)
