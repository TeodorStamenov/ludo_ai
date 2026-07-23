extends TestCase
## Unit тестове за NullTelemetrySink — no-op impleмeнтация на TelemetrySink.
##
## NullTelemetrySink не пише нищо, но брои record_invariant_violation.
## Полезен като test double в тестове на Application слоя.

var sink: NullTelemetrySink


func setUp() -> void:
	sink = NullTelemetrySink.new()


func test_is_telemetry_sink() -> void:
	assert_true(sink is TelemetrySink, "NullTelemetrySink extends TelemetrySink")


func test_violation_count_starts_at_zero() -> void:
	assert_eq(sink.violation_count, 0, "violation_count starts at 0")


func test_record_invariant_violation_increments_counter() -> void:
	sink.record_invariant_violation(&"match_1", "test violation")
	assert_eq(sink.violation_count, 1, "increments to 1")


func test_record_invariant_violation_increments_multiple_times() -> void:
	sink.record_invariant_violation(&"match_1", "first")
	sink.record_invariant_violation(&"match_1", "second")
	assert_eq(sink.violation_count, 2, "increments to 2 after two calls")


func test_record_invariant_violation_with_snapshot_does_not_crash() -> void:
	sink.record_invariant_violation(&"match_1", "desc", {"board": []})
	assert_eq(sink.violation_count, 1, "violation with snapshot counted")


func test_record_event_does_not_crash() -> void:
	sink.record_event(&"dice_rolled", {"value": 6})
	sink.record_event(&"turn_started")
	assert_eq(sink.violation_count, 0, "record_event does not increment violation_count")


func test_record_state_hash_does_not_crash() -> void:
	sink.record_state_hash(&"match_1", 5, 12345)
	assert_eq(sink.violation_count, 0, "record_state_hash does not increment violation_count")


func test_flush_does_not_crash() -> void:
	sink.flush()
	assert_true(true, "flush() is a no-op and does not crash")
