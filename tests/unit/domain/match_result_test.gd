class_name MatchResultTest
extends TestCase
## Unit тестове за MatchResult / PlayerStanding (Task #56 /
## docs/V1_ARCHITECTURE.md §4 / §5.2; docs/V1_GAME_DESIGN.md §3.1 / §5.2–5.3).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath/XP.
##   - Полета: schema_version, match_id, mode, campaign_level_id?, ranking[].
##   - PlayerStanding: rank + gifts/captures/finished за XP бонуси.
##   - Фабрики create / create_with_rank_order.
##   - Helpers: winner, get_standing, totals, to_player_summary.
##   - is_valid() инварианти (2–4 играчи, уникални ranks 1..N).
##   - Сериализация to_dict / from_dict / to_json / equals / duplicate_result.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_match_result_extends_ref_counted() -> void:
	var result := MatchResult.new()
	assert_true(result is RefCounted,
			"MatchResult трябва да extends RefCounted, не Node")


func test_match_result_is_not_node() -> void:
	var result: Object = MatchResult.new()
	assert_false(result is Node,
			"MatchResult не трябва да extends Node — domain слой е без сцени")


func test_match_result_script_path_is_in_domain_model() -> void:
	var result := MatchResult.new()
	var path: String = result.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"MatchResult трябва да е в game/domain/model/")


func test_player_standing_extends_ref_counted() -> void:
	var standing := MatchResult.PlayerStanding.new()
	assert_true(standing is RefCounted,
			"PlayerStanding трябва да extends RefCounted")


func test_to_dict_has_no_presentation_or_xp_fields() -> void:
	var result := _valid_two_player_result()
	var d := result.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от MatchResult")
	assert_false(d.has("node_path"), "NodePath не е част от MatchResult")
	assert_false(d.has("xp"), "XP се изчислява в Application, не в MatchResult")
	assert_false(d.has("xp_earned"), "xp_earned не е domain поле")
	assert_false(d.has("texture"), "texture не е част от domain MatchResult")


# ── Константи и подразбирания ─────────────────────────────────────────────────

func test_schema_and_player_bounds() -> void:
	assert_eq(MatchResult.SCHEMA_VERSION, 1)
	assert_eq(MatchResult.MIN_PLAYERS, 2)
	assert_eq(MatchResult.MAX_PLAYERS, 4)
	assert_eq(MatchResult.MIN_PLAYERS, MatchConfig.MIN_SEATS)
	assert_eq(MatchResult.MAX_PLAYERS, MatchConfig.MAX_SEATS)


func test_is_schema_supported() -> void:
	assert_true(MatchResult.is_schema_supported(MatchResult.SCHEMA_VERSION))
	assert_false(MatchResult.is_schema_supported(0))
	assert_false(MatchResult.is_schema_supported(MatchResult.SCHEMA_VERSION + 1))


func test_default_fields_are_invalid() -> void:
	var result := MatchResult.new()
	assert_eq(result.schema_version, MatchResult.SCHEMA_VERSION)
	assert_eq(result.match_id, &"")
	assert_eq(result.mode, MatchConfig.Mode.FREE_PLAY)
	assert_eq(result.campaign_level_id, &"")
	assert_eq(result.ranking.size(), 0)
	assert_false(result.is_valid(),
			"празен match_id / ranking → is_valid() == false")


# ── PlayerStanding ────────────────────────────────────────────────────────────

func test_player_standing_create_sets_all_fields() -> void:
	var standing := MatchResult.PlayerStanding.create(
			PlayerId.GREEN, 1, AnimalId.HEN, MatchConfig.ControllerType.AI,
			3, 2, 4)
	assert_eq(standing.player_id, PlayerId.GREEN)
	assert_eq(standing.rank, 1)
	assert_eq(standing.animal_id, AnimalId.HEN)
	assert_eq(standing.controller_type, MatchConfig.ControllerType.AI)
	assert_eq(standing.gifts_collected, 3)
	assert_eq(standing.pawns_captured, 2)
	assert_eq(standing.pawns_finished, 4)
	assert_true(standing.is_winner())
	assert_true(standing.is_ai())
	assert_true(standing.is_valid())


func test_player_standing_to_progress_summary_keys() -> void:
	var standing := MatchResult.PlayerStanding.create(
			PlayerId.YELLOW, 2, AnimalId.DOG, MatchConfig.ControllerType.HUMAN,
			1, 0, 3)
	var summary := standing.to_progress_summary()
	assert_eq(summary.get("rank"), 2)
	assert_eq(summary.get("gifts_collected"), 1)
	assert_eq(summary.get("pawns_captured"), 0)
	assert_eq(summary.get("pawns_finished"), 3)
	assert_eq(summary.size(), 4,
			"progress summary трябва да е плосък договор за SaveRepository")


func test_player_standing_is_valid_rejects_bad_stats() -> void:
	var bad_rank := MatchResult.PlayerStanding.create(PlayerId.GREEN, 0)
	assert_false(bad_rank.is_valid(), "rank 0 (UNRANKED) не е валиден във финал")
	var bad_finished := MatchResult.PlayerStanding.create(
			PlayerId.GREEN, 1, AnimalId.PIG, MatchConfig.ControllerType.HUMAN,
			0, 0, 5)
	assert_false(bad_finished.is_valid(), "pawns_finished > 4")
	var negative := MatchResult.PlayerStanding.create(
			PlayerId.GREEN, 1, AnimalId.PIG, MatchConfig.ControllerType.HUMAN,
			-1, 0, 0)
	assert_false(negative.is_valid(), "отрицателни gifts")


func test_player_standing_round_trip() -> void:
	var standing := MatchResult.PlayerStanding.create(
			PlayerId.ORANGE, 3, AnimalId.COW, MatchConfig.ControllerType.REMOTE,
			2, 1, 2)
	var restored := MatchResult.PlayerStanding.from_dict(standing.to_dict())
	assert_true(standing.equals(restored))
	assert_true(restored.is_valid())


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_fields() -> void:
	MatchId._reset_counter_for_tests()
	var match_id := MatchId.generate()
	var ranking: Array = [
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
		MatchResult.PlayerStanding.create(PlayerId.YELLOW, 2),
	]
	var result := MatchResult.create(match_id, ranking)
	assert_eq(result.match_id, match_id)
	assert_eq(result.player_count(), 2)
	assert_true(result.is_free_play())
	assert_true(result.is_valid())


func test_create_with_rank_order_assigns_ranks() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create_with_rank_order(
			MatchId.generate(),
			[PlayerId.YELLOW, PlayerId.GREEN, PlayerId.ORANGE])
	assert_eq(result.player_count(), 3)
	assert_eq(result.get_ranked_player_ids(),
			[PlayerId.YELLOW, PlayerId.GREEN, PlayerId.ORANGE] as Array[StringName])
	assert_eq(result.get_standing(PlayerId.YELLOW).rank, 1)
	assert_eq(result.get_standing(PlayerId.GREEN).rank, 2)
	assert_eq(result.get_standing(PlayerId.ORANGE).rank, 3)
	assert_true(result.is_valid())


func test_create_from_game_state_reads_ranking_and_player_fields() -> void:
	MatchId._reset_counter_for_tests()
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 42
	cfg.configure_seat(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.HEN)
	cfg.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DOG)
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.FINISHED)
	state.rank_player(PlayerId.YELLOW)
	state.rank_player(PlayerId.GREEN)
	var yellow := state.get_player(PlayerId.YELLOW)
	for i in PlayerState.PAWNS_PER_PLAYER:
		var pawn := yellow.get_pawn_by_index(i)
		pawn.mark_finished(
				Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW).size())
	var result := MatchResult.create_from_game_state(state)
	assert_true(result.is_valid())
	assert_eq(result.match_id, state.match_id)
	assert_eq(result.mode, MatchConfig.Mode.FREE_PLAY)
	assert_eq(result.get_winner_id(), PlayerId.YELLOW)
	var winner := result.get_standing(PlayerId.YELLOW)
	assert_eq(winner.animal_id, AnimalId.DOG)
	assert_eq(winner.controller_type, MatchConfig.ControllerType.AI)
	assert_eq(winner.pawns_finished, PlayerState.PAWNS_PER_PLAYER)
	assert_eq(result.get_standing(PlayerId.GREEN).rank, 2)
	assert_eq(result.get_standing(PlayerId.GREEN).animal_id, AnimalId.HEN)
	assert_eq(
			result.get_standing(PlayerId.GREEN).controller_type,
			MatchConfig.ControllerType.HUMAN)


func test_create_from_game_state_null_returns_empty_invalid() -> void:
	var result := MatchResult.create_from_game_state(null)
	assert_false(result.is_valid())
	assert_eq(result.ranking.size(), 0)


func test_create_from_game_state_copies_campaign_mode() -> void:
	MatchId._reset_counter_for_tests()
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.mode = MatchConfig.Mode.CAMPAIGN
	cfg.campaign_level_id = &"jungle_01"
	cfg.rng_seed = 7
	var state := GameState.create_from_match_config(cfg)
	state.rank_player(PlayerId.GREEN)
	state.rank_player(PlayerId.YELLOW)
	var result := MatchResult.create_from_game_state(state)
	assert_true(result.is_valid())
	assert_true(result.is_campaign())
	assert_eq(result.campaign_level_id, &"jungle_01")
	assert_eq(result.get_winner_id(), PlayerId.GREEN)


func test_create_campaign_result() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create_with_rank_order(
			MatchId.generate(),
			[PlayerId.GREEN, PlayerId.YELLOW],
			MatchConfig.Mode.CAMPAIGN,
			&"jungle_01")
	assert_true(result.is_campaign())
	assert_eq(result.campaign_level_id, &"jungle_01")
	assert_true(result.is_valid())


# ── Helpers ───────────────────────────────────────────────────────────────────

func test_get_winner_and_is_winner() -> void:
	var result := _valid_two_player_result()
	var winner := result.get_winner()
	assert_not_null(winner)
	assert_eq(winner.player_id, PlayerId.GREEN)
	assert_eq(result.get_winner_id(), PlayerId.GREEN)
	assert_true(result.is_winner(PlayerId.GREEN))
	assert_false(result.is_winner(PlayerId.YELLOW))


func test_get_standing_returns_null_for_missing() -> void:
	var result := _valid_two_player_result()
	assert_null(result.get_standing(PlayerId.CYAN))


func test_set_ranking_sorts_by_rank() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate())
	result.set_ranking([
		MatchResult.PlayerStanding.create(PlayerId.YELLOW, 2),
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
	])
	assert_eq(result.ranking[0].player_id, PlayerId.GREEN)
	assert_eq(result.ranking[1].player_id, PlayerId.YELLOW)
	assert_true(result.is_valid())


func test_totals_sum_standings() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(
				PlayerId.GREEN, 1, AnimalId.PIG, MatchConfig.ControllerType.HUMAN,
				2, 1, 4),
		MatchResult.PlayerStanding.create(
				PlayerId.YELLOW, 2, AnimalId.DOG, MatchConfig.ControllerType.AI,
				1, 3, 2),
	])
	assert_eq(result.total_gifts_collected(), 3)
	assert_eq(result.total_pawns_captured(), 4)
	assert_eq(result.total_pawns_finished(), 6)


func test_to_player_summary_matches_save_repository_contract() -> void:
	var result := _valid_two_player_result()
	var summary := result.to_player_summary(PlayerId.GREEN)
	assert_eq(summary.get("rank"), 1)
	assert_eq(summary.get("gifts_collected"), 2)
	assert_eq(summary.get("pawns_captured"), 1)
	assert_eq(summary.get("pawns_finished"), 4)
	assert_eq(result.to_player_summary(PlayerId.CYAN).size(), 0,
			"липсващ играч → празен summary")


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_valid_two_three_four_player_results() -> void:
	MatchId._reset_counter_for_tests()
	var two := MatchResult.create_with_rank_order(
			MatchId.generate(), [PlayerId.GREEN, PlayerId.YELLOW])
	var three := MatchResult.create_with_rank_order(
			MatchId.generate(),
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW])
	var four := MatchResult.create_with_rank_order(
			MatchId.generate(),
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, PlayerId.CYAN])
	assert_true(two.is_valid())
	assert_true(three.is_valid())
	assert_true(four.is_valid())


func test_invalid_fewer_than_two_players() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
	])
	assert_false(result.is_valid())


func test_invalid_duplicate_player_id() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 2),
	])
	assert_false(result.is_valid())


func test_invalid_duplicate_rank() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
		MatchResult.PlayerStanding.create(PlayerId.YELLOW, 1),
	])
	assert_false(result.is_valid())


func test_invalid_gap_in_ranks() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
		MatchResult.PlayerStanding.create(PlayerId.YELLOW, 3),
	])
	assert_false(result.is_valid(), "липсващо 2-ро място")


func test_invalid_match_id() -> void:
	var result := MatchResult.create_with_rank_order(
			&"not_a_match", [PlayerId.GREEN, PlayerId.YELLOW])
	assert_false(result.is_valid())


func test_invalid_free_play_with_campaign_level() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create_with_rank_order(
			MatchId.generate(), [PlayerId.GREEN, PlayerId.YELLOW],
			MatchConfig.Mode.FREE_PLAY, &"jungle_01")
	assert_false(result.is_valid())


func test_invalid_campaign_without_level() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create_with_rank_order(
			MatchId.generate(), [PlayerId.GREEN, PlayerId.YELLOW],
			MatchConfig.Mode.CAMPAIGN, &"")
	assert_false(result.is_valid())


func test_invalid_future_schema_version() -> void:
	var result := _valid_two_player_result()
	result.schema_version = MatchResult.SCHEMA_VERSION + 1
	assert_false(result.is_valid())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_contains_all_schema_keys() -> void:
	var result := _valid_two_player_result()
	var d := result.to_dict()
	assert_true(d.has("schema_version"))
	assert_true(d.has("match_id"))
	assert_true(d.has("mode"))
	assert_true(d.has("campaign_level_id"))
	assert_true(d.has("ranking"))
	assert_eq(d["ranking"].size(), 2)


func test_to_dict_writes_ranking_sorted_by_rank() -> void:
	MatchId._reset_counter_for_tests()
	var result := MatchResult.create(MatchId.generate())
	result.ranking = [
		MatchResult.PlayerStanding.create(PlayerId.YELLOW, 2),
		MatchResult.PlayerStanding.create(PlayerId.GREEN, 1),
	]
	var d := result.to_dict()
	assert_eq(d["ranking"][0]["player_id"], "green")
	assert_eq(d["ranking"][1]["player_id"], "yellow")


func test_dict_round_trip_preserves_fields() -> void:
	MatchId._reset_counter_for_tests()
	var original := MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(
				PlayerId.GREEN, 1, AnimalId.HEN, MatchConfig.ControllerType.HUMAN,
				2, 1, 4),
		MatchResult.PlayerStanding.create(
				PlayerId.YELLOW, 2, AnimalId.DOG, MatchConfig.ControllerType.AI,
				0, 2, 1),
	], MatchConfig.Mode.CAMPAIGN, &"desert_02")
	var restored := MatchResult.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_eq(restored.campaign_level_id, &"desert_02")
	assert_eq(restored.get_standing(PlayerId.YELLOW).pawns_captured, 2)


func test_json_round_trip() -> void:
	var original := _valid_two_player_result()
	var restored := MatchResult.from_json(original.to_json())
	assert_not_null(restored)
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())


func test_from_json_invalid_returns_null() -> void:
	assert_null(MatchResult.from_json(""))
	assert_null(MatchResult.from_json("{not json"))
	assert_null(MatchResult.from_json("[1,2]"))


func test_duplicate_result_is_independent() -> void:
	var original := _valid_two_player_result()
	var copy := original.duplicate_result()
	assert_true(original.equals(copy))
	copy.ranking[0].gifts_collected = 99
	assert_ne(original.ranking[0].gifts_collected, 99,
			"duplicate_result не трябва да споделя PlayerStanding референции")


func test_to_dict_produces_independent_ranking_copy() -> void:
	var result := _valid_two_player_result()
	var d := result.to_dict()
	d["ranking"][0]["gifts_collected"] = 99
	assert_eq(result.ranking[0].gifts_collected, 2,
			"to_dict не трябва да споделя референция към standing полета")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _valid_two_player_result() -> MatchResult:
	MatchId._reset_counter_for_tests()
	return MatchResult.create(MatchId.generate(), [
		MatchResult.PlayerStanding.create(
				PlayerId.GREEN, 1, AnimalId.PIG, MatchConfig.ControllerType.HUMAN,
				2, 1, 4),
		MatchResult.PlayerStanding.create(
				PlayerId.YELLOW, 2, AnimalId.DOG, MatchConfig.ControllerType.AI,
				0, 0, 2),
	])
