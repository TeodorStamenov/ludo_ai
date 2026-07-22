extends TestCase
## Unit тестове за EasyAIPolicy, MediumAIPolicy и HardAIPolicy.


func _make_move(pawn_id: StringName, opts: Dictionary = {}) -> MovePawnCommand:
	var cmd := MovePawnCommand.new(&"p1", pawn_id)
	for key in opts:
		cmd.set_meta(key, opts[key])
	return cmd


func test_easy_picks_from_nonempty_list() -> void:
	var policy := EasyAIPolicy.new()
	var actions: Array = [
		MovePawnCommand.new(&"p1", &"pawn0"),
		MovePawnCommand.new(&"p1", &"pawn1"),
		MovePawnCommand.new(&"p1", &"pawn2"),
	]
	var chosen: GameCommand = policy.choose_action({}, actions)
	assert_not_null(chosen, "EasyAI must return non-null from non-empty list")
	assert_true(chosen in actions, "EasyAI must pick from the provided list")


func test_easy_returns_null_on_empty() -> void:
	var policy := EasyAIPolicy.new()
	var chosen: GameCommand = policy.choose_action({}, [])
	assert_null(chosen)


func test_easy_distribution_covers_all_options() -> void:
	var policy := EasyAIPolicy.new()
	var ids: Array = [&"a", &"b", &"c", &"d"]
	var actions: Array = ids.map(func(id): return MovePawnCommand.new(&"p1", id))
	var seen: Dictionary = {}
	for _i in 200:
		var chosen := policy.choose_action({}, actions) as MovePawnCommand
		seen[chosen.pawn_id] = true
	for id in ids:
		assert_true(id in seen, "EasyAI should eventually pick '%s'" % id)


func test_medium_prefers_capture() -> void:
	var policy := MediumAIPolicy.new()
	var safe := MovePawnCommand.new(&"p1", &"safe")
	var capture := MovePawnCommand.new(&"p1", &"capture")
	capture.set_meta("captures_opponent", true)
	var chosen: GameCommand = policy.choose_action({}, [safe, capture])
	assert_eq((chosen as MovePawnCommand).pawn_id, &"capture",
			"MediumAI must prefer capture over safe move")


func test_medium_prefers_gift_over_plain() -> void:
	var policy := MediumAIPolicy.new()
	var plain := MovePawnCommand.new(&"p1", &"plain")
	var gift := MovePawnCommand.new(&"p1", &"gift")
	gift.set_meta("lands_on_gift", true)
	var chosen: GameCommand = policy.choose_action({}, [plain, gift])
	assert_eq((chosen as MovePawnCommand).pawn_id, &"gift",
			"MediumAI must prefer landing on gift")


func test_hard_capture_beats_gift() -> void:
	var policy := HardAIPolicy.new()
	var capture := MovePawnCommand.new(&"p1", &"capture")
	capture.set_meta("captures_opponent", true)
	var gift := MovePawnCommand.new(&"p1", &"gift")
	gift.set_meta("lands_on_gift", true)
	var chosen: GameCommand = policy.choose_action({}, [gift, capture])
	assert_eq((chosen as MovePawnCommand).pawn_id, &"capture",
			"HardAI capture score (%d) must beat gift (%d)" % [
				HardAIPolicy.SCORE_CAPTURE, HardAIPolicy.SCORE_GIFT])


func test_hard_escape_beats_gift() -> void:
	var policy := HardAIPolicy.new()
	var escape_cmd := MovePawnCommand.new(&"p1", &"escape")
	escape_cmd.set_meta("escapes_threat", true)
	var gift := MovePawnCommand.new(&"p1", &"gift")
	gift.set_meta("lands_on_gift", true)
	var chosen: GameCommand = policy.choose_action({}, [gift, escape_cmd])
	assert_eq((chosen as MovePawnCommand).pawn_id, &"escape",
			"HardAI escape score (%d) must beat gift (%d)" % [
				HardAIPolicy.SCORE_ESCAPE, HardAIPolicy.SCORE_GIFT])


func test_hard_finish_beats_stack() -> void:
	var policy := HardAIPolicy.new()
	var finish_cmd := MovePawnCommand.new(&"p1", &"finish")
	finish_cmd.set_meta("enters_finish", true)
	var stack_cmd := MovePawnCommand.new(&"p1", &"stack")
	stack_cmd.set_meta("forms_stack", true)
	var chosen: GameCommand = policy.choose_action({}, [stack_cmd, finish_cmd])
	assert_eq((chosen as MovePawnCommand).pawn_id, &"finish",
			"HardAI finish score (%d) must beat stack score (%d)" % [
				HardAIPolicy.SCORE_ENTER_FINISH, HardAIPolicy.SCORE_FORM_STACK])


func test_hard_returns_null_on_empty() -> void:
	var policy := HardAIPolicy.new()
	assert_null(policy.choose_action({}, []))


func test_ai_controller_delegates_to_policy() -> void:
	var policy := EasyAIPolicy.new()
	var controller := AIController.new(&"ai1", policy)
	assert_true(controller.is_autonomous())
	var actions: Array = [
		MovePawnCommand.new(&"ai1", &"p0"),
		MovePawnCommand.new(&"ai1", &"p1"),
	]
	var chosen := controller.get_action({}, actions)
	assert_not_null(chosen)
	assert_true(chosen in actions)


func test_human_controller_not_autonomous() -> void:
	var controller := HumanController.new(&"player1")
	assert_false(controller.is_autonomous())
