extends TestCase
## Unit тестове за LocalTelemetrySink — файлово-базиран JSONL telemetry адаптер,
## локален bug report bundle при invariant violation (#143) и кратко
## MatchSummary при нормално приключил мач (#145).
##
## Тестовете записват в user://telemetry.log и user://logs/; setUp/tearDown
## изчистват артефактите. Проверяват буферирането, auto-flush при
## FLUSH_THRESHOLD, atomic-append логиката, незабавния flush + bundle
## при invariant violation и circular eviction на MatchSummary логове.
##
## БЕЛЕЖКА: LocalTelemetrySink не прилага auto-flush при освобождаване
## (NOTIFICATION_PREDELETE е ненадеждно за RefCounted в Godot 4.6).
## Притежателят трябва да извика flush() преди да пусне последната референция.

var sink: LocalTelemetrySink

const _LOG_PATH := "user://telemetry.log"
const _LOGS_DIR := "user://logs"


func setUp() -> void:
	sink = LocalTelemetrySink.new()
	_delete_log()
	_delete_bug_reports()


func tearDown() -> void:
	_delete_log()
	_delete_bug_reports()


func _delete_log() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("telemetry.log"):
		dir.remove("telemetry.log")


func _delete_bug_reports() -> void:
	var dir := DirAccess.open(_LOGS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and (
				name.begins_with("bug_report_") or name.begins_with("match_summary_")
		):
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()


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


func _list_bug_report_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(_LOGS_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("bug_report_") and name.ends_with(".json"):
			paths.append("%s/%s" % [_LOGS_DIR, name])
		name = dir.get_next()
	dir.list_dir_end()
	return paths


func _list_match_summary_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(_LOGS_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("match_summary_") and name.ends_with(".json"):
			paths.append("%s/%s" % [_LOGS_DIR, name])
		name = dir.get_next()
	dir.list_dir_end()
	return paths


func _valid_summary(match_id: String = "m_ok") -> Dictionary:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
		MatchResult.PlayerStanding.create(PlayerId.YELLOW, 2),
	])
	result.match_id = StringName(match_id)
	return MatchSummary.build_from_match_result(result, 9)


func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f = null
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


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


# --- Invariant violation + bug report bundle (#143) ---

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
			assert_true(str(payload.get("bundle_path", "")).begins_with(_LOGS_DIR),
				"bundle_path points under user://logs")
	assert_true(found, "invariant_violation entry found in log")


func test_record_invariant_violation_writes_bug_report_bundle() -> void:
	var snapshot := {
		"match_id": "match_x",
		"command_sequence": 12,
		"state_hash": "42",
	}
	sink.record_invariant_violation(&"match_x", "own_stack_overflow: cell overflow", snapshot)

	var path := sink.get_last_bug_report_path()
	assert_false(path.is_empty(), "last bug report path set")
	assert_true(FileAccess.file_exists(path), "bundle file exists on disk")

	var reports := _list_bug_report_paths()
	assert_eq(reports.size(), 1, "exactly one bug report file")
	assert_eq(reports[0], path, "listed path matches last path")

	var bundle := _read_json_file(path)
	assert_true(BugReportBundle.is_valid_payload(bundle), "bundle schema valid")
	assert_eq(bundle.get(BugReportBundle.KEY_MATCH_ID), "match_x")
	assert_eq(bundle.get(BugReportBundle.KEY_DESCRIPTION),
			"own_stack_overflow: cell overflow")
	assert_eq(bundle.get(BugReportBundle.KEY_TRIGGER),
			String(BugReportBundle.TRIGGER_INVARIANT_VIOLATION))
	var snap: Dictionary = bundle.get(BugReportBundle.KEY_SNAPSHOT, {})
	assert_eq(snap.get("command_sequence"), 12, "snapshot preserved in bundle")


func test_bug_report_bundle_sanitizes_match_id_in_filename() -> void:
	sink.record_invariant_violation(&"match/../x y", "bad")
	var path := sink.get_last_bug_report_path()
	assert_false(path.is_empty(), "path set")
	var filename := path.get_file()
	assert_true(filename.begins_with("bug_report_"), "bug_report_ prefix")
	assert_false(filename.contains(".."), "no path traversal in filename")
	assert_false(filename.contains("/"), "no slash in filename")
	assert_false(filename.contains(" "), "spaces sanitized")


# --- MatchSummary for normally finished matches (#145) ---

func test_record_match_finished_writes_summary_file() -> void:
	var summary := _valid_summary("m_ok")
	sink.record_match_finished(summary)

	var path := sink.get_last_match_summary_path()
	assert_false(path.is_empty(), "last match summary path set")
	assert_true(FileAccess.file_exists(path), "summary file exists on disk")

	var files := _list_match_summary_paths()
	assert_eq(files.size(), 1, "exactly one match summary file")
	assert_eq(files[0], path)

	var stored := _read_json_file(path)
	assert_true(MatchSummary.is_valid_payload(stored), "stored payload valid")
	assert_eq(stored.get(MatchSummary.KEY_MATCH_ID), "m_ok")
	assert_eq(int(stored.get(MatchSummary.KEY_COMMAND_SEQUENCE, -1)), 9)
	assert_true(stored.has(MatchSummary.KEY_RECORDED_AT), "recorded_at stamped on write")
	assert_false(stored.has("journal"), "normal finish log must not embed journal")


func test_record_match_finished_writes_telemetry_event() -> void:
	sink.record_match_finished(_valid_summary("m_evt"))
	var lines := _read_log_lines()
	var found := false
	for line: String in lines:
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary and parsed.get("type") == "match_finished":
			found = true
			var payload: Dictionary = parsed.get("payload", {})
			assert_eq(payload.get("match_id"), "m_evt")
			assert_true(str(payload.get("summary_path", "")).begins_with(_LOGS_DIR))
	assert_true(found, "match_finished entry found in telemetry.log")


func test_record_match_finished_empty_is_noop() -> void:
	sink.record_match_finished({})
	assert_true(sink.get_last_match_summary_path().is_empty())
	assert_eq(_list_match_summary_paths().size(), 0)


func test_match_summary_circular_buffer_evicts_oldest() -> void:
	sink = LocalTelemetrySink.new(2)
	sink.record_match_finished(_valid_summary("m_1"))
	sink.record_match_finished(_valid_summary("m_2"))
	sink.record_match_finished(_valid_summary("m_3"))

	var files := _list_match_summary_paths()
	assert_eq(files.size(), 2, "capacity must not be exceeded")
	var ids: Array[String] = []
	for path: String in files:
		var stored := _read_json_file(path)
		ids.append(str(stored.get(MatchSummary.KEY_MATCH_ID, "")))
	assert_false(ids.has("m_1"), "oldest normal summary must be evicted")
	assert_true(ids.has("m_2"))
	assert_true(ids.has("m_3"))


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
