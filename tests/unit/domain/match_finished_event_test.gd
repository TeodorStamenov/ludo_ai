class_name MatchFinishedEventTest
extends TestCase
## Unit тестове за MatchFinishedEvent (Task #80 / docs/V1_ARCHITECTURE.md, §4.4 / §5.2 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 — край на мача с пълно стабилно класиране).
##
## Покрива критични инварианти на факта:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: match_id + ranking (PlayerId, index 0 = победител).
##   - is_valid(): валиден MatchId и 2..4 уникални PlayerId.
##   - create_from_state: само при MatchPhase.FINISHED с пълен ranking.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_match_finished_event_extends_domain_event() -> void:
	var event := MatchFinishedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"MatchFinishedEvent трябва да extends RefCounted чрез DomainEvent")


func test_match_finished_event_is_not_node() -> void:
	var event: Object = MatchFinishedEvent.new()
	assert_false(event is Node,
			"MatchFinishedEvent не трябва да extends Node — domain слой е без сцени")


func test_match_finished_event_script_path_is_in_domain_events() -> void:
	var event := MatchFinishedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"MatchFinishedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW])
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от MatchFinishedEvent payload")
	assert_false(d.has("xp"), "XP е application/progress, не domain event payload")
	assert_false(d.has("place_label"), "UI текст не е domain payload")
	assert_false(d.has("summary"), "MatchSummary се строи в MatchSession, не в event")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var event := MatchFinishedEvent.new(
			&"m_10_2", [PlayerId.YELLOW, PlayerId.GREEN])
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_FINISHED)
	assert_eq(event.match_id, &"m_10_2")
	assert_eq(event.ranking.size(), 2)
	assert_eq(event.ranking[0], PlayerId.YELLOW)
	assert_eq(event.ranking[1], PlayerId.GREEN)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.get_winner_id(), PlayerId.YELLOW)
	assert_true(event.is_winner(PlayerId.YELLOW))
	assert_false(event.is_winner(PlayerId.GREEN))


func test_init_defaults_still_sets_event_type() -> void:
	var event := MatchFinishedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_FINISHED)
	assert_eq(event.match_id, &"")
	assert_eq(event.ranking.size(), 0)
	assert_false(event.is_valid(),
			"MatchFinished без match_id/ranking не е валиден факт")


func test_create_finished_sets_envelope_and_payload() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_10_2", [PlayerId.GREEN, PlayerId.YELLOW], 5)
	assert_eq(event.match_id, &"m_10_2")
	assert_eq(event.command_sequence, 5)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_FINISHED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())
	assert_eq(event.player_count(), 2)
	assert_eq(event.get_rank_of(PlayerId.GREEN), 1)
	assert_eq(event.get_rank_of(PlayerId.YELLOW), 2)


func test_create_from_state_reads_finished_ranking() -> void:
	var state := _finished_two_player_state(PlayerId.GREEN, PlayerId.YELLOW)
	var event := MatchFinishedEvent.create_from_state(state, 3)
	assert_eq(event.match_id, state.match_id)
	assert_eq(event.command_sequence, 3)
	assert_eq(event.get_winner_id(), PlayerId.GREEN)
	assert_eq(event.get_ranked_player_ids(), state.get_ranked_player_ids())
	assert_true(event.is_valid())


func test_create_from_state_four_player_stable_ranking() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(4))
	state.rank_player(PlayerId.GREEN)
	state.rank_player(PlayerId.YELLOW)
	state.rank_player(PlayerId.ORANGE)
	state.rank_player(PlayerId.CYAN)
	state.set_phase(MatchPhase.FINISHED)
	var event := MatchFinishedEvent.create_from_state(state, 1)
	assert_true(event.is_valid())
	assert_eq(event.player_count(), 4)
	assert_eq(event.get_winner_id(), PlayerId.GREEN)
	assert_eq(event.get_rank_of(PlayerId.CYAN), 4)
	assert_eq(event.ranking[1], PlayerId.YELLOW)
	assert_eq(event.ranking[2], PlayerId.ORANGE)


func test_create_from_state_rejects_in_progress_or_partial() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(3))
	state.rank_player(PlayerId.GREEN)
	assert_false(MatchFinishedEvent.create_from_state(state).is_valid(),
			"частичен ranking / IN_PROGRESS → невалиден факт")
	state.rank_player(PlayerId.YELLOW)
	state.rank_player(PlayerId.ORANGE)
	assert_false(state.is_finished())
	assert_false(MatchFinishedEvent.create_from_state(state).is_valid(),
			"пълен ranking без FINISHED phase → невалиден факт")
	assert_false(MatchFinishedEvent.create_from_state(null).is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_42_0", [PlayerId.GREEN, PlayerId.YELLOW])
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_FINISHED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_empty_or_malformed_match_id() -> void:
	assert_false(MatchFinishedEvent.create_finished(
			&"", [PlayerId.GREEN, PlayerId.YELLOW], 1).is_valid())
	assert_false(MatchFinishedEvent.create_finished(
			&"not_a_match", [PlayerId.GREEN, PlayerId.YELLOW], 1).is_valid())


func test_is_valid_rejects_too_few_or_too_many_players() -> void:
	assert_false(MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN], 1).is_valid(),
			"мач с 1 играч не е валиден (§3.3)")
	assert_false(MatchFinishedEvent.create_finished(
			&"m_1_0", [
				PlayerId.GREEN, PlayerId.YELLOW, PlayerId.ORANGE,
				PlayerId.CYAN, PlayerId.GREEN,
			], 1).is_valid())


func test_is_valid_rejects_duplicate_or_invalid_player_ids() -> void:
	assert_false(MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.GREEN], 1).is_valid())
	assert_false(MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, &"purple"], 1).is_valid())


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW], -1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW])
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"MatchFinished може да е валиден преди stamp на command_sequence")


func test_get_rank_of_unranked_returns_unranked() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW])
	assert_eq(event.get_rank_of(PlayerId.ORANGE), PlayerState.RANK_UNRANKED)


# ── Сериализация (договор journal / replay) ───────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_5_1", [PlayerId.ORANGE, PlayerId.CYAN, PlayerId.GREEN], 2)
	var d := event.to_dict()
	assert_eq(d["event_type"], "MatchFinished")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["match_id"], "m_5_1")
	assert_true(d["ranking"] is Array)
	assert_eq(d["ranking"].size(), 3)
	assert_eq(d["ranking"][0], "orange")
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["match_id"]), TYPE_STRING)


func test_from_dict_round_trip_preserves_fact() -> void:
	var original := MatchFinishedEvent.create_finished(
			&"m_7_3", [PlayerId.YELLOW, PlayerId.GREEN], 4)
	var restored := MatchFinishedEvent.from_finished_dict(original.to_dict())
	assert_true(restored is MatchFinishedEvent)
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())
	assert_eq(restored.get_winner_id(), PlayerId.YELLOW)


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "PlayerRanked",
		"command_sequence": 1,
		"match_id": "m_1_0",
		"ranking": ["green", "yellow"],
	}
	var event := MatchFinishedEvent.from_finished_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_FINISHED,
			"from_finished_dict трябва да форсира TYPE_MATCH_FINISHED")


func test_duplicate_event_is_independent() -> void:
	var event := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW], 1)
	var copy := event.duplicate_event() as MatchFinishedEvent
	assert_not_null(copy)
	assert_true(event.equals(copy))
	copy.ranking[0] = PlayerId.ORANGE
	copy.stamp(9)
	copy.match_id = &"m_2_0"
	assert_eq(event.ranking[0], PlayerId.GREEN,
			"мутация на копието не трябва да пипа оригинала")
	assert_eq(event.match_id, &"m_1_0")
	assert_eq(event.command_sequence, 1)
	assert_false(event.equals(copy))


func test_equals() -> void:
	var a := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW], 1)
	var b := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW], 1)
	var c := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.GREEN, PlayerId.YELLOW], 2)
	var d := MatchFinishedEvent.create_finished(
			&"m_2_0", [PlayerId.GREEN, PlayerId.YELLOW], 1)
	var e := MatchFinishedEvent.create_finished(
			&"m_1_0", [PlayerId.YELLOW, PlayerId.GREEN], 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_MATCH_FINISHED, 1)))


# ── Договор с GameState / TYPE_* ──────────────────────────────────────────────

func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_MATCH_FINISHED, &"MatchFinished")
	var event := MatchFinishedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_MATCH_FINISHED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_payload_matches_game_state_ranking_source_of_truth() -> void:
	var state := _finished_two_player_state(PlayerId.YELLOW, PlayerId.GREEN)
	var event := MatchFinishedEvent.create_from_state(state, 1)
	assert_true(event.is_valid())
	assert_eq(event.match_id, state.match_id)
	assert_eq(event.ranking.size(), state.ranking.size())
	assert_eq(event.get_winner_id(), state.get_ranked_player_ids()[0])
	assert_true(state.is_finished())


# ── Helpers ───────────────────────────────────────────────────────────────────

func _finished_two_player_state(
		first: StringName,
		second: StringName
) -> GameState:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(2))
	assert_eq(state.rank_player(first), 1)
	assert_eq(state.rank_player(second), 2)
	state.set_phase(MatchPhase.FINISHED)
	assert_true(state.is_finished())
	return state
