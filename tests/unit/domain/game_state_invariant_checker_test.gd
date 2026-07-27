extends TestCase
## Business-critical тестове за GameStateInvariantChecker (#142 /
## docs/V1_ARCHITECTURE.md §12).
##
## Покрива runtime инварианти отвъд is_valid(): max-2 own stack, без чужди
## на home stretch, класиран ≠ активен, ranking ↔ PlayerState.rank.


func before_each() -> void:
	MatchId._reset_counter_for_tests()


func test_checker_extends_ref_counted_in_domain() -> void:
	var checker := GameStateInvariantChecker.new()
	assert_true(checker is RefCounted)
	var as_object: Object = checker
	assert_false(as_object is Node)
	var path: String = checker.get_script().resource_path
	assert_true(path.contains("game/domain/model/"))


func test_valid_in_progress_state_passes() -> void:
	var state := _two_player_in_progress()
	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_ok(), str(result.error_codes))
	assert_true(GameStateInvariantChecker.is_valid(state))
	assert_eq(GameStateInvariantChecker.describe_first_violation(state), "")


func test_null_state_reports_null_error() -> void:
	var result := GameStateInvariantChecker.validate(null)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_NULL_STATE))
	assert_false(GameStateInvariantChecker.is_valid(null))


func test_structurally_invalid_state_reports_invalid_state() -> void:
	var state := _two_player_in_progress()
	state.match_id = &""
	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_INVALID_STATE))


## §12: максимум 2 свои пионки на обща клетка.
func test_own_stack_overflow_is_detected() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(2).set_position(PawnZone.MAIN_PATH, 4, cell)

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_OWN_STACK_OVERFLOW))
	assert_true(GameStateInvariantChecker.describe_first_violation(state).contains(
			"own_stack_overflow"))


## След приета команда не трябва да остават смесени occupants на клетка.
func test_mixed_occupancy_is_detected() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	state.get_player(PlayerId.YELLOW).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 4, cell)
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, cell)

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_MIXED_OCCUPANCY))


## §12: home stretch не може да бъде атакуван / зает от противник.
func test_foreign_home_stretch_occupation_is_detected() -> void:
	var state := _two_player_in_progress()
	var yellow_home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.YELLOW)[0]
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.HOME_STRETCH, 50, yellow_home)

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_FOREIGN_HOME_STRETCH))


## §12: завършил / класиран играч не получава нов ход.
func test_ranked_active_player_is_detected() -> void:
	var state := _two_player_in_progress()
	state.rank_player(PlayerId.YELLOW)
	state.set_active_player(PlayerId.YELLOW)

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_RANKED_ACTIVE))


## §12: ranking[] и PlayerState.rank трябва да са съгласувани.
func test_ranking_player_rank_mismatch_is_detected() -> void:
	var state := _two_player_in_progress()
	state.rank_player(PlayerId.YELLOW)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.set_rank(PlayerState.RANK_FIRST + 1)

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_invalid())
	assert_true(result.has_error(GameStateInvariantChecker.ERR_RANKING_MISMATCH))


## Валиден legal stack от 2 не е нарушение.
func test_legal_friendly_stack_of_two_passes() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, cell)

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_ok(), str(result.error_codes))
	assert_true(GameStateInvariantChecker.is_runtime_valid(state))


## validate_runtime хваща board нарушения и без is_valid() gate.
func test_validate_runtime_detects_stack_overflow_on_partial_state() -> void:
	var state := _two_player_in_progress()
	state.match_id = &""
	assert_false(state.is_valid())
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(2).set_position(PawnZone.MAIN_PATH, 4, cell)

	var full := GameStateInvariantChecker.validate(state)
	assert_true(full.has_error(GameStateInvariantChecker.ERR_INVALID_STATE))
	assert_false(full.has_error(GameStateInvariantChecker.ERR_OWN_STACK_OVERFLOW),
			"full validate stops at is_valid")

	var runtime := GameStateInvariantChecker.validate_runtime(state)
	assert_true(runtime.has_error(GameStateInvariantChecker.ERR_OWN_STACK_OVERFLOW))
	assert_false(runtime.has_error(GameStateInvariantChecker.ERR_INVALID_STATE))


## Finished match с пълен ranking минава (активният може да е класиран).
func test_finished_match_with_full_ranking_passes() -> void:
	var state := _two_player_in_progress()
	state.rank_player(PlayerId.YELLOW)
	state.rank_player(PlayerId.GREEN)
	state.set_phase(MatchPhase.FINISHED)
	state.turn.enter_match_finished()

	var result := GameStateInvariantChecker.validate(state)
	assert_true(result.is_ok(), str(result.error_codes))


func _two_player_in_progress(rng_seed: int = 42) -> GameState:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		if i == 0:
			seat.configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		else:
			seat.configure(
					MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state
