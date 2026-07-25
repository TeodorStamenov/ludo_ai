class_name PawnZoneTest
extends TestCase
## Unit тестове за PawnZone enum (docs/V1_ARCHITECTURE.md, §4.1 и §12).
##
## Покрити инварианти:
##   - Четирите зони съществуват с очакваните целочислени стойности.
##   - Редът на прогресия BASE < MAIN_PATH < HOME_STRETCH < FINISHED е гарантиран.
##   - is_valid() приема само стойности 0–3.
##   - zone_name() връща правилните имена за всяка зона.
##   - ALL съдържа точно 4 уникални стойности в ред по прогресия.
##   - COUNT == 4.


# ── Целочислени стойности ─────────────────────────────────────────────────────

func test_base_value_is_zero() -> void:
	assert_eq(PawnZone.BASE, 0, "BASE трябва да е 0")


func test_main_path_value_is_one() -> void:
	assert_eq(PawnZone.MAIN_PATH, 1, "MAIN_PATH трябва да е 1")


func test_home_stretch_value_is_two() -> void:
	assert_eq(PawnZone.HOME_STRETCH, 2, "HOME_STRETCH трябва да е 2")


func test_finished_value_is_three() -> void:
	assert_eq(PawnZone.FINISHED, 3, "FINISHED трябва да е 3")


# ── Ред на прогресия ──────────────────────────────────────────────────────────

func test_progression_order_base_before_main_path() -> void:
	assert_lt(PawnZone.BASE, PawnZone.MAIN_PATH,
			"BASE трябва да е преди MAIN_PATH в прогресията")


func test_progression_order_main_path_before_home_stretch() -> void:
	assert_lt(PawnZone.MAIN_PATH, PawnZone.HOME_STRETCH,
			"MAIN_PATH трябва да е преди HOME_STRETCH в прогресията")


func test_progression_order_home_stretch_before_finished() -> void:
	assert_lt(PawnZone.HOME_STRETCH, PawnZone.FINISHED,
			"HOME_STRETCH трябва да е преди FINISHED в прогресията")


func test_progression_order_is_strictly_increasing() -> void:
	for i in PawnZone.ALL.size() - 1:
		assert_lt(PawnZone.ALL[i], PawnZone.ALL[i + 1],
				"ALL[%d] трябва да е по-малко от ALL[%d]" % [i, i + 1])


# ── COUNT и ALL ───────────────────────────────────────────────────────────────

func test_count_is_four() -> void:
	assert_eq(PawnZone.COUNT, 4, "COUNT трябва да е 4")


func test_all_has_exactly_four_entries() -> void:
	assert_eq(PawnZone.ALL.size(), 4, "ALL трябва да съдържа точно 4 зони")


func test_all_entries_match_enum_values_in_order() -> void:
	assert_eq(PawnZone.ALL[0], PawnZone.BASE,         "ALL[0] трябва да е BASE")
	assert_eq(PawnZone.ALL[1], PawnZone.MAIN_PATH,    "ALL[1] трябва да е MAIN_PATH")
	assert_eq(PawnZone.ALL[2], PawnZone.HOME_STRETCH, "ALL[2] трябва да е HOME_STRETCH")
	assert_eq(PawnZone.ALL[3], PawnZone.FINISHED,     "ALL[3] трябва да е FINISHED")


func test_all_entries_are_unique() -> void:
	var seen: Dictionary = {}
	for zone in PawnZone.ALL:
		assert_false(seen.has(zone), "PawnZone.ALL съдържа дублирана стойност: %d" % zone)
		seen[zone] = true


func test_all_size_equals_count() -> void:
	assert_eq(PawnZone.ALL.size(), PawnZone.COUNT,
			"ALL.size() трябва да съответства на COUNT")


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_zones() -> void:
	for zone in PawnZone.ALL:
		assert_true(PawnZone.is_valid(zone),
				"is_valid трябва да приема зона %d" % zone)


func test_is_valid_rejects_negative() -> void:
	assert_false(PawnZone.is_valid(-1), "is_valid трябва да отхвърли -1")


func test_is_valid_rejects_count() -> void:
	assert_false(PawnZone.is_valid(PawnZone.COUNT),
			"is_valid трябва да отхвърли COUNT (%d)" % PawnZone.COUNT)


func test_is_valid_rejects_large_integer() -> void:
	assert_false(PawnZone.is_valid(999), "is_valid трябва да отхвърли 999")


func test_is_valid_rejects_boundary_above() -> void:
	assert_false(PawnZone.is_valid(4), "is_valid трябва да отхвърли 4")


# ── zone_name ─────────────────────────────────────────────────────────────────

func test_zone_name_base() -> void:
	assert_eq(PawnZone.zone_name(PawnZone.BASE), &"BASE",
			"zone_name(BASE) трябва да върне &\"BASE\"")


func test_zone_name_main_path() -> void:
	assert_eq(PawnZone.zone_name(PawnZone.MAIN_PATH), &"MAIN_PATH",
			"zone_name(MAIN_PATH) трябва да върне &\"MAIN_PATH\"")


func test_zone_name_home_stretch() -> void:
	assert_eq(PawnZone.zone_name(PawnZone.HOME_STRETCH), &"HOME_STRETCH",
			"zone_name(HOME_STRETCH) трябва да върне &\"HOME_STRETCH\"")


func test_zone_name_finished() -> void:
	assert_eq(PawnZone.zone_name(PawnZone.FINISHED), &"FINISHED",
			"zone_name(FINISHED) трябва да върне &\"FINISHED\"")


func test_zone_name_invalid_returns_unknown() -> void:
	assert_eq(PawnZone.zone_name(-1), &"UNKNOWN",
			"zone_name(-1) трябва да върне &\"UNKNOWN\"")
	assert_eq(PawnZone.zone_name(99), &"UNKNOWN",
			"zone_name(99) трябва да върне &\"UNKNOWN\"")


func test_zone_name_all_zones_match_their_names() -> void:
	var expected: Array[StringName] = [&"BASE", &"MAIN_PATH", &"HOME_STRETCH", &"FINISHED"]
	for i in PawnZone.ALL.size():
		assert_eq(PawnZone.zone_name(PawnZone.ALL[i]), expected[i],
				"zone_name(ALL[%d]) трябва да е &\"%s\"" % [i, expected[i]])
