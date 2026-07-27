class_name MatchBatchSimulator
extends RefCounted
## Headless batch от AI-vs-AI мачове без Presentation / сцена
## (docs/V1_ARCHITECTURE.md §12; roadmap #140).
##
## Обвива MatchSimulator: различни seed-ове, агрегирана статистика и
## крайни инварианти (finished + GameState.is_valid + стабилен ranking).
## Mid-match runtime checks → #142; stuck command limit → #141.
##
## STRESS_MATCH_COUNT = 1000 е офлайн цел. CI тестовете ползват по-малък
## брой заради suite timeout.


const KEY_OK := "ok"
const KEY_MATCH_COUNT := "match_count"
const KEY_FINISHED_COUNT := "finished_count"
const KEY_FAILED_COUNT := "failed_count"
const KEY_FAILURES := "failures"
const KEY_TOTAL_COMMANDS := "total_commands"
const KEY_TOTAL_STEPS := "total_steps"
const KEY_ERROR := "error"

const FAILURE_SEED := "seed"
const FAILURE_SEAT_COUNT := "seat_count"
const FAILURE_ERROR := "error"
const FAILURE_HIT_LIMIT := "hit_limit"
const FAILURE_COMMAND_COUNT := "command_count"
const FAILURE_STEPS := "steps"

## Офлайн stress цел (§12 thousands_of_matches).
const STRESS_MATCH_COUNT := 1000
## Колко failure записа да задържим (първите N).
const MAX_REPORTED_FAILURES := 16
## Прост stride между seed-ове — намалява корелацията на близки индекси.
const DEFAULT_SEED_STRIDE := 997

var _simulator: MatchSimulator = null


func _init(simulator: MatchSimulator = null) -> void:
	_simulator = simulator


## Пуска match_count AI мача с seat_count seats.
## seed_i = base_seed + i * seed_stride. Връща агрегат; ok само ако всички минат.
func run(
		match_count: int,
		base_seed: int = 1,
		seat_count: int = 2,
		max_steps_per_match: int = MatchSimulator.DEFAULT_MAX_STEPS,
		seed_stride: int = DEFAULT_SEED_STRIDE,
		difficulty: int = AIDifficulty.EASY
) -> Dictionary:
	if match_count <= 0:
		return _failure("match_count must be positive")
	if seat_count < MatchConfig.MIN_SEATS or seat_count > MatchConfig.MAX_SEATS:
		return _failure("seat_count must be in [%d, %d]" % [
				MatchConfig.MIN_SEATS, MatchConfig.MAX_SEATS])
	if seed_stride == 0:
		return _failure("seed_stride must be non-zero")
	if max_steps_per_match <= 0:
		return _failure("max_steps_per_match must be positive")

	var counts: Dictionary = {seat_count: match_count}
	return run_mixed(counts, base_seed, max_steps_per_match, seed_stride, difficulty)


## Пуска смесен batch: counts_by_seats = {2: N2, 3: N3, 4: N4}.
## Ред: ascending seat_count, после index вътре в групата.
func run_mixed(
		counts_by_seats: Dictionary,
		base_seed: int = 1,
		max_steps_per_match: int = MatchSimulator.DEFAULT_MAX_STEPS,
		seed_stride: int = DEFAULT_SEED_STRIDE,
		difficulty: int = AIDifficulty.EASY
) -> Dictionary:
	if counts_by_seats.is_empty():
		return _failure("counts_by_seats is empty")
	if seed_stride == 0:
		return _failure("seed_stride must be non-zero")
	if max_steps_per_match <= 0:
		return _failure("max_steps_per_match must be positive")

	var ordered_seats: Array[int] = []
	var planned_total := 0
	for key in counts_by_seats.keys():
		var seats: int = int(key)
		var count: int = int(counts_by_seats[key])
		if seats < MatchConfig.MIN_SEATS or seats > MatchConfig.MAX_SEATS:
			return _failure("invalid seat_count %d" % seats)
		if count < 0:
			return _failure("negative match count for seat_count %d" % seats)
		if count == 0:
			continue
		ordered_seats.append(seats)
		planned_total += count
	if planned_total <= 0:
		return _failure("total match_count must be positive")
	ordered_seats.sort()

	var simulator: MatchSimulator = (
			_simulator if _simulator != null else MatchSimulator.new())
	var finished_count := 0
	var failed_count := 0
	var failures: Array = []
	var total_commands := 0
	var total_steps := 0
	var match_index := 0

	for seats in ordered_seats:
		var group_count: int = int(counts_by_seats[seats])
		for i in group_count:
			var rng_seed: int = base_seed + match_index * seed_stride
			match_index += 1
			var config := MatchSimulator.make_ai_config(rng_seed, seats, difficulty)
			var result: Dictionary = simulator.run(config, max_steps_per_match)
			total_commands += int(result.get(MatchSimulator.KEY_COMMAND_COUNT, 0))
			total_steps += int(result.get(MatchSimulator.KEY_STEPS, 0))

			var end_error := _end_invariant_error(
					result, seats)
			if end_error.is_empty():
				finished_count += 1
				continue

			failed_count += 1
			if failures.size() < MAX_REPORTED_FAILURES:
				failures.append({
					FAILURE_SEED: rng_seed,
					FAILURE_SEAT_COUNT: seats,
					FAILURE_ERROR: end_error,
					FAILURE_HIT_LIMIT: bool(result.get(
							MatchSimulator.KEY_HIT_LIMIT, false)),
					FAILURE_COMMAND_COUNT: int(result.get(
							MatchSimulator.KEY_COMMAND_COUNT, 0)),
					FAILURE_STEPS: int(result.get(MatchSimulator.KEY_STEPS, 0)),
				})

	var ok := failed_count == 0
	return {
		KEY_OK: ok,
		KEY_MATCH_COUNT: planned_total,
		KEY_FINISHED_COUNT: finished_count,
		KEY_FAILED_COUNT: failed_count,
		KEY_FAILURES: failures,
		KEY_TOTAL_COMMANDS: total_commands,
		KEY_TOTAL_STEPS: total_steps,
		KEY_ERROR: "" if ok else _format_batch_error(failed_count, failures),
	}


func _end_invariant_error(result: Dictionary, seat_count: int) -> String:
	if not bool(result.get(MatchSimulator.KEY_OK, false)):
		var sim_err := str(result.get(MatchSimulator.KEY_ERROR, "simulation failed"))
		return sim_err if not sim_err.is_empty() else "simulation failed"
	if not bool(result.get(MatchSimulator.KEY_FINISHED, false)):
		return "match did not finish"
	var state: GameState = result.get(MatchSimulator.KEY_STATE) as GameState
	if state == null:
		return "finished match has null state"
	if not state.is_finished():
		return "state.is_finished() is false"
	if not state.is_valid():
		return "state.is_valid() failed"
	if state.player_count() != seat_count:
		return "player_count %d != seat_count %d" % [state.player_count(), seat_count]
	if state.ranking.size() != seat_count:
		return "ranking size %d != seat_count %d" % [state.ranking.size(), seat_count]
	var summary: Dictionary = result.get(MatchSimulator.KEY_SUMMARY, {})
	if summary.is_empty():
		return "empty MatchSummary"
	var match_result := MatchResult.create_from_game_state(state)
	if not match_result.is_valid():
		return "MatchResult.is_valid() failed"
	if match_result.player_count() != seat_count:
		return "MatchResult.player_count mismatch"
	return ""


func _format_batch_error(failed_count: int, failures: Array) -> String:
	if failures.is_empty():
		return "%d match(es) failed" % failed_count
	var first: Dictionary = failures[0]
	return "%d match(es) failed; first seed=%d seats=%d: %s" % [
			failed_count,
			int(first.get(FAILURE_SEED, 0)),
			int(first.get(FAILURE_SEAT_COUNT, 0)),
			str(first.get(FAILURE_ERROR, "")),
	]


func _failure(message: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_MATCH_COUNT: 0,
		KEY_FINISHED_COUNT: 0,
		KEY_FAILED_COUNT: 0,
		KEY_FAILURES: [],
		KEY_TOTAL_COMMANDS: 0,
		KEY_TOTAL_STEPS: 0,
		KEY_ERROR: message,
	}
