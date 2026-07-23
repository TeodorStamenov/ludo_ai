extends TestCase
## Unit тестове за LocalSaveRepository — файлова persistence на user://.
##
## Тестовете използват уникални tmp имена, за да избегнат конфликт с реални данни.
## setUp/tearDown почистват тестовите файлове.

var repo: LocalSaveRepository

const _TEST_SETTINGS := "user://settings.json"
const _TEST_PROFILE  := "user://profile.json"
const _TEST_MATCH    := "user://active_match.json"

var _files_to_clean: Array[String] = [
	_TEST_SETTINGS, _TEST_PROFILE, _TEST_MATCH,
	"user://settings.tmp", "user://profile.tmp", "user://active_match.tmp",
]


func setUp() -> void:
	repo = LocalSaveRepository.new()
	_cleanup_files()


func tearDown() -> void:
	_cleanup_files()


func _cleanup_files() -> void:
	var dir := DirAccess.open("user://")
	if not dir:
		return
	for path: String in _files_to_clean:
		var name := path.get_file()
		if dir.file_exists(name):
			dir.remove(name)


# --- Settings ---

func test_load_settings_returns_defaults_when_no_file() -> void:
	var s := repo.load_settings()
	assert_eq(s.get("music_volume", -1.0), 1.0, "default music_volume")
	assert_true(s.get("haptics_enabled", false), "default haptics_enabled")


func test_save_and_load_settings_round_trip() -> void:
	var data := {
		"music_volume": 0.4, "sfx_volume": 0.6,
		"haptics_enabled": false, "auto_move_single": true, "colorblind_mode": true,
	}
	var ok := repo.save_settings(data)
	assert_true(ok, "save_settings should succeed")
	assert_true(FileAccess.file_exists(_TEST_SETTINGS), "settings.json created")

	var loaded := repo.load_settings()
	assert_eq(loaded["music_volume"], 0.4, "music_volume")
	assert_false(loaded["haptics_enabled"], "haptics_enabled")
	assert_true(loaded["colorblind_mode"], "colorblind_mode")


func test_settings_file_has_schema_envelope() -> void:
	repo.save_settings({"music_volume": 0.7, "sfx_volume": 1.0,
		"haptics_enabled": true, "auto_move_single": true, "colorblind_mode": false})
	var file := FileAccess.open(_TEST_SETTINGS, FileAccess.READ)
	assert_not_null(file, "settings.json should be readable")
	if not file:
		return
	var content := file.get_as_text()
	file = null
	var parsed = JSON.parse_string(content)
	assert_not_null(parsed, "JSON parseable")
	if not parsed is Dictionary:
		return
	assert_eq(parsed.get("schema_version"), LocalSaveRepository.SCHEMA_VERSION, "schema_version")
	assert_true(parsed.has("saved_at"), "saved_at present")
	assert_true(parsed.has("payload"), "payload present")


# --- Match snapshot ---

func test_has_no_snapshot_without_file() -> void:
	assert_false(repo.has_match_snapshot(), "no snapshot initially")


func test_save_and_check_snapshot() -> void:
	assert_true(repo.save_match_snapshot({"command_sequence": 10}), "save should succeed")
	assert_true(repo.has_match_snapshot(), "has_snapshot after save")
	assert_true(FileAccess.file_exists(_TEST_MATCH), "active_match.json exists")


func test_load_match_snapshot_round_trip() -> void:
	repo.save_match_snapshot({"match_id": "abc", "command_sequence": 7})
	var loaded := repo.load_match_snapshot()
	assert_eq(loaded.get("match_id"), "abc", "match_id round-trip")
	assert_eq(loaded.get("command_sequence"), 7, "command_sequence round-trip")


func test_clear_match_snapshot_removes_file() -> void:
	repo.save_match_snapshot({"x": 1})
	assert_true(repo.clear_match_snapshot(), "clear should succeed")
	assert_false(repo.has_match_snapshot(), "no snapshot after clear")
	assert_false(FileAccess.file_exists(_TEST_MATCH), "file deleted")


func test_clear_when_no_snapshot_returns_true() -> void:
	assert_true(repo.clear_match_snapshot(), "clear on empty is still ok")


# --- XP via profile ---

func test_add_xp_persists_between_instances() -> void:
	repo.add_xp(100)
	repo.add_xp(50)
	var repo2 := LocalSaveRepository.new()
	assert_eq(repo2.get_xp(), 150, "XP persists to new instance")


# --- Unlocks ---

func test_unlock_persists() -> void:
	repo.unlock(&"rabbit")
	var repo2 := LocalSaveRepository.new()
	assert_true(repo2.is_unlocked(&"rabbit"), "unlock persists across instances")


# --- Statistics ---

func test_record_match_result_persists() -> void:
	repo.record_match_result({"rank": 1, "gifts_collected": 2,
		"pawns_captured": 1, "pawns_finished": 4})
	var repo2 := LocalSaveRepository.new()
	var stats := repo2.get_statistics()
	assert_eq(stats["matches_played"], 1, "matches_played persisted")
	assert_eq(stats["matches_won"], 1, "matches_won persisted")
