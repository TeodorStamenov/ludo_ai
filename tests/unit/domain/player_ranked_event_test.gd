class_name PlayerRankedEventTest
extends TestCase
## Unit тестове за PlayerRankedEvent (Task #79 / docs/V1_ARCHITECTURE.md, §4.4 / §11 / §12;
## docs/V1_GAME_DESIGN.md, §3.1 — класиране след 4 прибрани пионки; ranking стабилен).
##
## Покрива критични инварианти на факта:
##   - Domain: extends DomainEvent/RefCounted, път game/domain/events/.
##   - Payload: player_id + rank (1-based).
##   - is_valid(): валиден PlayerId и rank в [RANK_FIRST, RANK_MAX].
##   - create_from_state: чете rank след GameState.rank_player().


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_player_ranked_event_extends_domain_event() -> void:
	var event := PlayerRankedEvent.new()
	assert_true(event is DomainEvent)
	assert_true(event is RefCounted,
			"PlayerRankedEvent трябва да extends RefCounted чрез DomainEvent")


func test_player_ranked_event_is_not_node() -> void:
	var event: Object = PlayerRankedEvent.new()
	assert_false(event is Node,
			"PlayerRankedEvent не трябва да extends Node — domain слой е без сцени")


func test_player_ranked_event_script_path_is_in_domain_events() -> void:
	var event := PlayerRankedEvent.new()
	var path: String = event.get_script().resource_path
	assert_true(path.contains("game/domain/events/"),
			"PlayerRankedEvent трябва да е в game/domain/events/")


func test_to_dict_has_no_presentation_fields() -> void:
	var event := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1)
	var d := event.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от DomainEvent")
	assert_false(d.has("global_position"), "global_position не е част от DomainEvent")
	assert_false(d.has("node_path"), "NodePath не е част от DomainEvent")
	assert_false(d.has("tween"), "tween не е част от DomainEvent")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в DomainEvent")
	assert_false(d.has("state"), "GameState не е част от PlayerRankedEvent payload")
	assert_false(d.has("ranking"), "пълният ranking[] е в GameState, не в event")
	assert_false(d.has("xp"), "XP е application/progress, не domain event payload")
	assert_false(d.has("place_label"), "UI текст не е domain payload")


# ── Конструктор / фабрика ─────────────────────────────────────────────────────

func test_init_sets_event_type_and_payload() -> void:
	var event := PlayerRankedEvent.new(PlayerId.YELLOW, 2)
	assert_eq(event.event_type, DomainEvent.TYPE_PLAYER_RANKED)
	assert_eq(event.player_id, PlayerId.YELLOW)
	assert_eq(event.rank, 2)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_false(event.is_stamped())
	assert_true(event.is_valid())
	assert_false(event.is_winner())


func test_init_defaults_still_sets_event_type() -> void:
	var event := PlayerRankedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PLAYER_RANKED)
	assert_eq(event.player_id, &"")
	assert_eq(event.rank, PlayerState.RANK_UNRANKED)
	assert_false(event.is_valid(),
			"PlayerRanked без player_id/rank не е валиден факт")


func test_create_ranked_sets_envelope_and_payload() -> void:
	var event := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1, 3)
	assert_eq(event.player_id, PlayerId.GREEN)
	assert_eq(event.rank, 1)
	assert_eq(event.command_sequence, 3)
	assert_eq(event.event_type, DomainEvent.TYPE_PLAYER_RANKED)
	assert_true(event.is_stamped())
	assert_true(event.is_valid())
	assert_true(event.is_winner())


func test_create_from_state_reads_rank_after_rank_player() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(2))
	var assigned: int = state.rank_player(PlayerId.GREEN)
	assert_eq(assigned, 1)
	var event := PlayerRankedEvent.create_from_state(state, PlayerId.GREEN, 2)
	assert_eq(event.player_id, PlayerId.GREEN)
	assert_eq(event.rank, 1)
	assert_eq(event.command_sequence, 2)
	assert_true(event.is_valid())
	assert_true(event.is_winner())


func test_create_from_state_second_place_in_multiplayer() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(4))
	assert_eq(state.rank_player(PlayerId.GREEN), 1)
	assert_eq(state.rank_player(PlayerId.YELLOW), 2)
	var event := PlayerRankedEvent.create_from_state(state, PlayerId.YELLOW, 1)
	assert_eq(event.player_id, PlayerId.YELLOW)
	assert_eq(event.rank, 2)
	assert_true(event.is_valid())
	assert_false(event.is_winner())


func test_create_from_state_rejects_unranked_or_null() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(2))
	assert_false(PlayerRankedEvent.create_from_state(state, PlayerId.GREEN).is_valid(),
			"некласиран играч → невалиден факт")
	assert_false(PlayerRankedEvent.create_from_state(null, PlayerId.GREEN).is_valid())
	assert_false(PlayerRankedEvent.create_from_state(state, &"purple").is_valid())


func test_stamp_uses_base_envelope() -> void:
	var event := PlayerRankedEvent.create_ranked(PlayerId.CYAN, 3)
	assert_false(event.is_stamped())
	event.stamp(1)
	assert_true(event.is_stamped())
	assert_eq(event.command_sequence, 1)
	assert_eq(event.event_type, DomainEvent.TYPE_PLAYER_RANKED)
	assert_true(event.is_valid())


# ── is_valid() / helpers ──────────────────────────────────────────────────────

func test_is_valid_rejects_unranked() -> void:
	var event := PlayerRankedEvent.create_ranked(
			PlayerId.GREEN, PlayerState.RANK_UNRANKED, 1)
	assert_false(event.is_valid(),
			"PlayerRanked изисква присвоено място ≥ 1")


func test_is_valid_rejects_rank_above_max() -> void:
	var event := PlayerRankedEvent.create_ranked(
			PlayerId.GREEN, PlayerState.RANK_MAX + 1, 1)
	assert_false(event.is_valid())


func test_is_valid_rejects_invalid_player_id() -> void:
	var event := PlayerRankedEvent.create_ranked(&"purple", 1, 1)
	assert_false(event.is_valid())


func test_is_valid_rejects_negative_sequence_even_with_valid_payload() -> void:
	var event := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1, -1)
	assert_false(event.is_valid())


func test_is_valid_allows_unset_command_sequence() -> void:
	var event := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1)
	assert_eq(event.command_sequence, DomainEvent.COMMAND_SEQUENCE_UNSET)
	assert_true(event.is_valid(),
			"PlayerRanked може да е валиден преди stamp на command_sequence")


func test_is_winner_only_for_first_place() -> void:
	assert_true(PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1).is_winner())
	assert_false(PlayerRankedEvent.create_ranked(PlayerId.YELLOW, 2).is_winner())
	assert_false(PlayerRankedEvent.create_ranked(PlayerId.CYAN, 4).is_winner())


# ── Сериализация (договор journal / replay) ───────────────────────────────────

func test_to_dict_includes_envelope_and_payload() -> void:
	var event := PlayerRankedEvent.create_ranked(PlayerId.ORANGE, 3, 2)
	var d := event.to_dict()
	assert_eq(d["event_type"], "PlayerRanked")
	assert_eq(d["command_sequence"], 2)
	assert_eq(d["player_id"], "orange")
	assert_eq(d["rank"], 3)
	assert_eq(typeof(d["event_type"]), TYPE_STRING)
	assert_eq(typeof(d["player_id"]), TYPE_STRING)
	assert_eq(typeof(d["rank"]), TYPE_INT)


func test_from_dict_round_trip_preserves_fact() -> void:
	var original := PlayerRankedEvent.create_ranked(PlayerId.YELLOW, 2, 4)
	var restored := PlayerRankedEvent.from_ranked_dict(original.to_dict())
	assert_true(restored is PlayerRankedEvent)
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_true(restored.is_stamped())


func test_from_dict_forces_event_type() -> void:
	var data := {
		"event_type": "TurnChanged",
		"command_sequence": 1,
		"player_id": "green",
		"rank": 1,
	}
	var event := PlayerRankedEvent.from_ranked_dict(data)
	assert_eq(event.event_type, DomainEvent.TYPE_PLAYER_RANKED,
			"from_ranked_dict трябва да форсира TYPE_PLAYER_RANKED")


func test_equals() -> void:
	var a := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1, 1)
	var b := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1, 1)
	var c := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 1, 2)
	var d := PlayerRankedEvent.create_ranked(PlayerId.YELLOW, 1, 1)
	var e := PlayerRankedEvent.create_ranked(PlayerId.GREEN, 2, 1)
	assert_true(a.equals(b))
	assert_false(a.equals(c))
	assert_false(a.equals(d))
	assert_false(a.equals(e))
	assert_false(a.equals(null))
	assert_false(a.equals(DomainEvent.create(DomainEvent.TYPE_PLAYER_RANKED, 1)))


# ── Договор с GameState / TYPE_* ──────────────────────────────────────────────

func test_type_constant_matches_architecture() -> void:
	assert_eq(DomainEvent.TYPE_PLAYER_RANKED, &"PlayerRanked")
	var event := PlayerRankedEvent.new()
	assert_eq(event.event_type, DomainEvent.TYPE_PLAYER_RANKED)
	assert_true(DomainEvent.is_known_type(event.event_type))


func test_payload_matches_game_state_ranking() -> void:
	var state := GameState.create_from_match_config(MatchConfig.create_with_seat_count(3))
	state.rank_player(PlayerId.GREEN)
	state.rank_player(PlayerId.YELLOW)
	var first := PlayerRankedEvent.create_from_state(state, PlayerId.GREEN, 1)
	var second := PlayerRankedEvent.create_from_state(state, PlayerId.YELLOW, 2)
	assert_true(first.is_valid())
	assert_true(second.is_valid())
	assert_eq(first.rank, state.get_player(PlayerId.GREEN).rank)
	assert_eq(second.rank, state.get_player(PlayerId.YELLOW).rank)
	assert_eq(state.get_ranked_player_ids()[0], first.player_id)
	assert_eq(state.get_ranked_player_ids()[1], second.player_id)
	assert_eq(state.ranking.size(), 2)
	assert_false(state.is_ranked(PlayerId.ORANGE),
			"третият играч още не е класиран — мачът продължава")
