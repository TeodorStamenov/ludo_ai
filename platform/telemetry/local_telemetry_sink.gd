class_name LocalTelemetrySink
extends TelemetrySink
## Локален файлов telemetry sink за production v1
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Записва state hash-ове и telemetry events в user://telemetry.log
## като JSONL. При invariant violation (#143) създава bug report
## bundle в user://logs/bug_report_<match_id>_<unix>.json.
## При нормално приключил мач (#145) записва кратко MatchSummary в
## user://logs/match_summary_<match_id>_<unix>.json и изтрива старите
## чрез ограничен circular buffer (MatchSummary.DEFAULT_LOG_CAPACITY).
##
## Лични данни не влизат в записа. При invariant violation
## незабавно прави flush и изписва push_error в конзолата.
##
## Буферира до FLUSH_THRESHOLD записа преди да пише на диск,
## за да намали I/O. Притежателят на инстанцията е отговорен
## да извика flush() преди освобождаване, тъй като
## NOTIFICATION_PREDELETE не е надеждно за RefCounted в Godot 4.

const _LOG_PATH := "user://telemetry.log"
const _LOGS_DIR := "user://logs"
const _BUG_REPORT_PREFIX := "bug_report_"
const _MATCH_SUMMARY_PREFIX := "match_summary_"
const FLUSH_THRESHOLD := 20

var _buffer: Array[String] = []
var _last_bug_report_path: String = ""
var _last_match_summary_path: String = ""
var _match_summary_log_capacity: int = MatchSummary.DEFAULT_LOG_CAPACITY


func _init(match_summary_log_capacity: int = MatchSummary.DEFAULT_LOG_CAPACITY) -> void:
	_match_summary_log_capacity = maxi(1, match_summary_log_capacity)


func record_event(event_type: StringName, payload: Dictionary = {}) -> void:
	var entry := {
		"type": str(event_type),
		"at": Time.get_datetime_string_from_system(),
	}
	if not payload.is_empty():
		entry["payload"] = payload
	_buffer.append(JSON.stringify(entry))
	if _buffer.size() >= FLUSH_THRESHOLD:
		flush()


func record_state_hash(match_id: StringName, command_sequence: int, hash_value: int) -> void:
	record_event(&"state_hash", {
		"match_id": str(match_id),
		"seq": command_sequence,
		"hash": hash_value,
	})


func record_invariant_violation(match_id: StringName, description: String,
		snapshot: Dictionary = {}) -> void:
	super.record_invariant_violation(match_id, description, snapshot)
	_last_bug_report_path = _write_bug_report_bundle(match_id, description, snapshot)
	var event_payload := {
		"match_id": str(match_id),
		"description": description,
	}
	if not _last_bug_report_path.is_empty():
		event_payload["bundle_path"] = _last_bug_report_path
	record_event(&"invariant_violation", event_payload)
	flush()


func record_match_finished(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	_last_match_summary_path = _write_match_summary(summary)
	var event_payload := {
		"match_id": str(summary.get(MatchSummary.KEY_MATCH_ID, "")),
	}
	if not _last_match_summary_path.is_empty():
		event_payload["summary_path"] = _last_match_summary_path
	record_event(&"match_finished", event_payload)
	flush()
	_evict_old_match_summaries()


## Път към последния записан bug report bundle, или "" ако няма / записът е неуспешен.
func get_last_bug_report_path() -> String:
	return _last_bug_report_path


## Път към последния записан MatchSummary лог, или "" ако няма / записът е неуспешен.
func get_last_match_summary_path() -> String:
	return _last_match_summary_path


func flush() -> void:
	if _buffer.is_empty():
		return
	var file: FileAccess
	if FileAccess.file_exists(_LOG_PATH):
		file = FileAccess.open(_LOG_PATH, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
	else:
		file = FileAccess.open(_LOG_PATH, FileAccess.WRITE)
	if not file:
		push_error("LocalTelemetrySink: cannot open '%s' (error %d)" % [
			_LOG_PATH, FileAccess.get_open_error()])
		_buffer.clear()
		return
	for line: String in _buffer:
		file.store_line(line)
	file = null
	_buffer.clear()


func _write_bug_report_bundle(
		match_id: StringName,
		description: String,
		snapshot: Dictionary
) -> String:
	if not _ensure_logs_dir():
		return ""
	var bundle: Dictionary = BugReportBundle.build_for_invariant_violation(
			match_id, description, snapshot)
	var safe_id := _sanitize_filename_part(String(match_id))
	if safe_id.is_empty():
		safe_id = "unknown"
	var stamp := str(int(Time.get_unix_time_from_system()))
	var filename := "%s%s_%s.json" % [_BUG_REPORT_PREFIX, safe_id, stamp]
	return _atomic_write_json(filename, bundle)


func _write_match_summary(summary: Dictionary) -> String:
	if not _ensure_logs_dir():
		return ""
	var payload := summary.duplicate(true)
	if not payload.has(MatchSummary.KEY_RECORDED_AT):
		payload[MatchSummary.KEY_RECORDED_AT] = Time.get_datetime_string_from_system()
	var raw_id := str(payload.get(MatchSummary.KEY_MATCH_ID, ""))
	var safe_id := _sanitize_filename_part(raw_id)
	if safe_id.is_empty():
		safe_id = "unknown"
	var stamp := str(int(Time.get_unix_time_from_system()))
	# Уникален суфикс при няколко записа в една и съща секунда.
	var uniq := str(_list_match_summary_filenames().size())
	var filename := "%s%s_%s_%s.json" % [_MATCH_SUMMARY_PREFIX, safe_id, stamp, uniq]
	return _atomic_write_json(filename, payload)


## Изтрива най-старите match_summary_*.json над capacity (FIFO по име).
func _evict_old_match_summaries() -> void:
	var names := _list_match_summary_filenames()
	if names.size() <= _match_summary_log_capacity:
		return
	names.sort()
	var to_remove := names.size() - _match_summary_log_capacity
	var dir := DirAccess.open(_LOGS_DIR)
	if dir == null:
		return
	for i in to_remove:
		dir.remove(names[i])


func _list_match_summary_filenames() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(_LOGS_DIR)
	if dir == null:
		return names
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with(_MATCH_SUMMARY_PREFIX) and name.ends_with(".json"):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return names


func _atomic_write_json(filename: String, data: Dictionary) -> String:
	var tmp_name := filename.get_basename() + ".tmp"
	var tmp_path := "%s/%s" % [_LOGS_DIR, tmp_name]
	var final_path := "%s/%s" % [_LOGS_DIR, filename]

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("LocalTelemetrySink: cannot write '%s' (error %d)" % [
			tmp_path, FileAccess.get_open_error()])
		return ""
	file.store_string(JSON.stringify(data, "\t"))
	file = null

	var dir := DirAccess.open(_LOGS_DIR)
	if not dir:
		push_error("LocalTelemetrySink: cannot open '%s' for rename" % _LOGS_DIR)
		return ""
	if dir.file_exists(filename):
		dir.remove(filename)
	var err := dir.rename(tmp_name, filename)
	if err != OK:
		push_error("LocalTelemetrySink: rename '%s' -> '%s' failed: %d" % [
			tmp_name, filename, err])
		return ""
	return final_path


func _ensure_logs_dir() -> bool:
	if DirAccess.dir_exists_absolute(_LOGS_DIR):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(_LOGS_DIR)
	if err != OK:
		push_error("LocalTelemetrySink: cannot create '%s' (error %d)" % [_LOGS_DIR, err])
		return false
	return true


static func _sanitize_filename_part(value: String) -> String:
	var out := ""
	for i in value.length():
		var ch := value[i]
		var ok := (
				(ch >= "0" and ch <= "9")
				or (ch >= "A" and ch <= "Z")
				or (ch >= "a" and ch <= "z")
				or ch == "-"
				or ch == "_"
		)
		out += ch if ok else "_"
	return out
