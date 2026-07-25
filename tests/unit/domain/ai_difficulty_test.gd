class_name AIDifficultyTest
extends TestCase
## Unit тестове за AIDifficulty (Task #24 / docs/V1_GAME_DESIGN.md §6).
##
## Покрива:
##   - Три нива EASY / MEDIUM / HARD с стабилни int стойности.
##   - is_valid() и difficulty_name().
##   - Domain слой: extends RefCounted, път game/domain/.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_ai_difficulty_extends_ref_counted() -> void:
	var d := AIDifficulty.new()
	assert_true(d is RefCounted,
			"AIDifficulty трябва да extends RefCounted")


func test_ai_difficulty_is_not_node() -> void:
	var d: Object = AIDifficulty.new()
	assert_false(d is Node,
			"AIDifficulty не трябва да extends Node")


func test_ai_difficulty_script_path_is_in_domain() -> void:
	var d := AIDifficulty.new()
	var path: String = d.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"AIDifficulty трябва да е в game/domain/")


# ── Enum стойности ────────────────────────────────────────────────────────────

func test_easy_value_is_zero() -> void:
	assert_eq(AIDifficulty.EASY, 0)


func test_medium_value_is_one() -> void:
	assert_eq(AIDifficulty.MEDIUM, 1)


func test_hard_value_is_two() -> void:
	assert_eq(AIDifficulty.HARD, 2)


func test_count_is_three() -> void:
	assert_eq(AIDifficulty.COUNT, 3)


func test_all_has_exactly_three_entries_in_order() -> void:
	assert_eq(AIDifficulty.ALL.size(), 3)
	assert_eq(AIDifficulty.ALL[0], AIDifficulty.EASY)
	assert_eq(AIDifficulty.ALL[1], AIDifficulty.MEDIUM)
	assert_eq(AIDifficulty.ALL[2], AIDifficulty.HARD)


func test_difficulty_order_is_strictly_increasing() -> void:
	assert_lt(AIDifficulty.EASY, AIDifficulty.MEDIUM)
	assert_lt(AIDifficulty.MEDIUM, AIDifficulty.HARD)


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_levels() -> void:
	for level in AIDifficulty.ALL:
		assert_true(AIDifficulty.is_valid(level),
				"ниво %d трябва да е валидно" % level)


func test_is_valid_rejects_out_of_range() -> void:
	assert_false(AIDifficulty.is_valid(-1))
	assert_false(AIDifficulty.is_valid(3))
	assert_false(AIDifficulty.is_valid(99))


# ── difficulty_name ───────────────────────────────────────────────────────────

func test_difficulty_name_easy() -> void:
	assert_eq(AIDifficulty.difficulty_name(AIDifficulty.EASY), &"EASY")


func test_difficulty_name_medium() -> void:
	assert_eq(AIDifficulty.difficulty_name(AIDifficulty.MEDIUM), &"MEDIUM")


func test_difficulty_name_hard() -> void:
	assert_eq(AIDifficulty.difficulty_name(AIDifficulty.HARD), &"HARD")


func test_difficulty_name_unknown() -> void:
	assert_eq(AIDifficulty.difficulty_name(99), &"UNKNOWN")
