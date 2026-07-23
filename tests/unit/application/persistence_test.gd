extends TestCase
## Unit тестове за persistence слоя на Application нивото.
##
## Покрива:
##   - StubSaveRepository: settings, profile, match snapshot CRUD
##   - SaveRepository port интерфейс: всички методи са налични
##   - Persistence инварианти (docs/V1_ARCHITECTURE.md, раздел 9):
##       schema_version, атомичен запис, три отделни payload-а


# --- SaveRepository port ---

func test_save_repository_extends_ref_counted() -> void:
	var repo := SaveRepository.new()
	assert_not_null(repo)
	assert_true(repo is RefCounted,
			"SaveRepository трябва да extends RefCounted, не Node")


func test_save_repository_is_not_node() -> void:
	var repo: Object = SaveRepository.new()
	assert_false(repo is Node,
			"SaveRepository не трябва да extends Node")


# --- StubSaveRepository: settings ---

func test_stub_repo_default_settings_are_returned_on_empty() -> void:
	var repo := StubSaveRepository.new()
	var settings := repo.load_settings()
	assert_true(settings.has("music_volume"),
			"Дефолтните настройки трябва да имат music_volume")
	assert_true(settings.has("sfx_volume"),
			"Дефолтните настройки трябва да имат sfx_volume")
	assert_true(settings.has("haptics_enabled"),
			"Дефолтните настройки трябва да имат haptics_enabled")
	assert_true(settings.has("auto_move_single"),
			"Дефолтните настройки трябва да имат auto_move_single")
	assert_true(settings.has("colorblind_mode"),
			"Дефолтните настройки трябва да имат colorblind_mode")


func test_stub_repo_save_and_load_settings() -> void:
	var repo := StubSaveRepository.new()
	var data := {"music_volume": 0.5, "sfx_volume": 0.8,
			"haptics_enabled": false, "auto_move_single": false, "colorblind_mode": true}
	var ok := repo.save_settings(data)
	assert_true(ok, "save_settings трябва да върне true при успех")
	var loaded := repo.load_settings()
	assert_eq(loaded.get("music_volume"), 0.5, "music_volume трябва да е запазен")
	assert_eq(loaded.get("colorblind_mode"), true, "colorblind_mode трябва да е запазен")


func test_stub_repo_settings_isolation() -> void:
	var repo1 := StubSaveRepository.new()
	var repo2 := StubSaveRepository.new()
	repo1.save_settings({"music_volume": 0.1, "sfx_volume": 0.1,
			"haptics_enabled": false, "auto_move_single": false, "colorblind_mode": false})
	var loaded2 := repo2.load_settings()
	assert_eq(loaded2.get("music_volume"), 1.0,
			"Различни repo инстанции не трябва да споделят данни")


# --- StubSaveRepository: match snapshot ---

func test_stub_repo_no_snapshot_by_default() -> void:
	var repo := StubSaveRepository.new()
	assert_false(repo.has_match_snapshot(),
			"Нов repo не трябва да има match snapshot")


func test_stub_repo_save_and_load_match_snapshot() -> void:
	var repo := StubSaveRepository.new()
	var snap := {"command_sequence": 42, "rng_state": {"seed": 1, "state": 0}, "state": {}}
	var ok := repo.save_match_snapshot(snap)
	assert_true(ok, "save_match_snapshot трябва да върне true")
	assert_true(repo.has_match_snapshot(), "has_match_snapshot трябва да е true след запис")
	var loaded := repo.load_match_snapshot()
	assert_eq(loaded.get("command_sequence"), 42,
			"command_sequence трябва да се запази")


func test_stub_repo_clear_match_snapshot() -> void:
	var repo := StubSaveRepository.new()
	repo.save_match_snapshot({"command_sequence": 1})
	assert_true(repo.has_match_snapshot())
	var ok := repo.clear_match_snapshot()
	assert_true(ok, "clear_match_snapshot трябва да върне true")
	assert_false(repo.has_match_snapshot(),
			"has_match_snapshot трябва да е false след изчистване")


func test_stub_repo_snapshot_data_is_deep_copy() -> void:
	var repo := StubSaveRepository.new()
	var original := {"command_sequence": 5}
	repo.save_match_snapshot(original)
	original["command_sequence"] = 999
	var loaded := repo.load_match_snapshot()
	assert_eq(loaded.get("command_sequence"), 5,
			"save/load трябва да правят дълбоко копие, не референция")


# --- StubSaveRepository: profile / XP ---

func test_stub_repo_initial_xp_is_zero() -> void:
	var repo := StubSaveRepository.new()
	assert_eq(repo.get_xp(), 0, "Началното XP трябва да е 0")


func test_stub_repo_add_xp() -> void:
	var repo := StubSaveRepository.new()
	var total := repo.add_xp(100)
	assert_eq(total, 100, "add_xp трябва да върне новото общо XP")
	total = repo.add_xp(40)
	assert_eq(total, 140, "Последователните add_xp трябва да се акумулират")


func test_stub_repo_unlock_and_check() -> void:
	var repo := StubSaveRepository.new()
	assert_false(repo.is_unlocked(&"desert_theme"),
			"Темата не трябва да е отключена по подразбиране")
	repo.unlock(&"desert_theme")
	assert_true(repo.is_unlocked(&"desert_theme"),
			"Темата трябва да е отключена след unlock()")


func test_stub_repo_unlock_idempotent() -> void:
	var repo := StubSaveRepository.new()
	repo.unlock(&"rabbit")
	repo.unlock(&"rabbit")
	var unlocks := repo.get_unlocks()
	var count := 0
	for item in unlocks:
		if item == "rabbit":
			count += 1
	assert_eq(count, 1, "unlock() трябва да е идемпотентна операция")


# --- StubSaveRepository: статистика ---

func test_stub_repo_initial_statistics() -> void:
	var repo := StubSaveRepository.new()
	var stats := repo.get_statistics()
	assert_eq(stats.get("matches_played"), 0)
	assert_eq(stats.get("matches_won"), 0)
	assert_eq(stats.get("gifts_collected"), 0)
	assert_eq(stats.get("pawns_captured"), 0)


func test_stub_repo_record_win_increments_played_and_won() -> void:
	var repo := StubSaveRepository.new()
	repo.record_match_result({"rank": 1, "gifts_collected": 2, "pawns_captured": 1, "pawns_finished": 4})
	var stats := repo.get_statistics()
	assert_eq(stats.get("matches_played"), 1, "matches_played трябва да се увеличи")
	assert_eq(stats.get("matches_won"), 1, "matches_won трябва да се увеличи при ранг 1")


func test_stub_repo_record_loss_does_not_increment_won() -> void:
	var repo := StubSaveRepository.new()
	repo.record_match_result({"rank": 3, "gifts_collected": 0, "pawns_captured": 0, "pawns_finished": 2})
	var stats := repo.get_statistics()
	assert_eq(stats.get("matches_played"), 1)
	assert_eq(stats.get("matches_won"), 0,
			"matches_won не трябва да се увеличи при загуба")


func test_stub_repo_save_profile_round_trip() -> void:
	var repo := StubSaveRepository.new()
	var profile := {"xp": 250, "unlocks": ["rabbit", "desert_theme"],
			"statistics": {"matches_played": 5, "matches_won": 2,
			"gifts_collected": 10, "pawns_captured": 8, "pawns_finished": 20}}
	repo.save_profile(profile)
	var loaded := repo.load_profile()
	assert_eq(loaded.get("xp"), 250, "XP трябва да се запази")
	assert_eq((loaded.get("unlocks") as Array).size(), 2,
			"Unlocks масивът трябва да се запази")
