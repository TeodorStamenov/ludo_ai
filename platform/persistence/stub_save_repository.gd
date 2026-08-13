class_name StubSaveRepository
extends SaveRepository
## In-memory имплементация на SaveRepository за използване в тестове.
##
## Не пише нищо на диск. Данните живеят само в паметта за времето на теста.
## Ползва SettingsData/ProfileData за същата defaults/migrate логика като
## LocalSaveRepository (#242 / #243 / #245), без файлов I/O.

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
		return SettingsData.create_default().to_dict()
	return SettingsData.from_dict(_settings).to_dict()


func get_default_settings() -> Dictionary:
	return SettingsData.create_default().to_dict()


# --- SaveRepository: profile ---

func save_profile(data: Dictionary) -> bool:
	_profile = data.duplicate(true)
	return true


func load_profile() -> Dictionary:
	return _load_profile_data().to_dict()


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


# --- SaveRepository: профил (XP / unlocks / статистика) ---

func get_xp() -> int:
	return _load_profile_data().xp


func add_xp(amount: int) -> int:
	var profile := _load_profile_data()
	profile.add_xp(amount)
	_profile = profile.to_dict()
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
	_profile = profile.to_dict()


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
	_profile = profile.to_dict()


func _load_profile_data() -> ProfileData:
	if _profile.is_empty():
		return ProfileData.new()
	return ProfileData.from_dict(_profile)
