extends TestCase
## Симулационен тест: пълен мач без сцена
## (Task #139 / #141 / docs/V1_ARCHITECTURE.md §12 / §16.1).
##
## Критични инварианти:
##   - AI-vs-AI мач достига MATCH_FINISHED без Presentation/сцена;
##   - ranking е пълен и валиден;
##   - еднакъв seed + FirstLegalAIPolicy → еднакъв final state hash;
##   - надхвърлен max_commands → hit_limit / stuck (#141).


func before_each() -> void:
	MatchId._reset_counter_for_tests()


func test_full_two_player_match_finishes_without_scene() -> void:
	var result := MatchSimulator.new().run(
			MatchSimulator.make_ai_config(4242, 2),
			MatchSimulator.DEFAULT_MAX_COMMANDS)
	assert_true(result[MatchSimulator.KEY_OK],
			str(result.get(MatchSimulator.KEY_ERROR, "")))
	assert_true(result[MatchSimulator.KEY_FINISHED])
	assert_false(result[MatchSimulator.KEY_HIT_LIMIT])
	assert_true(int(result[MatchSimulator.KEY_COMMAND_COUNT]) > 2,
			"full match needs more than StartMatch")
	assert_true(int(result[MatchSimulator.KEY_COMMAND_COUNT])
			< MatchSimulator.DEFAULT_MAX_COMMANDS)

	var state: GameState = result[MatchSimulator.KEY_STATE]
	assert_not_null(state)
	assert_true(state.is_finished())
	assert_eq(state.ranking.size(), 2)

	var summary: Dictionary = result[MatchSimulator.KEY_SUMMARY]
	assert_false(summary.is_empty(), "MatchFinished must produce MatchSummary")
	assert_true(summary.has("ranking") or summary.has("match_id"),
			"summary should carry MatchResult fields")


func test_same_seed_produces_identical_final_hash() -> void:
	const SEED := 13579
	var a := MatchSimulator.new().run(MatchSimulator.make_ai_config(SEED, 2))
	MatchId._reset_counter_for_tests()
	var b := MatchSimulator.new().run(MatchSimulator.make_ai_config(SEED, 2))
	assert_true(a[MatchSimulator.KEY_OK], str(a.get(MatchSimulator.KEY_ERROR, "")))
	assert_true(b[MatchSimulator.KEY_OK], str(b.get(MatchSimulator.KEY_ERROR, "")))
	var state_a: GameState = a[MatchSimulator.KEY_STATE]
	var state_b: GameState = b[MatchSimulator.KEY_STATE]
	assert_eq(state_a.compute_hash(), state_b.compute_hash(),
			"same seed + FirstLegal must yield identical final state hash")
	assert_eq(int(a[MatchSimulator.KEY_COMMAND_COUNT]),
			int(b[MatchSimulator.KEY_COMMAND_COUNT]))


func test_hit_max_commands_reports_stuck_match() -> void:
	## Command-limit stuck detection (#141).
	var result := MatchSimulator.new().run(
			MatchSimulator.make_ai_config(7, 2),
			2)
	assert_false(result[MatchSimulator.KEY_OK])
	assert_true(result[MatchSimulator.KEY_HIT_LIMIT])
	assert_false(result[MatchSimulator.KEY_FINISHED])
	assert_true(int(result[MatchSimulator.KEY_COMMAND_COUNT]) >= 2)
	var err := str(result[MatchSimulator.KEY_ERROR])
	assert_true(err.contains("max_commands"), err)
	assert_true(err.contains("stuck"), err)
