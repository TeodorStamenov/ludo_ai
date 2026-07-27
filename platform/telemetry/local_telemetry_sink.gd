class_name LocalTelemetrySink
extends TelemetrySink
## Локален файлов telemetry sink за production v1
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Записва state hash-ове и telemetry events в user://telemetry.log
## като JSONL. При invariant violation (#143) създава и bug report
## bundle в user://logs/bug_report_<match_id>_<unix>.json (атомичен запис).
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
const FLUSH_THRESHOLD := 20

var _buffer: Array[String] = []
var _last_bug_report_path: String = ""


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


## Път към последния записан bug report bundle, или "" ако няма / записът е неуспешен.
func get_last_bug_report_path() -> String:
	return _last_bug_report_path


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
	var tmp_name := filename.get_basename() + ".tmp"
	var tmp_path := "%s/%s" % [_LOGS_DIR, tmp_name]
	var final_path := "%s/%s" % [_LOGS_DIR, filename]

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("LocalTelemetrySink: cannot write bug report '%s' (error %d)" % [
			tmp_path, FileAccess.get_open_error()])
		return ""
	file.store_string(JSON.stringify(bundle, "\t"))
	file = null

	var dir := DirAccess.open(_LOGS_DIR)
	if not dir:
		push_error("LocalTelemetrySink: cannot open '%s' for rename" % _LOGS_DIR)
		return ""
	if dir.file_exists(filename):
		dir.remove(filename)
	var err := dir.rename(tmp_name, filename)
	if err != OK:
		push_error("LocalTelemetrySink: rename bug report '%s' -> '%s' failed: %d" % [
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
