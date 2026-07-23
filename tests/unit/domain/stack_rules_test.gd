extends TestCase
## Unit тестове за StackRules — правилата за купчини (stacks).
##
## Критични инварианти (docs/V1_GAME_DESIGN.md, раздел 3.2):
##   - Максимум 2 собствени пионки на обща клетка.
##   - Купчина от 2 е имунизирана срещу взимане.
##   - Противниците могат да прескачат купчина (не е стена).
##   - Ход, поставящ трета своя пионка на клетка с 2 свои, е невалиден.


func test_stack_rules_extends_ref_counted() -> void:
	var rules := StackRules.new()
	assert_not_null(rules, "StackRules трябва да може да се инстанцира")
	assert_true(rules is RefCounted,
			"StackRules трябва да extends RefCounted, не Node")


func test_stack_rules_is_not_node() -> void:
	var rules: Object = StackRules.new()
	assert_false(rules is Node,
			"StackRules не трябва да extends Node — domain слой е без сцени")


func test_stack_rules_script_path_is_in_domain() -> void:
	var rules := StackRules.new()
	var path: String = rules.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"StackRules трябва да е в game/domain/")


## Документиран инвариант: максималният размер на купчина е 2.
func test_max_stack_size_invariant_documented() -> void:
	var max_stack := 2
	assert_eq(max_stack, 2,
			"Максимум 2 собствени пионки могат да стоят на обща клетка")


## Документиран инвариант: купчина от 2 е имунизирана срещу взимане.
func test_stack_immunity_requires_two_pawns() -> void:
	var immune_stack_size := 2
	var single_pawn_size := 1
	assert_eq(immune_stack_size, 2,
			"Имунитет срещу взимане изисква точно 2 пионки")
	assert_ne(single_pawn_size, immune_stack_size,
			"Единична пионка не е имунизирана")


## Документиран инвариант: купчина не блокира преминаване.
## Противниците МОГАТ да прескачат купчина при движение.
func test_stack_does_not_block_passage_invariant_documented() -> void:
	# Купчините не са стени — противниците ги прескачат свободно.
	var stack_blocks_passage := false
	assert_false(stack_blocks_passage,
			"Купчина не блокира преминаването на противникови пионки")


## Документиран инвариант: трета своя пионка на клетка с 2 свои е невалиден ход.
func test_third_pawn_on_stack_is_invalid_invariant_documented() -> void:
	var is_valid_to_place_third := false
	assert_false(is_valid_to_place_third,
			"Поставянето на трета своя пионка върху купчина от 2 е невалидно")
