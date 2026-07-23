extends TestCase
## Unit тестове за StubSaveRepository — in-memory реализация на
## SaveRepository + SettingsRepository + ProgressRepository.

var repo: StubSaveRepository


func setUp() -> void:
	repo = StubSaveRepository.new()


# --- Settings ---

func test_load_settings_returns_defaults_when_empty() -> void:
	var s := repo.load_settings()
	assert_eq(s["music_volume"], 1.0, "default music_volume")
	assert_true(s["haptics_enabled"], "default haptics_enabled")
	assert_false(s["colorblind_mode"], "default colorblind_mode")


func test_save_and_load_settings_round_trip() -> void:
	var data := {"music_volume": 0.5, "sfx_volume": 0.8,
		"haptics_enabled": false, "auto_move_single": false, "colorblind_mode": true}
	var ok := repo.save_settings(data)
	assert_true(ok, "save_settings should succeed")
	var loaded := repo.load_settings()
	assert_eq(loaded["music_volume"], 0.5, "music_volume")
	assert_false(loaded["haptics_enabled"], "haptics_enabled")
	assert_true(loaded["colorblind_mode"], "colorblind_mode")


func test_load_settings_merges_missing_keys_with_defaults() -> void:
	repo.save_settings({"music_volume": 0.3})
	var loaded := repo.load_settings()
	assert_eq(loaded["music_volume"], 0.3, "overridden key")
	assert_eq(loaded["sfx_volume"], 1.0, "default key still present")


func test_get_default_settings_does_not_mutate() -> void:
	var defaults1 := repo.get_default_settings()
	defaults1["music_volume"] = 0.0
	var defaults2 := repo.get_default_settings()
	assert_eq(defaults2["music_volume"], 1.0, "defaults must be isolated copies")


# --- Profile / SaveRepository ---

func test_save_and_load_profile_round_trip() -> void:
	var data := {"xp": 200, "unlocks": ["rabbit"], "statistics": {}}
	assert_true(repo.save_profile(data), "save_profile should succeed")
	var loaded := repo.load_profile()
	assert_eq(loaded["xp"], 200, "xp")
	assert_eq(loaded["unlocks"].size(), 1, "unlocks count")


# --- Match snapshot ---

func test_has_no_snapshot_initially() -> void:
	assert_false(repo.has_match_snapshot(), "no snapshot at start")


func test_save_and_load_match_snapshot() -> void:
	var snap := {"match_id": "m1", "command_sequence": 5}
	assert_true(repo.save_match_snapshot(snap), "save should succeed")
	assert_true(repo.has_match_snapshot(), "has_snapshot after save")
	var loaded := repo.load_match_snapshot()
	assert_eq(loaded["match_id"], "m1", "match_id")
	assert_eq(loaded["command_sequence"], 5, "command_sequence")


func test_clear_match_snapshot() -> void:
	repo.save_match_snapshot({"x": 1})
	assert_true(repo.clear_match_snapshot(), "clear should succeed")
	assert_false(repo.has_match_snapshot(), "no snapshot after clear")
	var loaded := repo.load_match_snapshot()
	assert_true(loaded.is_empty(), "loaded snapshot is empty after clear")


# --- XP ---

func test_get_xp_starts_at_zero() -> void:
	assert_eq(repo.get_xp(), 0, "initial XP is 0")


func test_add_xp_accumulates() -> void:
	var total := repo.add_xp(100)
	assert_eq(total, 100, "first add_xp")
	total = repo.add_xp(40)
	assert_eq(total, 140, "second add_xp")
	assert_eq(repo.get_xp(), 140, "get_xp after adds")


# --- Unlocks ---

func test_is_not_unlocked_initially() -> void:
	assert_false(repo.is_unlocked(&"rabbit"), "rabbit not unlocked initially")


func test_unlock_and_check() -> void:
	repo.unlock(&"rabbit")
	assert_true(repo.is_unlocked(&"rabbit"), "rabbit unlocked after unlock()")
	assert_false(repo.is_unlocked(&"dog"), "dog still locked")


func test_unlock_same_item_twice_does_not_duplicate() -> void:
	repo.unlock(&"pig")
	repo.unlock(&"pig")
	assert_eq(repo.get_unlocks().size(), 1, "no duplicate in unlocks list")


func test_get_unlocks_returns_all_unlocked() -> void:
	repo.unlock(&"pig")
	repo.unlock(&"rabbit")
	repo.unlock(&"dog")
	assert_eq(repo.get_unlocks().size(), 3, "three unlocks")


# --- Statistics ---

func test_get_statistics_returns_zeros_initially() -> void:
	var stats := repo.get_statistics()
	assert_eq(stats.get("matches_played", -1), 0, "matches_played starts at 0")
	assert_eq(stats.get("matches_won", -1), 0, "matches_won starts at 0")


func test_record_match_result_increments_played() -> void:
	repo.record_match_result({"rank": 2, "gifts_collected": 3, "pawns_captured": 1, "pawns_finished": 4})
	var stats := repo.get_statistics()
	assert_eq(stats["matches_played"], 1, "played count")
	assert_eq(stats["matches_won"], 0, "no win for rank 2")
	assert_eq(stats["gifts_collected"], 3, "gifts")
	assert_eq(stats["pawns_captured"], 1, "captures")


func test_record_win_increments_won() -> void:
	repo.record_match_result({"rank": 1, "gifts_collected": 0, "pawns_captured": 0, "pawns_finished": 4})
	var stats := repo.get_statistics()
	assert_eq(stats["matches_won"], 1, "win counted")


func test_multiple_match_results_accumulate() -> void:
	repo.record_match_result({"rank": 1, "gifts_collected": 2, "pawns_captured": 0, "pawns_finished": 4})
	repo.record_match_result({"rank": 2, "gifts_collected": 1, "pawns_captured": 1, "pawns_finished": 2})
	var stats := repo.get_statistics()
	assert_eq(stats["matches_played"], 2, "two matches")
	assert_eq(stats["matches_won"], 1, "one win")
	assert_eq(stats["gifts_collected"], 3, "accumulated gifts")
