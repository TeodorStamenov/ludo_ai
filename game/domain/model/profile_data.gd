class_name ProfileData
extends RefCounted
## Типизиран модел за прогреса на играча (docs/V1_ARCHITECTURE.md §9;
## docs/V1_GAME_DESIGN.md §5.5; #242).
##
## XP, отключено съдържание (животни/теми/нива — единен StringName списък,
## огледало на предишната LocalSaveRepository.unlock()/is_unlocked() форма) и
## агрегирана статистика. SaveRepository.save_profile()/load_profile()
## продължават да работят с Dictionary (портов договор) — ProfileData е
## typed слоят, който повикващият код реално ползва.
##
## schema_version тук е независим от envelope-ния schema_version, който
## LocalSaveRepository пише около payload-а (#245) — виж settings_data.gd.

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var xp: int = 0
var unlocks: Array[StringName] = []
var matches_played: int = 0
var matches_won: int = 0
var gifts_collected: int = 0
var pawns_captured: int = 0
var pawns_finished: int = 0


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
	if xp < 0:
		return false
	if matches_played < 0 or matches_won < 0 or matches_won > matches_played:
		return false
	if gifts_collected < 0 or pawns_captured < 0 or pawns_finished < 0:
		return false
	return true


func has_unlock(item_id: StringName) -> bool:
	return item_id in unlocks


func add_unlock(item_id: StringName) -> void:
	if not has_unlock(item_id):
		unlocks.append(item_id)


func add_xp(amount: int) -> void:
	xp += amount


## Агрегира резултат от завършен мач в статистиката (огледало на предишната
## LocalSaveRepository.record_match_result, преместено тук за изолирано
## тестване без файлов I/O). rank == 1 → победа.
func record_match_result(summary: Dictionary) -> void:
	matches_played += 1
	if int(summary.get("rank", 999)) == 1:
		matches_won += 1
	gifts_collected += int(summary.get("gifts_collected", 0))
	pawns_captured += int(summary.get("pawns_captured", 0))
	pawns_finished += int(summary.get("pawns_finished", 0))


func to_dict() -> Dictionary:
	var unlock_strings: Array = []
	for item_id in unlocks:
		unlock_strings.append(String(item_id))
	return {
		"schema_version": schema_version,
		"xp": xp,
		"unlocks": unlock_strings,
		"statistics": {
			"matches_played": matches_played,
			"matches_won": matches_won,
			"gifts_collected": gifts_collected,
			"pawns_captured": pawns_captured,
			"pawns_finished": pawns_finished,
		},
	}


## Липсващи полета → нулеви стойности (нов профил). По-стар schema_version
## се мигрира първо (migrate_dict).
static func from_dict(data: Dictionary) -> ProfileData:
	var migrated := migrate_dict(data)
	var profile := ProfileData.new()
	profile.schema_version = SCHEMA_VERSION
	profile.xp = int(migrated.get("xp", 0))

	var raw_unlocks: Array = migrated.get("unlocks", [])
	var unlocks: Array[StringName] = []
	for entry in raw_unlocks:
		unlocks.append(StringName(str(entry)))
	profile.unlocks = unlocks

	var stats: Dictionary = migrated.get("statistics", {})
	profile.matches_played = int(stats.get("matches_played", 0))
	profile.matches_won = int(stats.get("matches_won", 0))
	profile.gifts_collected = int(stats.get("gifts_collected", 0))
	profile.pawns_captured = int(stats.get("pawns_captured", 0))
	profile.pawns_finished = int(stats.get("pawns_finished", 0))
	return profile


func duplicate_state() -> ProfileData:
	return ProfileData.from_dict(to_dict())


func equals(other: ProfileData) -> bool:
	if other == null:
		return false
	if xp != other.xp or unlocks.size() != other.unlocks.size():
		return false
	for i in unlocks.size():
		if unlocks[i] != other.unlocks[i]:
			return false
	return (
			matches_played == other.matches_played
			and matches_won == other.matches_won
			and gifts_collected == other.gifts_collected
			and pawns_captured == other.pawns_captured
			and pawns_finished == other.pawns_finished
	)
