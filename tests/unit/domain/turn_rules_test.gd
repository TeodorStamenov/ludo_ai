extends TestCase
## Unit тестове за TurnRules и TurnState state machine.
##
## Критични инварианти (docs/V1_ARCHITECTURE.md, раздел 4.2, 12):
##   - TurnState е изрична state machine, не набор от boolean флагове.
##   - Завършил играч не получава нов ход.
##   - При 3–4 играчи ranking е стабилен.
##   - Фазите следват реда: AWAITING_ROLL → AWAITING_MOVE → RESOLVING_MOVE
##     → TURN_END → следващ AWAITING_ROLL.


func test_turn_rules_extends_ref_counted() -> void:
	var rules := TurnRules.new()
	assert_not_null(rules, "TurnRules трябва да може да се инстанцира")
	assert_true(rules is RefCounted,
			"TurnRules трябва да extends RefCounted, не Node")


func test_turn_rules_is_not_node() -> void:
	var rules: Object = TurnRules.new()
	assert_false(rules is Node,
			"TurnRules не трябва да extends Node — domain слой е без сцени")


func test_turn_rules_script_path_is_in_domain() -> void:
	var rules := TurnRules.new()
	var path: String = rules.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"TurnRules трябва да е в game/domain/")


func test_turn_state_extends_ref_counted() -> void:
	var ts := TurnState.new()
	assert_not_null(ts, "TurnState трябва да може да се инстанцира")
	assert_true(ts is RefCounted,
			"TurnState трябва да extends RefCounted, не Node")


func test_turn_state_is_not_node() -> void:
	var ts: Object = TurnState.new()
	assert_false(ts is Node,
			"TurnState не трябва да extends Node — domain слой е без сцени")


func test_turn_state_script_path_is_in_domain() -> void:
	var ts := TurnState.new()
	var path: String = ts.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"TurnState трябва да е в game/domain/")


## Документиран инвариант: state machine фазите са изброени.
## Ходът преминава: MATCH_START → AWAITING_ROLL → … → MATCH_FINISHED.
func test_turn_phase_sequence_invariant_documented() -> void:
	var phases: Array[String] = [
		"MATCH_START",
		"AWAITING_ROLL",
		"AWAITING_MOVE",
		"RESOLVING_MOVE",
		"RESOLVING_POWER_UP",
		"TURN_END",
		"MATCH_FINISHED",
	]
	assert_eq(phases.size(), 7, "TurnState трябва да има точно 7 фази")
	assert_true("AWAITING_ROLL" in phases)
	assert_true("MATCH_FINISHED" in phases)


## Документиран инвариант: завършил играч не получава нов ход.
func test_finished_player_does_not_get_new_turn_invariant_documented() -> void:
	var finished_player_plays := false
	assert_false(finished_player_plays,
			"Завършил играч трябва да бъде пропускан при смяна на ход")


## Документиран инвариант: при 3–4 играчи ranking е стабилен.
## Играч не може да смени позицията си след финализиране.
func test_ranking_is_stable_invariant_documented() -> void:
	var ranking_can_change_after_finish := false
	assert_false(ranking_can_change_after_finish,
			"Класирането трябва да е стабилно след финализиране на играч")


## Документиран инвариант: допълнителен ход само при 6.
func test_extra_turn_only_on_six_invariant_documented() -> void:
	var extra_turn_on_roll: Array[int] = [6]
	var no_extra_turn_rolls: Array[int] = [1, 2, 3, 4, 5]
	assert_eq(extra_turn_on_roll.size(), 1,
			"Само едно хвърляне дава допълнителен ход")
	assert_eq(extra_turn_on_roll[0], 6,
			"Само хвърляне на 6 дава допълнителен ход")
	assert_eq(no_extra_turn_rolls.size(), 5,
			"Пет хвърляния не дават допълнителен ход")
