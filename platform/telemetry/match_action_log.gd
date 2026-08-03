class_name MatchActionLog
extends RefCounted
## Human-greppable per-match action log (docs/V1_ARCHITECTURE.md, раздел 10).
##
## За разлика от LocalTelemetrySink (споделен telemetry.log + summary/bug
## report snapshots), този клас пише ЕДИН JSONL файл на мач с всяко domain
## събитие (зар, движение, capture, gift/power-up, смяна на ход) в реално
## време, плюс отхвърлените команди — за диагностика на "защо се случи X"
## без нужда от replay.
##
## Собственикът (GameScreen) вика begin() при старт на мача и end() при
## приключване / излизане от сцената.

const _LOGS_DIR := "user://logs"
const _PREFIX := "match_actions_"

var _file: FileAccess = null


func begin(match_id: StringName) -> void:
	if not _ensure_logs_dir():
		return
	var safe_id := LocalTelemetrySink._sanitize_filename_part(String(match_id))
	if safe_id.is_empty():
		safe_id = "unknown"
	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second]
	var filename := "%s%s_%s.jsonl" % [_PREFIX, stamp, safe_id]
	var path := "%s/%s" % [_LOGS_DIR, filename]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if not _file:
		push_error("MatchActionLog: cannot open '%s' (error %d)" % [
			path, FileAccess.get_open_error()])
		return
	_write_line({
		"kind": "match_started",
		"match_id": String(match_id),
		"at": Time.get_datetime_string_from_system(),
	})


func record_events(sequence: int, events: Array) -> void:
	if _file == null:
		return
	for entry in events:
		var event := entry as DomainEvent
		if event == null:
			continue
		var line := event.to_dict()
		line["sequence"] = sequence
		line["at"] = Time.get_datetime_string_from_system()
		_write_line(line)


func record_rejected(command: GameCommand, reason: String) -> void:
	if _file == null:
		return
	_write_line({
		"kind": "rejected_command",
		"command": command.to_dict() if command != null else {},
		"reason": reason,
		"at": Time.get_datetime_string_from_system(),
	})


func end() -> void:
	if _file == null:
		return
	_write_line({
		"kind": "match_ended",
		"at": Time.get_datetime_string_from_system(),
	})
	_file = null


func _write_line(data: Dictionary) -> void:
	_file.store_line(JSON.stringify(data))
	_file.flush()


func _ensure_logs_dir() -> bool:
	if DirAccess.dir_exists_absolute(_LOGS_DIR):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(_LOGS_DIR)
	if err != OK:
		push_error("MatchActionLog: cannot create '%s' (error %d)" % [_LOGS_DIR, err])
		return false
	return true
