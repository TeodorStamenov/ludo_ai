class_name LocalTelemetrySink
extends TelemetrySink
## Локален файлов telemetry sink за production v1
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Записва gameplay journal и state hash-ове в user://telemetry.log
## като JSONL (по един JSON обект на ред) за лесен offline анализ.
##
## Лични данни не влизат в записа. При invariant violation
## незабавно прави flush и изписва push_error в конзолата.
##
## Буферира до FLUSH_THRESHOLD записа преди да пише на диск,
## за да намали I/O. Притежателят на инстанцията е отговорен
## да извика flush() преди освобождаване, тъй като
## NOTIFICATION_PREDELETE не е надеждно за RefCounted в Godot 4.

const _LOG_PATH := "user://telemetry.log"
const FLUSH_THRESHOLD := 20

var _buffer: Array[String] = []


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
	record_event(&"invariant_violation", {
		"match_id": str(match_id),
		"description": description,
	})
	flush()


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

