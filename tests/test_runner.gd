## Headless test runner — пълен suite (domain + application + platform + simulation).
##
## Бързи команди (препоръчани):
##   ./run_tests.sh              — пълен suite
##   ./run_tests.sh domain       — само unit/domain/ (GUT CLI)
##   make test                   — пълен suite чрез Makefile
##   make test-domain            — само unit/domain/ чрез Makefile
##
## Директно стартиране:
##   godot --headless --script tests/test_runner.gd
##
## Поддържа пълния GUT lifecycle: before_all / after_all / before_each / after_each.
## setUp() / tearDown() се извикват преди/след before_each / after_each.
extends SceneTree

const TEST_FILES: Array[String] = [
	# domain — нови тестове се добавят САМО тук
	"res://tests/unit/domain/pawn_zone_test.gd",
	"res://tests/unit/domain/match_phase_test.gd",
	"res://tests/unit/domain/turn_phase_test.gd",
	"res://tests/unit/domain/turn_state_test.gd",
	"res://tests/unit/domain/dice_state_test.gd",
	"res://tests/unit/domain/gift_state_test.gd",
	"res://tests/unit/domain/match_result_test.gd",
	"res://tests/unit/domain/game_state_test.gd",
	"res://tests/unit/domain/game_state_serialization_test.gd",
	"res://tests/unit/domain/game_state_hash_test.gd",
	"res://tests/unit/domain/framework_sanity_test.gd",
	"res://tests/unit/domain/random_source_test.gd",
	"res://tests/unit/domain/seeded_random_source_test.gd",
	"res://tests/unit/domain/rng_state_export_restore_test.gd",
	"res://tests/unit/domain/same_seed_identical_results_test.gd",
	"res://tests/unit/domain/presentation_random_source_test.gd",
	"res://tests/unit/domain/movement_rules_test.gd",
	"res://tests/unit/domain/stack_rules_test.gd",
	"res://tests/unit/domain/capture_rules_test.gd",
	"res://tests/unit/domain/home_stretch_test.gd",
	"res://tests/unit/domain/power_up_test.gd",
	"res://tests/unit/domain/turn_rules_test.gd",
	"res://tests/unit/domain/game_engine_contract_test.gd",
	"res://tests/unit/domain/game_command_test.gd",
	"res://tests/unit/domain/start_match_command_test.gd",
	"res://tests/unit/domain/roll_dice_command_test.gd",
	"res://tests/unit/domain/move_pawn_command_test.gd",
	"res://tests/unit/domain/domain_event_test.gd",
	"res://tests/unit/domain/match_started_event_test.gd",
	"res://tests/unit/domain/dice_rolled_event_test.gd",
	"res://tests/unit/domain/valid_moves_changed_event_test.gd",
	"res://tests/unit/domain/pawn_moved_event_test.gd",
	"res://tests/unit/domain/pawn_exited_base_event_test.gd",
	"res://tests/unit/domain/pawn_captured_event_test.gd",
	"res://tests/unit/domain/pawn_sent_home_event_test.gd",
	"res://tests/unit/domain/pawn_stack_formed_event_test.gd",
	"res://tests/unit/domain/pawn_finished_event_test.gd",
	"res://tests/unit/domain/turn_changed_event_test.gd",
	"res://tests/unit/domain/player_ranked_event_test.gd",
	"res://tests/unit/domain/match_finished_event_test.gd",
	"res://tests/unit/domain/match_config_test.gd",
	"res://tests/unit/domain/match_config_serialization_test.gd",
	"res://tests/unit/domain/match_config_validator_test.gd",
	"res://tests/unit/domain/match_config_validity_test.gd",
	"res://tests/unit/domain/ai_difficulty_test.gd",
	"res://tests/unit/domain/animal_id_test.gd",
	"res://tests/unit/domain/theme_id_test.gd",
	"res://tests/unit/domain/level_modifier_id_test.gd",
	"res://tests/unit/domain/cell_type_test.gd",
	"res://tests/unit/domain/cell_definition_test.gd",
	"res://tests/unit/domain/player_board_definition_test.gd",
	"res://tests/unit/domain/board_definition_test.gd",
	"res://tests/unit/domain/board_definition_validator_test.gd",
	"res://tests/unit/domain/classic_15x15_board_test.gd",
	"res://tests/unit/domain/classic_15x15_cell_ids_test.gd",
	"res://tests/unit/domain/classic_15x15_base_cells_test.gd",
	"res://tests/unit/domain/classic_15x15_spawn_cells_test.gd",
	"res://tests/unit/domain/classic_15x15_main_loop_test.gd",
	"res://tests/unit/domain/classic_15x15_home_stretch_test.gd",
	"res://tests/unit/domain/classic_15x15_player_routes_test.gd",
	"res://tests/unit/domain/classic_15x15_route_continuity_test.gd",
	"res://tests/unit/domain/classic_15x15_spawn_home_cells_test.gd",
	"res://tests/unit/domain/classic_15x15_equal_route_lengths_test.gd",
	"res://tests/unit/domain/two_player_opposite_seats_test.gd",
	"res://tests/unit/domain/three_player_active_seats_test.gd",
	"res://tests/unit/domain/four_player_active_seats_test.gd",
	"res://tests/unit/domain/ids_test.gd",
	# application — съществуващи тестове за важна оркестрационна логика
	"res://tests/unit/application/event_queue_test.gd",
	"res://tests/unit/application/ai_policy_test.gd",
	"res://tests/unit/application/match_session_test.gd",
	# platform — само реални I/O имплементации
	"res://tests/unit/platform/local_save_repository_test.gd",
	"res://tests/unit/platform/local_telemetry_sink_test.gd",
	# simulation
	"res://tests/simulation/deterministic_replay_test.gd",
	"res://tests/simulation/thousands_of_matches_test.gd",
]

var _passed: int = 0
var _failed: int = 0
var _pending: int = 0


func _init() -> void:
	print("\n=== Cosy Ludo — Unit Tests ===\n")
	for path in TEST_FILES:
		_run_file(path)
	var total := _passed + _failed + _pending
	print("\n--- Results: %d passed, %d failed, %d pending / %d total ---" % [
		_passed, _failed, _pending, total
	])
	quit(0 if _failed == 0 else 1)


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if not script:
		_failed += 1
		print("  FAIL  %s — cannot load script" % path)
		return

	var suite: GutTest = script.new() as GutTest
	if suite == null:
		_failed += 1
		print("  FAIL  %s — script does not extend GutTest / TestCase" % path)
		return

	suite.before_all()

	var methods: Array = suite.get_method_list()
	for m in methods:
		var name: String = m["name"]
		if name.begins_with("test_"):
			_run_case(suite, name)

	suite.after_all()


func _run_case(suite: GutTest, method: String) -> void:
	# Snapshot GUT counters before this test to detect per-test results.
	var fail_before: int = suite.get_fail_count()
	var pending_before: int = suite.get_pending_count()
	suite.clear_signal_watcher()

	var label := "%s::%s" % [
		suite.get_script().resource_path.get_file().get_basename(), method
	]

	suite.before_each()
	if suite.has_method("setUp"):
		suite.setUp()

	suite.call(method)

	if suite.has_method("tearDown"):
		suite.tearDown()
	suite.after_each()

	var failed_in_test: int = suite.get_fail_count() - fail_before
	var pending_in_test: int = suite.get_pending_count() - pending_before

	if pending_in_test > 0:
		_pending += 1
		print("  skip  %s" % label)
	elif failed_in_test > 0:
		_failed += 1
		print("  FAIL  %s" % label)
	else:
		_passed += 1
		print("  pass  %s" % label)
