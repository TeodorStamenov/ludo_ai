class_name MatchPhaseTest
extends TestCase
## Unit тестове за MatchPhase enum (docs/V1_ARCHITECTURE.md, §4.1).
##
## Покрити инварианти:
##   - Трите фази съществуват с очакваните целочислени стойности.
##   - Редът на прогресия SETUP < IN_PROGRESS < FINISHED е гарантиран.
##   - is_valid() приема само стойности 0–2.
##   - phase_name() връща правилните имена за всяка фаза.
##   - ALL съдържа точно 3 уникални стойности в ред по прогресия.
##   - COUNT == 3.


# ── Архитектурни изисквания ────────────────────────────────────────────────────

func test_match_phase_extends_ref_counted() -> void:
	var mp := MatchPhase.new()
	assert_true(mp is RefCounted,
			"MatchPhase трябва да extends RefCounted, не Node")


func test_match_phase_is_not_node() -> void:
	var mp: Object = MatchPhase.new()
	assert_false(mp is Node,
			"MatchPhase не трябва да extends Node — domain слой е без сцени")


func test_match_phase_script_path_is_in_domain() -> void:
	var mp := MatchPhase.new()
	var path: String = mp.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"MatchPhase трябва да е в game/domain/")


# ── Целочислени стойности ──────────────────────────────────────────────────────

func test_setup_value_is_zero() -> void:
	assert_eq(MatchPhase.SETUP, 0, "SETUP трябва да е 0")


func test_in_progress_value_is_one() -> void:
	assert_eq(MatchPhase.IN_PROGRESS, 1, "IN_PROGRESS трябва да е 1")


func test_finished_value_is_two() -> void:
	assert_eq(MatchPhase.FINISHED, 2, "FINISHED трябва да е 2")


# ── Ред на прогресия ───────────────────────────────────────────────────────────

func test_progression_order_setup_before_in_progress() -> void:
	assert_lt(MatchPhase.SETUP, MatchPhase.IN_PROGRESS,
			"SETUP трябва да е преди IN_PROGRESS в прогресията")


func test_progression_order_in_progress_before_finished() -> void:
	assert_lt(MatchPhase.IN_PROGRESS, MatchPhase.FINISHED,
			"IN_PROGRESS трябва да е преди FINISHED в прогресията")


func test_progression_order_is_strictly_increasing() -> void:
	for i in MatchPhase.ALL.size() - 1:
		assert_lt(MatchPhase.ALL[i], MatchPhase.ALL[i + 1],
				"ALL[%d] трябва да е по-малко от ALL[%d]" % [i, i + 1])


# ── COUNT и ALL ────────────────────────────────────────────────────────────────

func test_count_is_three() -> void:
	assert_eq(MatchPhase.COUNT, 3, "COUNT трябва да е 3")


func test_all_has_exactly_three_entries() -> void:
	assert_eq(MatchPhase.ALL.size(), 3, "ALL трябва да съдържа точно 3 фази")


func test_all_entries_match_enum_values_in_order() -> void:
	assert_eq(MatchPhase.ALL[0], MatchPhase.SETUP,       "ALL[0] трябва да е SETUP")
	assert_eq(MatchPhase.ALL[1], MatchPhase.IN_PROGRESS, "ALL[1] трябва да е IN_PROGRESS")
	assert_eq(MatchPhase.ALL[2], MatchPhase.FINISHED,    "ALL[2] трябва да е FINISHED")


func test_all_entries_are_unique() -> void:
	var seen: Dictionary = {}
	for phase in MatchPhase.ALL:
		assert_false(seen.has(phase),
				"MatchPhase.ALL съдържа дублирана стойност: %d" % phase)
		seen[phase] = true


func test_all_size_equals_count() -> void:
	assert_eq(MatchPhase.ALL.size(), MatchPhase.COUNT,
			"ALL.size() трябва да съответства на COUNT")


# ── is_valid ───────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_phases() -> void:
	for phase in MatchPhase.ALL:
		assert_true(MatchPhase.is_valid(phase),
				"is_valid трябва да приема фаза %d" % phase)


func test_is_valid_rejects_negative() -> void:
	assert_false(MatchPhase.is_valid(-1), "is_valid трябва да отхвърли -1")


func test_is_valid_rejects_count() -> void:
	assert_false(MatchPhase.is_valid(MatchPhase.COUNT),
			"is_valid трябва да отхвърли COUNT (%d)" % MatchPhase.COUNT)


func test_is_valid_rejects_large_integer() -> void:
	assert_false(MatchPhase.is_valid(999), "is_valid трябва да отхвърли 999")


func test_is_valid_rejects_boundary_above() -> void:
	assert_false(MatchPhase.is_valid(3), "is_valid трябва да отхвърли 3")


# ── phase_name ─────────────────────────────────────────────────────────────────

func test_phase_name_setup() -> void:
	assert_eq(MatchPhase.phase_name(MatchPhase.SETUP), &"SETUP",
			"phase_name(SETUP) трябва да върне &\"SETUP\"")


func test_phase_name_in_progress() -> void:
	assert_eq(MatchPhase.phase_name(MatchPhase.IN_PROGRESS), &"IN_PROGRESS",
			"phase_name(IN_PROGRESS) трябва да върне &\"IN_PROGRESS\"")


func test_phase_name_finished() -> void:
	assert_eq(MatchPhase.phase_name(MatchPhase.FINISHED), &"FINISHED",
			"phase_name(FINISHED) трябва да върне &\"FINISHED\"")


func test_phase_name_invalid_returns_unknown() -> void:
	assert_eq(MatchPhase.phase_name(-1), &"UNKNOWN",
			"phase_name(-1) трябва да върне &\"UNKNOWN\"")
	assert_eq(MatchPhase.phase_name(99), &"UNKNOWN",
			"phase_name(99) трябва да върне &\"UNKNOWN\"")


func test_phase_name_all_phases_match_their_names() -> void:
	var expected: Array[StringName] = [&"SETUP", &"IN_PROGRESS", &"FINISHED"]
	for i in MatchPhase.ALL.size():
		assert_eq(MatchPhase.phase_name(MatchPhase.ALL[i]), expected[i],
				"phase_name(ALL[%d]) трябва да е &\"%s\"" % [i, expected[i]])
