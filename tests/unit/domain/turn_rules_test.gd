class_name TurnRulesTest
extends TestCase
## Business-critical тестове за TurnRules state machine (Task #85 /
## docs/V1_ARCHITECTURE.md §4.2 / §12; CURRENT_YELLOW_BEHAVIOR YEL-003/010–013).
##
## Покрива: преходи, skip на класирани, next player, after-roll/move outcomes,
## advance_from_turn_end → TurnChanged / MATCH_FINISHED.


var _rules: TurnRules


func before_each() -> void:
	_rules = TurnRules.new()
	MatchId._reset_counter_for_tests()


func test_turn_rules_is_domain_ref_counted() -> void:
	assert_true(_rules is RefCounted)
	var as_object: Object = _rules
	assert_false(as_object is Node)
	assert_true(_rules.get_script().resource_path.contains("game/domain/rules/"))


func test_can_transition_allows_documented_edges() -> void:
	assert_true(_rules.can_transition(TurnPhase.MATCH_START, TurnPhase.AWAITING_ROLL))
	assert_true(_rules.can_transition(TurnPhase.AWAITING_ROLL, TurnPhase.AWAITING_MOVE))
	assert_true(_rules.can_transition(TurnPhase.AWAITING_ROLL, TurnPhase.AWAITING_ROLL))
	assert_true(_rules.can_transition(TurnPhase.AWAITING_ROLL, TurnPhase.TURN_END))
	assert_true(_rules.can_transition(TurnPhase.AWAITING_MOVE, TurnPhase.RESOLVING_MOVE))
	assert_true(_rules.can_transition(TurnPhase.RESOLVING_MOVE, TurnPhase.RESOLVING_POWER_UP))
	assert_true(_rules.can_transition(TurnPhase.RESOLVING_MOVE, TurnPhase.TURN_END))
	assert_true(_rules.can_transition(TurnPhase.TURN_END, TurnPhase.AWAITING_ROLL))
	assert_true(_rules.can_transition(TurnPhase.TURN_END, TurnPhase.MATCH_FINISHED))


func test_can_transition_rejects_illegal_edges() -> void:
	assert_false(_rules.can_transition(TurnPhase.MATCH_START, TurnPhase.AWAITING_MOVE))
	assert_false(_rules.can_transition(TurnPhase.AWAITING_MOVE, TurnPhase.AWAITING_ROLL))
	assert_false(_rules.can_transition(TurnPhase.MATCH_FINISHED, TurnPhase.AWAITING_ROLL))
	assert_false(_rules.can_transition(TurnPhase.TURN_END, TurnPhase.RESOLVING_MOVE))
	assert_false(_rules.can_transition(-1, TurnPhase.AWAITING_ROLL))
	assert_false(_rules.can_transition(TurnPhase.AWAITING_ROLL, 99))


func test_grants_extra_roll_only_on_six() -> void:
	assert_true(_rules.grants_extra_roll(6))
	for value in [1, 2, 3, 4, 5]:
		assert_false(_rules.grants_extra_roll(value),
				"зар %d не дава допълнителен ход" % value)


func test_begin_player_turn_sets_base_attempts_yel_003_004() -> void:
	var state := _four_player_in_progress()
	assert_true(_rules.begin_player_turn(state, 0, 1))
	assert_eq(state.active_player_index, 0)
	assert_true(state.turn.is_awaiting_roll())
	assert_eq(state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_true(state.turn.allows_roll_dice())

	_place_pawn_on_main_path(state.get_player_by_index(1), 0)
	assert_true(_rules.begin_player_turn(state, 1, 2))
	assert_eq(state.turn.base_attempts_remaining, TurnState.SINGLE_ROLL_ATTEMPTS)


func test_should_skip_ranked_player() -> void:
	var state := _four_player_in_progress()
	var player := state.get_player_by_index(0)
	assert_false(_rules.should_skip_player(player))
	state.rank_player(player.player_id)
	assert_true(_rules.should_skip_player(player))
	assert_true(_rules.should_skip_player(null))


func test_find_next_player_skips_ranked() -> void:
	var state := _four_player_in_progress()
	state.set_active_player_index(0)
	state.rank_player(state.get_player_by_index(1).player_id)
	var next_idx: int = _rules.find_next_player_index(state, 0)
	assert_eq(next_idx, 2, "класираният seat 1 трябва да се прескочи")


func test_find_next_player_wraps_around() -> void:
	var state := _four_player_in_progress()
	state.set_active_player_index(3)
	assert_eq(_rules.find_next_player_index(state, 3), 0)


func test_resolve_after_roll_base_miss_retries_yel_010() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	var outcome := _rules.resolve_after_roll(turn, 4, true, [])
	assert_eq(outcome, TurnRules.OUTCOME_RETRY_ROLL)
	assert_true(turn.is_awaiting_roll())
	assert_eq(turn.base_attempts_remaining, 2)
	assert_true(turn.allows_roll_dice())
	assert_false(turn.has_dice_result())


func test_resolve_after_roll_base_third_miss_ends_turn_yel_012() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	assert_eq(_rules.resolve_after_roll(turn, 2, true, []), TurnRules.OUTCOME_RETRY_ROLL)
	assert_eq(_rules.resolve_after_roll(turn, 3, true, []), TurnRules.OUTCOME_RETRY_ROLL)
	var outcome := _rules.resolve_after_roll(turn, 5, true, [])
	assert_eq(outcome, TurnRules.OUTCOME_TURN_END)
	assert_true(turn.is_turn_end())


func test_resolve_after_roll_six_offers_moves_and_grants_extra_yel_013() -> void:
	var turn := TurnState.create_for_player_turn(1, true)
	var pawns: Array = [&"green_0", &"green_1"]
	var outcome := _rules.resolve_after_roll(turn, 6, true, pawns)
	assert_eq(outcome, TurnRules.OUTCOME_AWAITING_MOVE)
	assert_true(turn.is_awaiting_move())
	assert_true(turn.has_extra_roll_pending())
	assert_true(turn.allows_move_pawn())
	assert_eq(turn.valid_pawn_ids.size(), 2)


func test_resolve_after_roll_no_moves_with_extra_gives_extra_roll() -> void:
	var turn := TurnState.create_for_player_turn(2, false)
	var outcome := _rules.resolve_after_roll(turn, 6, false, [])
	assert_eq(outcome, TurnRules.OUTCOME_EXTRA_ROLL)
	assert_true(turn.is_awaiting_roll())
	assert_false(turn.has_extra_roll_pending())
	assert_eq(turn.turn_number, 2)


func test_resolve_after_roll_no_moves_without_extra_ends_turn_yel_045() -> void:
	var turn := TurnState.create_for_player_turn(2, false)
	var outcome := _rules.resolve_after_roll(turn, 3, false, [])
	assert_eq(outcome, TurnRules.OUTCOME_TURN_END)
	assert_true(turn.is_turn_end())


func test_resolve_after_move_without_gift_honors_extra_roll() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	_rules.resolve_after_roll(turn, 6, false, [&"green_0"])
	assert_true(turn.has_extra_roll_pending())
	var outcome := _rules.resolve_after_move(turn, false)
	assert_eq(outcome, TurnRules.OUTCOME_EXTRA_ROLL)
	assert_true(turn.is_awaiting_roll())


func test_resolve_after_move_with_gift_enters_power_up() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	_rules.resolve_after_roll(turn, 4, false, [&"green_0"])
	var outcome := _rules.resolve_after_move(turn, true)
	assert_eq(outcome, TurnRules.OUTCOME_RESOLVING_POWER_UP)
	assert_true(turn.is_resolving_power_up())


func test_resolve_after_power_up_ends_or_extra() -> void:
	var turn := TurnState.create_for_player_turn(1, false)
	_rules.resolve_after_roll(turn, 4, false, [&"green_0"])
	_rules.resolve_after_move(turn, true)
	var outcome := _rules.resolve_after_power_up(turn)
	assert_eq(outcome, TurnRules.OUTCOME_TURN_END)

	turn = TurnState.create_for_player_turn(1, false)
	_rules.resolve_after_roll(turn, 6, false, [&"green_0"])
	_rules.resolve_after_move(turn, true)
	outcome = _rules.resolve_after_power_up(turn)
	assert_eq(outcome, TurnRules.OUTCOME_EXTRA_ROLL)


func test_advance_from_turn_end_emits_turn_changed() -> void:
	var state := _four_player_in_progress()
	_rules.begin_player_turn(state, 0, 1)
	state.turn.enter_turn_end()
	var result: Dictionary = _rules.advance_from_turn_end(state, 5)
	assert_eq(result["outcome"], TurnRules.OUTCOME_NEXT_TURN)
	assert_eq(state.active_player_index, 1)
	assert_true(state.turn.is_awaiting_roll())
	assert_eq(state.turn.turn_number, 2)
	var event := result["event"] as TurnChangedEvent
	assert_true(event is TurnChangedEvent)
	assert_eq(event.previous_player_index, 0)
	assert_eq(event.new_player_index, 1)
	assert_eq(event.command_sequence, 5)
	assert_true(event.is_valid())


func test_advance_skips_finished_player() -> void:
	var state := _four_player_in_progress()
	_rules.begin_player_turn(state, 0, 3)
	state.rank_player(state.get_player_by_index(1).player_id)
	state.turn.enter_turn_end()
	var result: Dictionary = _rules.advance_from_turn_end(state, 8)
	assert_eq(result["outcome"], TurnRules.OUTCOME_NEXT_TURN)
	assert_eq(state.active_player_index, 2)
	assert_eq((result["event"] as TurnChangedEvent).new_player_index, 2)


func test_advance_when_no_playable_players_finishes_turn_machine() -> void:
	var state := _two_player_in_progress()
	_rules.begin_player_turn(state, 0, 4)
	state.rank_player(state.get_player_by_index(0).player_id)
	state.rank_player(state.get_player_by_index(1).player_id)
	state.turn.enter_turn_end()
	var result: Dictionary = _rules.advance_from_turn_end(state, 9)
	assert_eq(result["outcome"], TurnRules.OUTCOME_MATCH_FINISHED)
	assert_true(state.turn.is_match_finished())
	assert_eq(result["event"], null)


func test_start_match_uses_turn_rules_for_first_turn() -> void:
	var engine := GameEngine.new(null, null, null, _rules)
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 17
	var state := GameState.create_from_match_config(cfg)
	var rng := SeededRandomSource.new(cfg.rng_seed)
	var cmd := StartMatchCommand.create_with_config(cfg)
	state.stamp_command(cmd)
	var result := engine.validate_and_apply(state, cmd, rng)
	assert_true(result.accepted)
	assert_true(result.state.turn.is_awaiting_roll())
	assert_eq(result.state.turn.base_attempts_remaining, TurnState.BASE_ROLL_ATTEMPTS)
	assert_eq(result.state.turn.turn_number, 1)


func _four_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_four_player()
	cfg.rng_seed = 42
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _two_player_in_progress() -> GameState:
	var cfg := MatchConfig.create_two_player_opposite()
	cfg.rng_seed = 7
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	return state


func _place_pawn_on_main_path(player: PlayerState, pawn_index: int) -> void:
	var pawn := player.get_pawn_by_index(pawn_index)
	assert_not_null(pawn)
	pawn.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
