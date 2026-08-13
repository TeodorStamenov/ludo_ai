class_name SettingsData
extends RefCounted
## Типизиран модел за потребителски настройки (docs/V1_ARCHITECTURE.md §9; #243).
##
## Огледало на MatchConfig/GameState конвенцията: SCHEMA_VERSION + migrate_dict()
## + is_valid() + to_dict()/from_dict(). SaveRepository.save_settings()/
## load_settings() продължават да работят с Dictionary (портов договор) —
## SettingsData е typed слоят, който повикващият код реално ползва.
##
## schema_version тук е НЕЗАВИСИМ от envelope-ния schema_version, който
## LocalSaveRepository пише около payload-а (#245) — envelope-ът версионира
## файловия формат, това поле версионира собствената вътрешна форма на
## настройките (същият nested pattern, който MatchSession.to_snapshot() вече
## ползва за GameState вътре в snapshot-а).

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var haptics_enabled: bool = true
var auto_move_single: bool = true
var colorblind_mode: bool = false


static func create_default() -> SettingsData:
	return SettingsData.new()


## Поддържана е само текущата SCHEMA_VERSION (след успешна миграция).
static func is_schema_supported(version: int) -> bool:
	return version == SCHEMA_VERSION


## Мигрира dictionary payload от schema_version N до SCHEMA_VERSION.
## Липсващ/нулев schema_version се третира като pre-versioned (0).
## Бъдещи версии (> SCHEMA_VERSION) не се пипат.
static func migrate_dict(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var version: int = int(migrated.get("schema_version", 0))
	if version > SCHEMA_VERSION:
		return migrated
	while version < SCHEMA_VERSION:
		migrated = _migrate_one_step(migrated, version)
		version += 1
		migrated["schema_version"] = version
	return migrated


static func _migrate_one_step(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			# Pre-schema payloads вече ползват v1 имена на полетата.
			return data
		_:
			return data


func is_valid() -> bool:
	if music_volume < 0.0 or music_volume > 1.0:
		return false
	if sfx_volume < 0.0 or sfx_volume > 1.0:
		return false
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"haptics_enabled": haptics_enabled,
		"auto_move_single": auto_move_single,
		"colorblind_mode": colorblind_mode,
	}


## Липсващи полета → стойностите на create_default(). По-стар schema_version
## се мигрира първо (migrate_dict).
static func from_dict(data: Dictionary) -> SettingsData:
	var migrated := migrate_dict(data)
	var defaults := create_default()
	var settings := SettingsData.new()
	settings.schema_version = SCHEMA_VERSION
	settings.music_volume = float(migrated.get("music_volume", defaults.music_volume))
	settings.sfx_volume = float(migrated.get("sfx_volume", defaults.sfx_volume))
	settings.haptics_enabled = bool(
			migrated.get("haptics_enabled", defaults.haptics_enabled))
	settings.auto_move_single = bool(
			migrated.get("auto_move_single", defaults.auto_move_single))
	settings.colorblind_mode = bool(
			migrated.get("colorblind_mode", defaults.colorblind_mode))
	return settings


func duplicate_state() -> SettingsData:
	return SettingsData.from_dict(to_dict())


func equals(other: SettingsData) -> bool:
	if other == null:
		return false
	return (
			absf(music_volume - other.music_volume) < 0.0001
			and absf(sfx_volume - other.sfx_volume) < 0.0001
			and haptics_enabled == other.haptics_enabled
			and auto_move_single == other.auto_move_single
			and colorblind_mode == other.colorblind_mode
	)
