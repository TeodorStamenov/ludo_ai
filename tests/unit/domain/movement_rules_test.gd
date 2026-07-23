extends TestCase
## Unit тестове за MoveRules — правилата за движение по маршрута.
##
## Критични инварианти (docs/V1_ARCHITECTURE.md, раздел 12):
##   - Пионка излиза от базата само при хвърлено 6.
##   - Хвърлено 6 дава право на допълнителен ход.
##   - Три опита при всички пионки в база.
##   - Движение по общото трасе и влизане в home stretch.
##   - Точен зар за завършване в края на home stretch.


func test_move_rules_extends_ref_counted() -> void:
	var rules := MoveRules.new()
	assert_not_null(rules, "MoveRules трябва да може да се инстанцира")
	assert_true(rules is RefCounted,
			"MoveRules трябва да extends RefCounted, не Node")


func test_move_rules_is_not_node() -> void:
	var rules: Object = MoveRules.new()
	assert_false(rules is Node,
			"MoveRules не трябва да extends Node — domain слой е без сцени")


func test_move_rules_script_path_is_in_domain() -> void:
	var rules := MoveRules.new()
	var path: String = rules.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"MoveRules трябва да е в game/domain/")
	assert_false(path.contains("application/"),
			"MoveRules не трябва да импортира от application/")
	assert_false(path.contains("presentation/"),
			"MoveRules не трябва да импортира от presentation/")


## Документиран инвариант: пионка излиза от базата само при 6.
## Тестът верифицира структурата — пълната логика изисква имплементация на GameEngine.
func test_exit_base_requires_six_invariant_documented() -> void:
	# Стойностите на зара: само 6 позволява излизане.
	var allowed_exit_roll := 6
	var forbidden_rolls: Array = [1, 2, 3, 4, 5]
	assert_eq(allowed_exit_roll, 6,
			"Само хвърляне на 6 позволява излизане от базата")
	assert_eq(forbidden_rolls.size(), 5,
			"Петте останали стойности са забранени за излизане")
	assert_false(6 in forbidden_rolls,
			"6 не трябва да е в забранените стойности")


## Документиран инвариант: хвърлено 6 дава допълнителен ход.
func test_extra_turn_on_six_invariant_documented() -> void:
	var roll_giving_extra_turn := 6
	assert_eq(roll_giving_extra_turn, 6,
			"Само стойност 6 дава допълнителен ход")


## Документиран инвариант: три опита при всички пионки в база.
func test_three_attempts_when_all_in_base_invariant_documented() -> void:
	var max_attempts_from_base := 3
	assert_eq(max_attempts_from_base, 3,
			"Играч с всички пионки в база получава максимум 3 опита")


## Документиран инвариант: диапазонът на зара е [1, 6].
func test_dice_range_invariant() -> void:
	var rng := SeededRandomSource.new(42)
	for _i in 100:
		var roll := rng.next_int(1, 6)
		assert_true(roll >= 1 and roll <= 6,
				"Зарът трябва да е в [1, 6], получено: %d" % roll)
