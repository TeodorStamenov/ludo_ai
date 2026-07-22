## Minimal headless test runner.
## Run with: godot --headless --script tests/test_runner.gd
extends SceneTree

const TEST_FILES: Array[String] = [
	"res://tests/unit/application/match_config_test.gd",
	"res://tests/unit/application/event_queue_test.gd",
	"res://tests/unit/application/ai_policy_test.gd",
	"res://tests/unit/application/match_session_test.gd",
	"res://tests/unit/domain/seeded_rng_test.gd",
]

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("\n=== Cosy Ludo — Unit Tests ===\n")
	for path in TEST_FILES:
		_run_file(path)
	print("\n--- Results: %d passed, %d failed ---" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if not script:
		_failed += 1
		print("  FAIL  %s — cannot load script" % path)
		return
	var suite: RefCounted = script.new()
	var methods: Array = suite.get_method_list()
	for m in methods:
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		_run_case(suite, name)


func _run_case(suite: RefCounted, method: String) -> void:
	if suite.has_method("setUp"):
		suite.call("setUp")
	var label := "%s::%s" % [suite.get_script().resource_path.get_file().get_basename(), method]
	suite._current_label = label
	suite._case_failed = false
	suite.call(method)
	if suite._case_failed:
		_failed += 1
		print("  FAIL  %s" % label)
	else:
		_passed += 1
		print("  pass  %s" % label)
	if suite.has_method("tearDown"):
		suite.call("tearDown")
