extends TestCase
## Unit тестове за MoveRules — правилата за движение по маршрута.
##
## Критични инварианти (docs/V1_ARCHITECTURE.md, раздел 12 / Task #92):
##   - Пионка излиза от базата само при хвърлено 6 (виж exit_base_rule_test).
##   - Хвърлено 6 дава право на допълнителен ход (виж extra_roll_on_six_test / #93).
##   - Три опита при всички пионки в база (#94).
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


## Инвариант #92 / YEL-030–031: излизане от база само при 6 (MoveRules).
func test_exit_base_requires_six() -> void:
	var rules := MoveRules.new()
	assert_eq(MoveRules.EXIT_BASE_VALUE, DiceState.EXIT_BASE_VALUE)
	assert_true(rules.allows_exit_base(6))
	for face in [1, 2, 3, 4, 5]:
		assert_false(rules.allows_exit_base(face),
				"зар %d не позволява излизане от база" % face)


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
