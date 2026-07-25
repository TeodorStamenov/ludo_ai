class_name TurnPhaseTest
extends TestCase
## Unit тестове за TurnPhase enum (docs/V1_ARCHITECTURE.md, §4.2).
##
## Покрити инварианти:
##   - Седемте фази съществуват с очакваните целочислени стойности.
##   - Редът на прогресия е строго нарастващ (MATCH_START < … < MATCH_FINISHED).
##   - is_valid() приема само стойности 0–6.
##   - accepts_command() е true само за AWAITING_ROLL и AWAITING_MOVE.
##   - phase_name() връща правилните имена за всяка фаза.
##   - ALL съдържа точно 7 уникални стойности в ред по прогресия.
##   - COUNT == 7.
##   - COMMAND_ACCEPTING съдържа точно 2 фази.


# ── Архитектурни изисквания ────────────────────────────────────────────────────

func test_turn_phase_extends_ref_counted() -> void:
	var tp := TurnPhase.new()
	assert_true(tp is RefCounted,
			"TurnPhase трябва да extends RefCounted, не Node")


func test_turn_phase_is_not_node() -> void:
	var tp: Object = TurnPhase.new()
	assert_false(tp is Node,
			"TurnPhase не трябва да extends Node — domain слой е без сцени")


func test_turn_phase_script_path_is_in_domain() -> void:
	var tp := TurnPhase.new()
	var path: String = tp.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"TurnPhase трябва да е в game/domain/")


# ── Целочислени стойности ──────────────────────────────────────────────────────

func test_match_start_value_is_zero() -> void:
	assert_eq(TurnPhase.MATCH_START, 0, "MATCH_START трябва да е 0")


func test_awaiting_roll_value_is_one() -> void:
	assert_eq(TurnPhase.AWAITING_ROLL, 1, "AWAITING_ROLL трябва да е 1")


func test_awaiting_move_value_is_two() -> void:
	assert_eq(TurnPhase.AWAITING_MOVE, 2, "AWAITING_MOVE трябва да е 2")


func test_resolving_move_value_is_three() -> void:
	assert_eq(TurnPhase.RESOLVING_MOVE, 3, "RESOLVING_MOVE трябва да е 3")


func test_resolving_power_up_value_is_four() -> void:
	assert_eq(TurnPhase.RESOLVING_POWER_UP, 4, "RESOLVING_POWER_UP трябва да е 4")


func test_turn_end_value_is_five() -> void:
	assert_eq(TurnPhase.TURN_END, 5, "TURN_END трябва да е 5")


func test_match_finished_value_is_six() -> void:
	assert_eq(TurnPhase.MATCH_FINISHED, 6, "MATCH_FINISHED трябва да е 6")


# ── Ред на прогресия ───────────────────────────────────────────────────────────

func test_progression_order_match_start_before_awaiting_roll() -> void:
	assert_lt(TurnPhase.MATCH_START, TurnPhase.AWAITING_ROLL,
			"MATCH_START трябва да е преди AWAITING_ROLL")


func test_progression_order_awaiting_roll_before_awaiting_move() -> void:
	assert_lt(TurnPhase.AWAITING_ROLL, TurnPhase.AWAITING_MOVE,
			"AWAITING_ROLL трябва да е преди AWAITING_MOVE")


func test_progression_order_awaiting_move_before_resolving_move() -> void:
	assert_lt(TurnPhase.AWAITING_MOVE, TurnPhase.RESOLVING_MOVE,
			"AWAITING_MOVE трябва да е преди RESOLVING_MOVE")


func test_progression_order_resolving_move_before_resolving_power_up() -> void:
	assert_lt(TurnPhase.RESOLVING_MOVE, TurnPhase.RESOLVING_POWER_UP,
			"RESOLVING_MOVE трябва да е преди RESOLVING_POWER_UP")


func test_progression_order_resolving_power_up_before_turn_end() -> void:
	assert_lt(TurnPhase.RESOLVING_POWER_UP, TurnPhase.TURN_END,
			"RESOLVING_POWER_UP трябва да е преди TURN_END")


func test_progression_order_turn_end_before_match_finished() -> void:
	assert_lt(TurnPhase.TURN_END, TurnPhase.MATCH_FINISHED,
			"TURN_END трябва да е преди MATCH_FINISHED")


func test_progression_order_is_strictly_increasing() -> void:
	for i in TurnPhase.ALL.size() - 1:
		assert_lt(TurnPhase.ALL[i], TurnPhase.ALL[i + 1],
				"ALL[%d] трябва да е по-малко от ALL[%d]" % [i, i + 1])


# ── COUNT и ALL ────────────────────────────────────────────────────────────────

func test_count_is_seven() -> void:
	assert_eq(TurnPhase.COUNT, 7, "COUNT трябва да е 7")


func test_all_has_exactly_seven_entries() -> void:
	assert_eq(TurnPhase.ALL.size(), 7, "ALL трябва да съдържа точно 7 фази")


func test_all_entries_match_enum_values_in_order() -> void:
	assert_eq(TurnPhase.ALL[0], TurnPhase.MATCH_START,        "ALL[0] трябва да е MATCH_START")
	assert_eq(TurnPhase.ALL[1], TurnPhase.AWAITING_ROLL,      "ALL[1] трябва да е AWAITING_ROLL")
	assert_eq(TurnPhase.ALL[2], TurnPhase.AWAITING_MOVE,      "ALL[2] трябва да е AWAITING_MOVE")
	assert_eq(TurnPhase.ALL[3], TurnPhase.RESOLVING_MOVE,     "ALL[3] трябва да е RESOLVING_MOVE")
	assert_eq(TurnPhase.ALL[4], TurnPhase.RESOLVING_POWER_UP, "ALL[4] трябва да е RESOLVING_POWER_UP")
	assert_eq(TurnPhase.ALL[5], TurnPhase.TURN_END,           "ALL[5] трябва да е TURN_END")
	assert_eq(TurnPhase.ALL[6], TurnPhase.MATCH_FINISHED,     "ALL[6] трябва да е MATCH_FINISHED")


func test_all_entries_are_unique() -> void:
	var seen: Dictionary = {}
	for phase in TurnPhase.ALL:
		assert_false(seen.has(phase),
				"TurnPhase.ALL съдържа дублирана стойност: %d" % phase)
		seen[phase] = true


func test_all_size_equals_count() -> void:
	assert_eq(TurnPhase.ALL.size(), TurnPhase.COUNT,
			"ALL.size() трябва да съответства на COUNT")


# ── is_valid ───────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_phases() -> void:
	for phase in TurnPhase.ALL:
		assert_true(TurnPhase.is_valid(phase),
				"is_valid трябва да приема фаза %d" % phase)


func test_is_valid_rejects_negative() -> void:
	assert_false(TurnPhase.is_valid(-1), "is_valid трябва да отхвърли -1")


func test_is_valid_rejects_count() -> void:
	assert_false(TurnPhase.is_valid(TurnPhase.COUNT),
			"is_valid трябва да отхвърли COUNT (%d)" % TurnPhase.COUNT)


func test_is_valid_rejects_large_integer() -> void:
	assert_false(TurnPhase.is_valid(999), "is_valid трябва да отхвърли 999")


func test_is_valid_rejects_boundary_above() -> void:
	assert_false(TurnPhase.is_valid(7), "is_valid трябва да отхвърли 7")


# ── accepts_command ────────────────────────────────────────────────────────────

func test_accepts_command_true_for_awaiting_roll() -> void:
	assert_true(TurnPhase.accepts_command(TurnPhase.AWAITING_ROLL),
			"accepts_command трябва да е true за AWAITING_ROLL")


func test_accepts_command_true_for_awaiting_move() -> void:
	assert_true(TurnPhase.accepts_command(TurnPhase.AWAITING_MOVE),
			"accepts_command трябва да е true за AWAITING_MOVE")


func test_accepts_command_false_for_match_start() -> void:
	assert_false(TurnPhase.accepts_command(TurnPhase.MATCH_START),
			"accepts_command трябва да е false за MATCH_START")


func test_accepts_command_false_for_resolving_move() -> void:
	assert_false(TurnPhase.accepts_command(TurnPhase.RESOLVING_MOVE),
			"accepts_command трябва да е false за RESOLVING_MOVE")


func test_accepts_command_false_for_resolving_power_up() -> void:
	assert_false(TurnPhase.accepts_command(TurnPhase.RESOLVING_POWER_UP),
			"accepts_command трябва да е false за RESOLVING_POWER_UP")


func test_accepts_command_false_for_turn_end() -> void:
	assert_false(TurnPhase.accepts_command(TurnPhase.TURN_END),
			"accepts_command трябва да е false за TURN_END")


func test_accepts_command_false_for_match_finished() -> void:
	assert_false(TurnPhase.accepts_command(TurnPhase.MATCH_FINISHED),
			"accepts_command трябва да е false за MATCH_FINISHED")


func test_command_accepting_has_exactly_two_entries() -> void:
	assert_eq(TurnPhase.COMMAND_ACCEPTING.size(), 2,
			"COMMAND_ACCEPTING трябва да съдържа точно 2 фази")


func test_command_accepting_contains_awaiting_roll_and_awaiting_move() -> void:
	assert_true(TurnPhase.AWAITING_ROLL in TurnPhase.COMMAND_ACCEPTING,
			"COMMAND_ACCEPTING трябва да съдържа AWAITING_ROLL")
	assert_true(TurnPhase.AWAITING_MOVE in TurnPhase.COMMAND_ACCEPTING,
			"COMMAND_ACCEPTING трябва да съдържа AWAITING_MOVE")


# ── phase_name ─────────────────────────────────────────────────────────────────

func test_phase_name_match_start() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.MATCH_START), &"MATCH_START",
			"phase_name(MATCH_START) трябва да върне &\"MATCH_START\"")


func test_phase_name_awaiting_roll() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.AWAITING_ROLL), &"AWAITING_ROLL",
			"phase_name(AWAITING_ROLL) трябва да върне &\"AWAITING_ROLL\"")


func test_phase_name_awaiting_move() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.AWAITING_MOVE), &"AWAITING_MOVE",
			"phase_name(AWAITING_MOVE) трябва да върне &\"AWAITING_MOVE\"")


func test_phase_name_resolving_move() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.RESOLVING_MOVE), &"RESOLVING_MOVE",
			"phase_name(RESOLVING_MOVE) трябва да върне &\"RESOLVING_MOVE\"")


func test_phase_name_resolving_power_up() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.RESOLVING_POWER_UP), &"RESOLVING_POWER_UP",
			"phase_name(RESOLVING_POWER_UP) трябва да върне &\"RESOLVING_POWER_UP\"")


func test_phase_name_turn_end() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.TURN_END), &"TURN_END",
			"phase_name(TURN_END) трябва да върне &\"TURN_END\"")


func test_phase_name_match_finished() -> void:
	assert_eq(TurnPhase.phase_name(TurnPhase.MATCH_FINISHED), &"MATCH_FINISHED",
			"phase_name(MATCH_FINISHED) трябва да върне &\"MATCH_FINISHED\"")


func test_phase_name_invalid_returns_unknown() -> void:
	assert_eq(TurnPhase.phase_name(-1), &"UNKNOWN",
			"phase_name(-1) трябва да върне &\"UNKNOWN\"")
	assert_eq(TurnPhase.phase_name(99), &"UNKNOWN",
			"phase_name(99) трябва да върне &\"UNKNOWN\"")


func test_phase_name_all_phases_match_their_names() -> void:
	var expected: Array[StringName] = [
		&"MATCH_START", &"AWAITING_ROLL", &"AWAITING_MOVE",
		&"RESOLVING_MOVE", &"RESOLVING_POWER_UP", &"TURN_END", &"MATCH_FINISHED",
	]
	for i in TurnPhase.ALL.size():
		assert_eq(TurnPhase.phase_name(TurnPhase.ALL[i]), expected[i],
				"phase_name(ALL[%d]) трябва да е &\"%s\"" % [i, expected[i]])
