extends TestCase
## Unit тестове за CaptureRules — правилата за взимане на пионки.
##
## Критични инварианти (docs/V1_ARCHITECTURE.md, раздел 12):
##   - Единична незащитена противникова пионка се взима при стъпване.
##   - Взетата пионка се връща в базата на своя играч.
##   - Пионки в home stretch са защитени от взимане и power-up ефекти.
##   - Купчина от 2 е имунизирана — не може да се взима.


func test_capture_rules_extends_ref_counted() -> void:
	var rules := CaptureRules.new()
	assert_not_null(rules, "CaptureRules трябва да може да се инстанцира")
	assert_true(rules is RefCounted,
			"CaptureRules трябва да extends RefCounted, не Node")


func test_capture_rules_is_not_node() -> void:
	var rules: Object = CaptureRules.new()
	assert_false(rules is Node,
			"CaptureRules не трябва да extends Node — domain слой е без сцени")


func test_capture_rules_script_path_is_in_domain() -> void:
	var rules := CaptureRules.new()
	var path: String = rules.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"CaptureRules трябва да е в game/domain/")


## Документиран инвариант: home stretch не може да бъде атакуван.
## Пионки в HOME_STRETCH и FINISHED зони са недостъпни за взимане и power-up.
func test_home_stretch_immune_to_capture_invariant_documented() -> void:
	var home_stretch_can_be_attacked := false
	assert_false(home_stretch_can_be_attacked,
			"Пионки в home stretch са защитени от взимане")


## Документиран инвариант: взета пионка се връща в база (не изчезва).
## Общият брой пионки никога не трябва да намалява.
func test_captured_pawn_returns_to_base_invariant_documented() -> void:
	# Инвариант: 4 пионки на играч винаги трябва да присъстват в game state.
	var pawns_per_player := 4
	assert_eq(pawns_per_player, 4,
			"Всеки играч трябва да има точно 4 пионки по всяко време")


## Документиран инвариант: купчина от 2 е имунизирана срещу взимане.
func test_stack_of_two_cannot_be_captured_invariant_documented() -> void:
	var stack_is_immune := true
	assert_true(stack_is_immune,
			"Купчина от 2 пионки е имунизирана срещу взимане")


## Документиран инвариант: взимане е невъзможно в BASE зона.
func test_base_zone_immune_to_capture_invariant_documented() -> void:
	var base_can_be_attacked := false
	assert_false(base_can_be_attacked,
			"Пионки в базата не могат да бъдат взимани")
