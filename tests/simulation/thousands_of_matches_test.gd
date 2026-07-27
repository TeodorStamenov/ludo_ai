extends TestCase
## Симулационен тест: batch от AI мачове без сцена
## (Task #140 / docs/V1_ARCHITECTURE.md §12).
##
## Критични инварианти върху реален MatchSimulator:
##   - всеки мач достига MATCH_FINISHED;
##   - GameState.is_valid() + пълен ranking;
##   - MatchResult / MatchSummary са валидни;
##   - еднакъв base_seed → детерминистичен агрегат.
##
## CI ползва малък брой (suite timeout ~120s). Офлайн stress:
## MatchBatchSimulator.run(MatchBatchSimulator.STRESS_MATCH_COUNT).


## Достатъчно seed diversity за CI без да душим suite timeout.
const CI_MATCH_COUNT_2P := 8
const CI_MATCH_COUNT_3P := 1
const CI_MATCH_COUNT_4P := 1


func before_each() -> void:
	MatchId._reset_counter_for_tests()


func test_batch_two_player_matches_all_finish() -> void:
	var batch := MatchBatchSimulator.new().run(CI_MATCH_COUNT_2P, 10_001, 2)
	assert_true(batch[MatchBatchSimulator.KEY_OK],
			str(batch.get(MatchBatchSimulator.KEY_ERROR, "")))
	assert_eq(int(batch[MatchBatchSimulator.KEY_MATCH_COUNT]), CI_MATCH_COUNT_2P)
	assert_eq(int(batch[MatchBatchSimulator.KEY_FINISHED_COUNT]), CI_MATCH_COUNT_2P)
	assert_eq(int(batch[MatchBatchSimulator.KEY_FAILED_COUNT]), 0)
	assert_true(int(batch[MatchBatchSimulator.KEY_TOTAL_COMMANDS]) > CI_MATCH_COUNT_2P * 2,
			"each finished match needs more than StartMatch")
	assert_true((batch[MatchBatchSimulator.KEY_FAILURES] as Array).is_empty())


func test_batch_mixed_seat_counts_finish_with_stable_ranking() -> void:
	var counts: Dictionary = {
		2: 2,
		3: CI_MATCH_COUNT_3P,
		4: CI_MATCH_COUNT_4P,
	}
	var batch := MatchBatchSimulator.new().run_mixed(counts, 42_042)
	assert_true(batch[MatchBatchSimulator.KEY_OK],
			str(batch.get(MatchBatchSimulator.KEY_ERROR, "")))
	var expected: int = 2 + CI_MATCH_COUNT_3P + CI_MATCH_COUNT_4P
	assert_eq(int(batch[MatchBatchSimulator.KEY_FINISHED_COUNT]), expected)
	assert_eq(int(batch[MatchBatchSimulator.KEY_FAILED_COUNT]), 0)


func test_same_base_seed_batch_is_deterministic() -> void:
	const BASE := 77_777
	const N := 3
	var a := MatchBatchSimulator.new().run(N, BASE, 2)
	var b := MatchBatchSimulator.new().run(N, BASE, 2)
	assert_true(a[MatchBatchSimulator.KEY_OK], str(a.get(MatchBatchSimulator.KEY_ERROR, "")))
	assert_true(b[MatchBatchSimulator.KEY_OK], str(b.get(MatchBatchSimulator.KEY_ERROR, "")))
	assert_eq(int(a[MatchBatchSimulator.KEY_TOTAL_COMMANDS]),
			int(b[MatchBatchSimulator.KEY_TOTAL_COMMANDS]))
	assert_eq(int(a[MatchBatchSimulator.KEY_TOTAL_STEPS]),
			int(b[MatchBatchSimulator.KEY_TOTAL_STEPS]))

	var spot := MatchSimulator.new().run(MatchSimulator.make_ai_config(BASE, 2))
	var spot_again := MatchSimulator.new().run(MatchSimulator.make_ai_config(BASE, 2))
	assert_true(spot[MatchSimulator.KEY_OK])
	assert_true(spot_again[MatchSimulator.KEY_OK])
	var state_a: GameState = spot[MatchSimulator.KEY_STATE]
	var state_b: GameState = spot_again[MatchSimulator.KEY_STATE]
	assert_eq(state_a.compute_hash(), state_b.compute_hash(),
			"same seed + FirstLegal must yield identical final state hash")


func test_rejects_invalid_batch_parameters() -> void:
	var bad_count := MatchBatchSimulator.new().run(0, 1, 2)
	assert_false(bad_count[MatchBatchSimulator.KEY_OK])
	assert_true(str(bad_count[MatchBatchSimulator.KEY_ERROR]).contains("match_count"))

	var bad_seats := MatchBatchSimulator.new().run(1, 1, 1)
	assert_false(bad_seats[MatchBatchSimulator.KEY_OK])
	assert_true(str(bad_seats[MatchBatchSimulator.KEY_ERROR]).contains("seat_count"))

	var bad_mixed := MatchBatchSimulator.new().run_mixed({})
	assert_false(bad_mixed[MatchBatchSimulator.KEY_OK])


func test_hit_max_steps_is_reported_in_failures() -> void:
	var batch := MatchBatchSimulator.new().run(1, 7, 2, 2)
	assert_false(batch[MatchBatchSimulator.KEY_OK])
	assert_eq(int(batch[MatchBatchSimulator.KEY_FAILED_COUNT]), 1)
	var failures: Array = batch[MatchBatchSimulator.KEY_FAILURES]
	assert_eq(failures.size(), 1)
	var first: Dictionary = failures[0]
	assert_true(bool(first[MatchBatchSimulator.FAILURE_HIT_LIMIT]))
	assert_true(str(first[MatchBatchSimulator.FAILURE_ERROR]).contains("max_steps"))
