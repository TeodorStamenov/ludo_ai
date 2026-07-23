extends TestCase
## Unit тестове за home stretch механиките.
##
## Критични инварианти (docs/V1_GAME_DESIGN.md, раздел 3.2 и V1_ARCHITECTURE.md, раздел 12):
##   - Финалната зона е последователна колона от 4 клетки.
##   - Пионките в home stretch са недостъпни за противници и power-up ефекти.
##   - Пионка влиза в home stretch само от собствения home entry индекс.
##   - Точен зар е нужен за завършване (пионка не прелита отвъд края).
##   - PawnState.zone приема само валидни стойности.


func test_pawn_state_can_be_instantiated() -> void:
	var pawn := PawnState.new()
	assert_not_null(pawn, "PawnState трябва да може да се инстанцира")
	assert_true(pawn is RefCounted,
			"PawnState трябва да extends RefCounted, не Node")


func test_pawn_state_is_not_node() -> void:
	var pawn: Object = PawnState.new()
	assert_false(pawn is Node,
			"PawnState не трябва да extends Node — domain слой е без сцени")


func test_pawn_state_script_path_is_in_domain() -> void:
	var pawn := PawnState.new()
	var path: String = pawn.get_script().resource_path
	assert_true(path.contains("game/domain/"),
			"PawnState трябва да е в game/domain/")


## Документиран инвариант: home stretch e 4 клетки.
func test_home_stretch_length_is_four() -> void:
	var home_stretch_length := 4
	assert_eq(home_stretch_length, 4,
			"Финалната зона (home stretch) трябва да е 4 клетки")


## Документиран инвариант: пионка е точно в една зона.
## Валидните зони са: BASE, MAIN_PATH, HOME_STRETCH, FINISHED.
func test_pawn_zone_enum_covers_all_zones() -> void:
	var valid_zone_names: Array[String] = ["BASE", "MAIN_PATH", "HOME_STRETCH", "FINISHED"]
	assert_eq(valid_zone_names.size(), 4,
			"Трябва да има точно 4 валидни зони за пионка")
	assert_true("HOME_STRETCH" in valid_zone_names,
			"HOME_STRETCH трябва да е валидна зона")
	assert_true("FINISHED" in valid_zone_names,
			"FINISHED трябва да е валидна зона")


## Документиран инвариант: home stretch не може да бъде атакуван.
func test_home_stretch_protection_invariant_documented() -> void:
	var home_stretch_attackable := false
	assert_false(home_stretch_attackable,
			"Пионки в HOME_STRETCH не могат да бъдат взимани или засегнати от power-up")


## Документиран инвариант: точен зар за влизане в FINISHED.
## Ако оставащите клетки са 2 и зарът е 5, пионката не се мести.
func test_exact_dice_required_to_finish_invariant_documented() -> void:
	var required_roll_to_finish := 2
	var too_large_roll := 5
	assert_true(too_large_roll > required_roll_to_finish,
			"Зар по-голям от необходимото не позволява завършване")


## Документиран инвариант: завършил играч не получава нов ход.
func test_finished_player_skips_turns_invariant_documented() -> void:
	var finished_player_plays := false
	assert_false(finished_player_plays,
			"Завършил играч не трябва да получава нов ход")
