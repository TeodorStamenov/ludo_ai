class_name CommandResultTest
extends TestCase
## Unit тестове за CommandResult (Task #82 / docs/V1_ARCHITECTURE.md, §4.3 / §12).
##
## Покрива критични инварианти:
##   - Domain: extends RefCounted, път game/domain/model/.
##   - ok / rejected / not_implemented фабрики.
##   - is_valid(): accept ↔ error==null; reject ↔ error + празни events.
##   - §12: reject не носи events (state остава входният).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_command_result_extends_ref_counted() -> void:
	var result := CommandResult.new()
	assert_true(result is RefCounted,
			"CommandResult трябва да extends RefCounted, не Node")


func test_command_result_is_not_node() -> void:
	var result: Object = CommandResult.new()
	assert_false(result is Node,
			"CommandResult не трябва да extends Node — domain слой е без сцени")


func test_command_result_script_path_is_in_domain_model() -> void:
	var result := CommandResult.new()
	var path: String = result.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"CommandResult трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var result := CommandResult.ok(GameState.new())
	var d := result.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от CommandResult")
	assert_false(d.has("node_path"), "NodePath не е част от CommandResult")
	assert_false(d.has("texture"), "texture не е част от domain CommandResult")
	assert_true(d.has("accepted"))
	assert_true(d.has("state"))
	assert_true(d.has("events"))
	assert_true(d.has("error"))


# ── Фабрики и подразбирания ───────────────────────────────────────────────────

func test_default_fields_are_invalid() -> void:
	var result := CommandResult.new()
	assert_false(result.accepted)
	assert_null(result.state)
	assert_eq(result.events.size(), 0)
	assert_null(result.error)
	assert_false(result.is_valid(),
			"липсващ state / reject без error → is_valid() == false")


func test_ok_sets_accepted_without_error() -> void:
	var state := GameState.new()
	var events: Array = [DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 1)]
	var result := CommandResult.ok(state, events)
	assert_true(result.accepted)
	assert_false(result.is_rejected())
	assert_false(result.has_error())
	assert_eq(result.state, state)
	assert_eq(result.event_count(), 1)
	assert_null(result.error)
	assert_true(result.is_valid())


func test_rejected_sets_error_and_clears_events() -> void:
	var state := GameState.new()
	var err := CommandError.illegal_move("not in valid_pawn_ids")
	var result := CommandResult.rejected(state, err)
	assert_false(result.accepted)
	assert_true(result.is_rejected())
	assert_true(result.has_error())
	assert_eq(result.state, state)
	assert_eq(result.event_count(), 0)
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(result.is_valid())


func test_not_implemented_uses_stable_error_code() -> void:
	var result := CommandResult.not_implemented(GameState.new())
	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_NOT_IMPLEMENTED)
	assert_true(result.is_valid())


func test_ok_duplicates_events_array() -> void:
	var events: Array = [DomainEvent.create(DomainEvent.TYPE_TURN_CHANGED, 2)]
	var result := CommandResult.ok(GameState.new(), events)
	events.clear()
	assert_eq(result.event_count(), 1,
			"ok() трябва да копира events масива — не да споделя референция")


# ── is_valid() инварианти (§4.3 / §12) ────────────────────────────────────────

func test_accepted_with_error_is_invalid() -> void:
	var result := CommandResult.create(
			true, GameState.new(), [], CommandError.wrong_player())
	assert_false(result.is_valid(),
			"accept + error нарушава договора")


func test_rejected_without_error_is_invalid() -> void:
	var result := CommandResult.create(false, GameState.new(), [], null)
	assert_false(result.is_valid(),
			"reject без CommandError → невалиден")


func test_rejected_with_events_is_invalid() -> void:
	var result := CommandResult.create(
			false,
			GameState.new(),
			[DomainEvent.create(DomainEvent.TYPE_PAWN_MOVED, 1)],
			CommandError.wrong_phase())
	assert_false(result.is_valid(),
			"§12: reject не произвежда DomainEvent")


func test_rejected_with_invalid_error_is_invalid() -> void:
	var result := CommandResult.rejected(
			GameState.new(), CommandError.create(&"not_a_real_error"))
	assert_false(result.is_valid())


func test_accepted_with_invalid_event_is_invalid() -> void:
	var bad := DomainEvent.create(&"NotARealEvent", 1)
	var result := CommandResult.ok(GameState.new(), [bad])
	assert_false(result.is_valid())


func test_accepted_with_non_event_entry_is_invalid() -> void:
	var result := CommandResult.ok(GameState.new(), ["not-an-event"])
	assert_false(result.is_valid())


# ── equals / duplicate ────────────────────────────────────────────────────────

func test_equals_and_duplicate_result() -> void:
	var state := _minimal_state()
	var original := CommandResult.rejected(
			state, CommandError.wrong_player("not active"))
	var copy := original.duplicate_result()
	assert_true(original.equals(copy))
	copy.error.message = "changed"
	assert_false(original.equals(copy))
	assert_eq(original.error.message, "not active",
			"duplicate_result не трябва да споделя CommandError референция")
	assert_false(original.equals(null))


func test_duplicate_result_copies_events_independently() -> void:
	var event := DomainEvent.create(DomainEvent.TYPE_DICE_ROLLED, 3)
	var original := CommandResult.ok(_minimal_state(), [event])
	var copy := original.duplicate_result()
	assert_true(original.equals(copy))
	(copy.events[0] as DomainEvent).command_sequence = 99
	assert_eq((original.events[0] as DomainEvent).command_sequence, 3,
			"duplicate_result не трябва да споделя DomainEvent референции")


func _minimal_state() -> GameState:
	MatchId._reset_counter_for_tests()
	var cfg := MatchConfig.new()
	cfg.rng_seed = 42
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	cfg.seats[0].configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.seats[1].configure(
			MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	return GameState.create_from_match_config(cfg)
