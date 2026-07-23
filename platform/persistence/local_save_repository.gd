class_name LocalSaveRepository
extends SaveRepository
## Файлово базирана имплементация на всички persistence порти
## (docs/V1_ARCHITECTURE.md, раздели 9, 10).
##
## Управлява три JSON файла в user://:
##   settings.json      — звук, музика, haptics, auto-move, colorblind
##   profile.json       — XP, unlocks, campaign progress, статистика
##   active_match.json  — snapshot за resume след прекъсване
##
## Атомичен запис: write to .tmp → remove old .json → rename .tmp → .json
## Всеки файл съдържа schema_version, saved_at и payload.
##
## В допълнение към SaveRepository имплементира методите на
## SettingsRepository и ProgressRepository (duck-typed от application слоя).

const SCHEMA_VERSION := 1

const _SETTINGS_FILE := "settings.json"
const _PROFILE_FILE  := "profile.json"
const _MATCH_FILE    := "active_match.json"

const _SETTINGS_DEFAULTS := {
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"haptics_enabled": true,
	"auto_move_single": true,
	"colorblind_mode": false,
}

# --- SaveRepository: settings ---

func save_settings(data: Dictionary) -> bool:
	return _atomic_write(_SETTINGS_FILE, data)


func load_settings() -> Dictionary:
	var payload := _read_payload(_SETTINGS_FILE)
	if payload.is_empty():
		return _SETTINGS_DEFAULTS.duplicate()
	return _merge_with_defaults(payload, _SETTINGS_DEFAULTS)


# --- SaveRepository: profile ---

func save_profile(data: Dictionary) -> bool:
	return _atomic_write(_PROFILE_FILE, data)


func load_profile() -> Dictionary:
	return _read_payload(_PROFILE_FILE)


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


# --- SettingsRepository interface (duck-typed) ---

func get_default_settings() -> Dictionary:
	return _SETTINGS_DEFAULTS.duplicate()


# --- ProgressRepository interface (duck-typed) ---

func get_xp() -> int:
	return _profile_get("xp", 0)


func add_xp(amount: int) -> int:
	var profile := _load_profile_data()
	profile["xp"] = profile.get("xp", 0) + amount
	save_profile(profile)
	return profile["xp"]


func get_unlocks() -> Array:
	return _profile_get("unlocks", [])


func unlock(item_id: StringName) -> void:
	var profile := _load_profile_data()
	var unlocks: Array = profile.get("unlocks", [])
	var key := str(item_id)
	if key not in unlocks:
		unlocks.append(key)
		profile["unlocks"] = unlocks
		save_profile(profile)


func is_unlocked(item_id: StringName) -> bool:
	return str(item_id) in get_unlocks()


func get_statistics() -> Dictionary:
	return _profile_get("statistics", _empty_statistics())


func record_match_result(summary: Dictionary) -> void:
	var profile := _load_profile_data()
	var stats: Dictionary = get_statistics()
	stats["matches_played"] = stats.get("matches_played", 0) + 1
	if summary.get("rank", 999) == 1:
		stats["matches_won"] = stats.get("matches_won", 0) + 1
	stats["gifts_collected"] = (stats.get("gifts_collected", 0)
		+ summary.get("gifts_collected", 0))
	stats["pawns_captured"] = (stats.get("pawns_captured", 0)
		+ summary.get("pawns_captured", 0))
	stats["pawns_finished"] = (stats.get("pawns_finished", 0)
		+ summary.get("pawns_finished", 0))
	profile["statistics"] = stats
	save_profile(profile)


# --- Private helpers ---

func _atomic_write(filename: String, payload: Dictionary) -> bool:
	var tmp_name := filename.get_basename() + ".tmp"
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"payload": payload,
	}
	var file := FileAccess.open("user://" + tmp_name, FileAccess.WRITE)
	if not file:
		push_error("LocalSaveRepository: cannot write '%s' (error %d)" % [
			tmp_name, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file = null

	var dir := DirAccess.open("user://")
	if not dir:
		push_error("LocalSaveRepository: cannot open user:// dir")
		return false
	if dir.file_exists(filename):
		dir.remove(filename)
	var err := dir.rename(tmp_name, filename)
	if err != OK:
		push_error("LocalSaveRepository: rename '%s' -> '%s' failed: %d" % [
			tmp_name, filename, err])
		return false
	return true


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
	var schema: int = parsed.get("schema_version", 0)
	if schema != SCHEMA_VERSION:
		push_warning("LocalSaveRepository: schema_version mismatch in '%s' (got %d)" % [
			filename, schema])
	return parsed.get("payload", {})


func _load_profile_data() -> Dictionary:
	var payload := _read_payload(_PROFILE_FILE)
	if payload.is_empty():
		return {"xp": 0, "unlocks": [], "statistics": _empty_statistics()}
	return payload


func _profile_get(key: String, default_val: Variant) -> Variant:
	return _load_profile_data().get(key, default_val)


func _merge_with_defaults(data: Dictionary, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate()
	for key: String in data:
		result[key] = data[key]
	return result


func _empty_statistics() -> Dictionary:
	return {
		"matches_played": 0,
		"matches_won": 0,
		"gifts_collected": 0,
		"pawns_captured": 0,
		"pawns_finished": 0,
	}
