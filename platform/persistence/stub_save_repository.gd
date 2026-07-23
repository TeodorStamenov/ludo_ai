class_name StubSaveRepository
extends SaveRepository
## In-memory имплементация на SaveRepository + SettingsRepository +
## ProgressRepository за използване в тестове.
##
## Не пише нищо на диск. Данните живеят само в паметта за времето на теста.

const _SETTINGS_DEFAULTS := {
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"haptics_enabled": true,
	"auto_move_single": true,
	"colorblind_mode": false,
}

var _settings: Dictionary = {}
var _profile: Dictionary = {}
var _match_snapshot: Dictionary = {}
var _has_snapshot: bool = false


# --- SaveRepository: settings ---

func save_settings(data: Dictionary) -> bool:
	_settings = data.duplicate(true)
	return true


func load_settings() -> Dictionary:
	if _settings.is_empty():
		return _SETTINGS_DEFAULTS.duplicate()
	var result := _SETTINGS_DEFAULTS.duplicate()
	for key: String in _settings:
		result[key] = _settings[key]
	return result


# --- SaveRepository: profile ---

func save_profile(data: Dictionary) -> bool:
	_profile = data.duplicate(true)
	return true


func load_profile() -> Dictionary:
	return _profile.duplicate(true)


# --- SaveRepository: match snapshot ---

func save_match_snapshot(snapshot: Dictionary) -> bool:
	_match_snapshot = snapshot.duplicate(true)
	_has_snapshot = true
	return true


func load_match_snapshot() -> Dictionary:
	return _match_snapshot.duplicate(true)


func clear_match_snapshot() -> bool:
	_match_snapshot = {}
	_has_snapshot = false
	return true


func has_match_snapshot() -> bool:
	return _has_snapshot


# --- SettingsRepository interface (duck-typed) ---

func get_default_settings() -> Dictionary:
	return _SETTINGS_DEFAULTS.duplicate()


# --- ProgressRepository interface (duck-typed) ---

func get_xp() -> int:
	return _profile.get("xp", 0)


func add_xp(amount: int) -> int:
	_profile["xp"] = _profile.get("xp", 0) + amount
	return _profile["xp"]


func get_unlocks() -> Array:
	return _profile.get("unlocks", [])


func unlock(item_id: StringName) -> void:
	var unlocks: Array = _profile.get("unlocks", [])
	var key := str(item_id)
	if key not in unlocks:
		unlocks.append(key)
		_profile["unlocks"] = unlocks


func is_unlocked(item_id: StringName) -> bool:
	return str(item_id) in get_unlocks()


func get_statistics() -> Dictionary:
	return _profile.get("statistics", {
		"matches_played": 0,
		"matches_won": 0,
		"gifts_collected": 0,
		"pawns_captured": 0,
		"pawns_finished": 0,
	})


func record_match_result(summary: Dictionary) -> void:
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
	_profile["statistics"] = stats
