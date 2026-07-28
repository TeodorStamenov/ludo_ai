class_name PresentationRandomSourceTest
extends TestCase
## Unit тестове за PresentationRandomSource
## (Task #33 / docs/V1_ARCHITECTURE.md §4.5).
##
## Покрива:
##   - Presentation слой: път game/presentation/common/, extends RefCounted.
##   - Тип изолация: НЕ е RandomSource (не може да се подаде към GameEngine).
##   - API: next_int / next_float / chance / pick.
##   - Инвариант: консумацията му не променя gameplay SeededRandomSource.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_presentation_random_source_extends_ref_counted() -> void:
	var rng := PresentationRandomSource.new(1)
	assert_true(rng is RefCounted,
			"PresentationRandomSource трябва да extends RefCounted")


func test_presentation_random_source_is_not_node() -> void:
	var rng: Object = PresentationRandomSource.new(1)
	assert_false(rng is Node,
			"PresentationRandomSource не трябва да extends Node — utility, не сцена")


func test_presentation_random_source_script_path_is_in_presentation_common() -> void:
	var rng := PresentationRandomSource.new(1)
	var path: String = rng.get_script().resource_path
	assert_true(path.contains("game/presentation/common/"),
			"PresentationRandomSource трябва да е в game/presentation/common/")


func test_presentation_random_source_is_not_random_source() -> void:
	var rng: Object = PresentationRandomSource.new(1)
	assert_false(rng is RandomSource,
			"PresentationRandomSource не трябва да наследява RandomSource — " +
			"забранява подаването към GameEngine / MatchSession")


# ── Договор: next_int ─────────────────────────────────────────────────────────

func test_next_int_respects_closed_interval() -> void:
	var rng := PresentationRandomSource.new(42)
	for _i in 100:
		var v := rng.next_int(1, 6)
		assert_true(v >= 1 and v <= 6,
				"next_int(1, 6) трябва да е в [1, 6], got %d" % v)


func test_next_int_when_min_equals_max() -> void:
	var rng := PresentationRandomSource.new(7)
	for _i in 10:
		assert_eq(rng.next_int(4, 4), 4,
				"next_int(n, n) трябва да върне n")


func test_next_int_same_seed_produces_same_sequence() -> void:
	var rng1 := PresentationRandomSource.new(777)
	var rng2 := PresentationRandomSource.new(777)
	for _i in 20:
		assert_eq(rng1.next_int(1, 6), rng2.next_int(1, 6),
				"Еднакъв seed трябва да дава идентична next_int последователност")


# ── Договор: next_float ───────────────────────────────────────────────────────

func test_next_float_respects_closed_interval() -> void:
	var rng := PresentationRandomSource.new(99)
	for _i in 100:
		var v := rng.next_float(0.9, 1.15)
		assert_true(v >= 0.9 and v <= 1.15,
				"next_float(0.9, 1.15) трябва да е в диапазона, got %s" % str(v))


func test_next_float_default_unit_interval() -> void:
	var rng := PresentationRandomSource.new(11)
	for _i in 50:
		var v := rng.next_float()
		assert_true(v >= 0.0 and v <= 1.0,
				"next_float() по подразбиране трябва да е в [0, 1], got %s" % str(v))


func test_next_float_same_seed_produces_same_sequence() -> void:
	var rng1 := PresentationRandomSource.new(314)
	var rng2 := PresentationRandomSource.new(314)
	for _i in 20:
		assert_eq(rng1.next_float(0.0, 10.0), rng2.next_float(0.0, 10.0),
				"Еднакъв seed трябва да дава идентична next_float последователност")


# ── Договор: chance / pick ────────────────────────────────────────────────────

func test_chance_returns_bool() -> void:
	var rng := PresentationRandomSource.new(55)
	var saw_true := false
	var saw_false := false
	for _i in 200:
		var result := rng.chance(0.5)
		assert_true(typeof(result) == TYPE_BOOL, "chance трябва да връща bool")
		if result:
			saw_true = true
		else:
			saw_false = true
	assert_true(saw_true and saw_false,
			"chance(0.5) трябва да връща и true, и false при достатъчно опити")


func test_chance_zero_always_false() -> void:
	var rng := PresentationRandomSource.new(3)
	for _i in 30:
		assert_false(rng.chance(0.0), "chance(0) трябва винаги да е false")


func test_chance_one_always_true() -> void:
	var rng := PresentationRandomSource.new(3)
	for _i in 30:
		assert_true(rng.chance(1.0), "chance(1) трябва винаги да е true")


func test_pick_returns_element_from_array() -> void:
	var rng := PresentationRandomSource.new(88)
	var arr: Array = [&"spin_a", &"spin_b", &"spin_c"]
	for _i in 40:
		var picked: Variant = rng.pick(arr)
		assert_true(picked in arr,
				"pick() трябва да връща елемент от масива")


func test_pick_same_seed_produces_same_sequence() -> void:
	var arr: Array = ["a", "b", "c", "d"]
	var rng1 := PresentationRandomSource.new(2026)
	var rng2 := PresentationRandomSource.new(2026)
	for _i in 20:
		assert_eq(rng1.pick(arr), rng2.pick(arr),
				"Еднакъв seed трябва да дава идентична pick последователност")


# ── Изолация от gameplay RNG (§4.5 инвариант) ─────────────────────────────────

func test_cosmetic_draws_do_not_advance_gameplay_rng() -> void:
	## Козметичните тегления не трябва да влияят върху domain SeededRandomSource.
	const GAMEPLAY_SEED := 12345
	var gameplay := SeededRandomSource.new(GAMEPLAY_SEED)
	var cosmetic := PresentationRandomSource.new(999)

	var expected_state := gameplay.get_state().duplicate(true)

	for _i in 50:
		cosmetic.next_float(0.9, 1.15)
		cosmetic.chance(0.5)
		cosmetic.next_int(1, 4)

	assert_eq(gameplay.get_state(), expected_state,
			"PresentationRandomSource не трябва да променя gameplay RNG state")


func test_interleaved_cosmetic_and_gameplay_streams_stay_isolated() -> void:
	## Същият gameplay seed + същите domain извиквания = същият поток,
	## независимо колко козметични тегления се правят между тях.
	const GAMEPLAY_SEED := 424242
	var reference := SeededRandomSource.new(GAMEPLAY_SEED)
	var expected: Array = []
	for _i in 30:
		expected.append(reference.next_int(1, 6))

	var gameplay := SeededRandomSource.new(GAMEPLAY_SEED)
	var cosmetic := PresentationRandomSource.new(777)
	var actual: Array = []
	for _i in 30:
		cosmetic.next_float(2.5, 4.0)
		cosmetic.chance(0.5)
		actual.append(gameplay.next_int(1, 6))

	assert_eq(actual, expected,
			"Gameplay потокът трябва да е идентичен при преплетени cosmetic draws")


func test_presentation_rng_does_not_share_state_with_match_config_rng() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 55555
	var match_rng := cfg.create_random_source()
	var before := match_rng.get_state().duplicate(true)

	var cosmetic := PresentationRandomSource.new(cfg.rng_seed)
	for _i in 40:
		cosmetic.next_int(1, 6)
		cosmetic.next_float()

	assert_eq(match_rng.get_state(), before,
			"Дори със същия seed-число, presentation RNG е отделна инстанция " +
			"и не пипа MatchConfig.create_random_source()")


func test_dice_view_owns_presentation_rng_by_default() -> void:
	var view := DiceView.new()
	assert_true(view.cosmetic_rng != null,
			"DiceView трябва да има PresentationRandomSource по подразбиране")
	assert_true(view.cosmetic_rng is PresentationRandomSource)
	# Cast през Object — статичният анализатор знае, че типът не е RandomSource.
	var rng_obj: Object = view.cosmetic_rng
	assert_false(rng_obj is RandomSource,
			"DiceView.cosmetic_rng не трябва да е RandomSource (#160)")
	view.free()


func test_dice_view_set_cosmetic_rng_accepts_injection() -> void:
	var view := DiceView.new()
	var injected := PresentationRandomSource.new(42)
	view.set_cosmetic_rng(injected)
	assert_eq(view.cosmetic_rng.get_seed(), 42,
			"set_cosmetic_rng трябва да приеме инжектирания instance")
	view.set_cosmetic_rng(null)
	assert_true(view.cosmetic_rng != null,
			"set_cosmetic_rng(null) трябва да създаде нов randomized instance")
	view.free()
