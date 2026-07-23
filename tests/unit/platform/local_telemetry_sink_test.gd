extends TestCase
## Unit тестове за LocalTelemetrySink — файлово-базиран JSONL telemetry адаптер.
##
## Тестовете записват в user://telemetry.log; setUp/tearDown изчистват файла.
## Проверяват буферирането, auto-flush при достигане на FLUSH_THRESHOLD,
## atomic-append логиката и незабавния flush при invariant violation.
##
## БЕЛЕЖКА: LocalTelemetrySink не прилага auto-flush при освобождаване
## (NOTIFICATION_PREDELETE е ненадеждно за RefCounted в Godot 4.6).
## Притежателят трябва да извика flush() преди да пусне последната референция.

var sink: LocalTelemetrySink

const _LOG_PATH := "user://telemetry.log"


func setUp() -> void:
	sink = LocalTelemetrySink.new()
	_delete_log()


func tearDown() -> void:
	_delete_log()


func _delete_log() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("telemetry.log"):
		dir.remove("telemetry.log")


func _read_log_lines() -> Array[String]:
	var lines: Array[String] = []
	if not FileAccess.file_exists(_LOG_PATH):
		return lines
	var f := FileAccess.open(_LOG_PATH, FileAccess.READ)
	if not f:
		return lines
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "":
			lines.append(line)
	f = null
	return lines


# --- Buffering behaviour ---

func test_single_record_does_not_auto_flush() -> void:
	sink.record_event(&"dice_rolled", {"value": 3})
	assert_false(FileAccess.file_exists(_LOG_PATH),
		"file should not exist after one entry (below threshold)")


func test_flush_writes_buffered_entry_to_file() -> void:
	sink.record_event(&"dice_rolled", {"value": 3})
	sink.flush()
	assert_true(FileAccess.file_exists(_LOG_PATH), "file created after explicit flush")
	var lines := _read_log_lines()
	assert_eq(lines.size(), 1, "one line written")


func test_flush_on_empty_buffer_does_not_create_file() -> void:
	sink.flush()
	assert_false(FileAccess.file_exists(_LOG_PATH), "no file when buffer was empty")


func test_flush_clears_buffer() -> void:
	sink.record_event(&"turn_started")
	sink.flush()
	sink.flush()
	var lines := _read_log_lines()
	assert_eq(lines.size(), 1, "second flush writes nothing extra")


# --- Auto-flush at threshold ---

func test_auto_flush_at_threshold() -> void:
	for i in LocalTelemetrySink.FLUSH_THRESHOLD:
		sink.record_event(&"tick", {"i": i})
	assert_true(FileAccess.file_exists(_LOG_PATH),
		"file created automatically at FLUSH_THRESHOLD")
	var lines := _read_log_lines()
	assert_eq(lines.size(), LocalTelemetrySink.FLUSH_THRESHOLD,
		"all threshold entries flushed")


func test_no_auto_flush_below_threshold() -> void:
	for i in LocalTelemetrySink.FLUSH_THRESHOLD - 1:
		sink.record_event(&"tick", {"i": i})
	assert_false(FileAccess.file_exists(_LOG_PATH),
		"no flush before threshold is reached")


# --- JSONL content ---

func test_record_event_produces_valid_json_line() -> void:
	sink.record_event(&"dice_rolled", {"value": 6})
	sink.flush()
	var lines := _read_log_lines()
	assert_eq(lines.size(), 1, "one line")
	var parsed = JSON.parse_string(lines[0])
	assert_not_null(parsed, "line is valid JSON")
	if not parsed is Dictionary:
		return
	assert_eq(parsed.get("type"), "dice_rolled", "type field correct")
	assert_true(parsed.has("at"), "at timestamp present")
	assert_true(parsed.has("payload"), "payload present when non-empty")
	assert_eq(parsed["payload"].get("value"), 6, "payload value correct")


func test_record_event_without_payload_omits_payload_key() -> void:
	sink.record_event(&"turn_started")
	sink.flush()
	var lines := _read_log_lines()
	assert_eq(lines.size(), 1, "one line")
	var parsed = JSON.parse_string(lines[0])
	if not parsed is Dictionary:
		return
	assert_false(parsed.has("payload"), "payload key absent when empty")


func test_record_state_hash_produces_state_hash_entry() -> void:
	sink.record_state_hash(&"match_abc", 7, 999)
	sink.flush()
	var lines := _read_log_lines()
	assert_eq(lines.size(), 1, "one line")
	var parsed = JSON.parse_string(lines[0])
	if not parsed is Dictionary:
		return
	assert_eq(parsed.get("type"), "state_hash", "type is state_hash")
	var payload: Dictionary = parsed.get("payload", {})
	assert_eq(payload.get("match_id"), "match_abc", "match_id in payload")
	assert_eq(payload.get("seq"), 7, "seq in payload")
	assert_eq(payload.get("hash"), 999, "hash in payload")


# --- Invariant violation ---

func test_record_invariant_violation_flushes_immediately() -> void:
	sink.record_event(&"some_event")
	sink.record_invariant_violation(&"match_x", "bad state")
	assert_true(FileAccess.file_exists(_LOG_PATH),
		"flush happens immediately on invariant violation")


func test_record_invariant_violation_writes_violation_entry() -> void:
	sink.record_invariant_violation(&"match_x", "board corrupted")
	var lines := _read_log_lines()
	var found := false
	for line: String in lines:
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary and parsed.get("type") == "invariant_violation":
			found = true
			var payload: Dictionary = parsed.get("payload", {})
			assert_eq(payload.get("match_id"), "match_x", "match_id in violation payload")
			assert_eq(payload.get("description"), "board corrupted",
				"description in violation payload")
	assert_true(found, "invariant_violation entry found in log")


# --- Append (не overwrite) при множество flush-ове ---

func test_multiple_flushes_append_to_file() -> void:
	sink.record_event(&"event_a")
	sink.flush()
	sink.record_event(&"event_b")
	sink.flush()
	var lines := _read_log_lines()
	assert_eq(lines.size(), 2, "both entries present after two flushes")
	var types: Array[String] = []
	for line: String in lines:
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			types.append(str(parsed.get("type", "")))
	assert_true(types.has("event_a"), "event_a in log")
	assert_true(types.has("event_b"), "event_b in log")


# --- Explicit flush преди освобождаване ---
# Проверява коректния usage pattern: притежателят извиква flush() преди
# да пусне последната референция. NOTIFICATION_PREDELETE не е надеждно
# за RefCounted в Godot 4.6 и не се използва.

func test_explicit_flush_before_release_preserves_buffered_data() -> void:
	sink.record_event(&"pre_release_event", {"seq": 1})
	sink.flush()
	sink = null
	var lines := _read_log_lines()
	assert_eq(lines.size(), 1, "data present after explicit flush + release")
	var parsed = JSON.parse_string(lines[0])
	assert_true(parsed is Dictionary, "line is valid JSON")
	if parsed is Dictionary:
		assert_eq(parsed.get("type"), "pre_release_event", "event type preserved")


func test_unreleased_buffer_is_lost_without_explicit_flush() -> void:
	sink.record_event(&"buffered_but_never_flushed")
	sink = null
	assert_false(FileAccess.file_exists(_LOG_PATH),
		"unflushed buffer is not auto-saved on release (NOTIFICATION_PREDELETE unreliable)")
