class_name LocalSaveRepository
extends SaveRepository
## Файлово базирана имплементация на SaveRepository
## (docs/V1_ARCHITECTURE.md, раздели 9, 10).
##
## Управлява три JSON файла в user://:
##   settings.json      — SettingsData (#243)
##   profile.json        — ProfileData (#242)
##   active_match.json   — MatchSession snapshot / ActiveMatchSave (#244)
##
## Атомичен запис (#248): AtomicFileWriter.write() — .tmp → rename → .json.
## Всеки файл съдържа envelope {schema_version, saved_at, payload}.
##
## Envelope schema_version (SCHEMA_VERSION по-долу) версионира файловия
## формат; четенето минава през SaveMigrationPipeline (#249), независимо от
## SettingsData.SCHEMA_VERSION / ProfileData.SCHEMA_VERSION, които версионират
## съдържанието на payload-а (#245) — settings/profile се мигрират чрез
## съответния модел СЛЕД envelope миграцията.

const SCHEMA_VERSION := 1

const _SETTINGS_FILE := "settings.json"
const _PROFILE_FILE  := "profile.json"
const _MATCH_FILE    := "active_match.json"

# --- SaveRepository: settings ---

func save_settings(data: Dictionary) -> bool:
	return _atomic_write(_SETTINGS_FILE, data)


func load_settings() -> Dictionary:
	return _load_settings_data().to_dict()


func get_default_settings() -> Dictionary:
	return SettingsData.create_default().to_dict()


# --- SaveRepository: profile ---

func save_profile(data: Dictionary) -> bool:
	return _atomic_write(_PROFILE_FILE, data)


func load_profile() -> Dictionary:
	return _load_profile_data().to_dict()


# --- SaveRepository: match snapshot ---

func save_match_snapshot(snapshot: Dictionary) -> bool:
	return _atomic_write(_MATCH_FILE, snapshot)


func load_match_snapshot() -> Dictionary:
	return _read_payload(_MATCH_FILE)


func clear_match_snapshot() -> bool:
	var dir := DirAccess.open("user://")
	if not dir:
		push_error("LocalSaveRepository: cannot open user://")
		return false
	if not dir.file_exists(_MATCH_FILE):
		return true
	var err := dir.remove(_MATCH_FILE)
	if err != OK:
		push_error("LocalSaveRepository: cannot remove '%s': %d" % [_MATCH_FILE, err])
		return false
	return true


func has_match_snapshot() -> bool:
	return FileAccess.file_exists("user://" + _MATCH_FILE)


# --- SaveRepository: профил (XP / unlocks / статистика) ---

func get_xp() -> int:
	return _load_profile_data().xp


func add_xp(amount: int) -> int:
	var profile := _load_profile_data()
	profile.add_xp(amount)
	save_profile(profile.to_dict())
	return profile.xp


func get_unlocks() -> Array:
	var result: Array = []
	for item_id in _load_profile_data().unlocks:
		result.append(String(item_id))
	return result


func unlock(item_id: StringName) -> void:
	var profile := _load_profile_data()
	if profile.has_unlock(item_id):
		return
	profile.add_unlock(item_id)
	save_profile(profile.to_dict())


func is_unlocked(item_id: StringName) -> bool:
	return _load_profile_data().has_unlock(item_id)


func get_statistics() -> Dictionary:
	var profile := _load_profile_data()
	return {
		"matches_played": profile.matches_played,
		"matches_won": profile.matches_won,
		"gifts_collected": profile.gifts_collected,
		"pawns_captured": profile.pawns_captured,
		"pawns_finished": profile.pawns_finished,
	}


func record_match_result(summary: Dictionary) -> void:
	var profile := _load_profile_data()
	profile.record_match_result(summary)
	save_profile(profile.to_dict())


# --- Private helpers ---

## Атомичен запис (#248, AtomicFileWriter) на envelope-а около payload-а.
func _atomic_write(filename: String, payload: Dictionary) -> bool:
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"payload": payload,
	}
	return AtomicFileWriter.write("user://" + filename, JSON.stringify(envelope, "\t"))


## Чете envelope-а и връща мигрирания payload (#249, SaveMigrationPipeline) —
## по-стар/pre-envelope формат вече не се губи тихо.
func _read_payload(filename: String) -> Dictionary:
	var path := "user://" + filename
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LocalSaveRepository: cannot read '%s' (error %d)" % [
			path, FileAccess.get_open_error()])
		return {}
	var content := file.get_as_text()
	file = null
	var parsed = JSON.parse_string(content)
	if not parsed is Dictionary:
		push_error("LocalSaveRepository: malformed JSON in '%s'" % path)
		return {}
	if not SaveMigrationPipeline.is_envelope_supported(parsed):
		push_warning(
				"LocalSaveRepository: envelope schema_version е от бъдещето в '%s'" % filename)
	return SaveMigrationPipeline.migrate_envelope(parsed)


## payload-ът минава през SettingsData.from_dict(), което мигрира по-стари
## schema_version и попълва липсващи полета от defaults (#245).
func _load_settings_data() -> SettingsData:
	var payload := _read_payload(_SETTINGS_FILE)
	if payload.is_empty():
		return SettingsData.create_default()
	return SettingsData.from_dict(payload)


## payload-ът минава през ProfileData.from_dict(), което мигрира по-стари
## schema_version и попълва липсващи полета с нулеви стойности (#245).
func _load_profile_data() -> ProfileData:
	var payload := _read_payload(_PROFILE_FILE)
	if payload.is_empty():
		return ProfileData.new()
	return ProfileData.from_dict(payload)
