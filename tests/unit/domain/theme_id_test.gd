class_name ThemeIdTest
extends TestCase
## Unit тестове за ThemeId (Task #25 / docs/V1_GAME_DESIGN.md §2 / §5.1,
## content/themes/, docs/V1_ARCHITECTURE.md §5.1: theme_id).
##
## Покрива:
##   - Двете v1 теми с стабилни StringName ID-та.
##   - DEFAULT и STARTER набори.
##   - is_valid() / is_starter().
##   - Domain слой: extends RefCounted, път game/domain/ids/.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_theme_id_extends_ref_counted() -> void:
	var t := ThemeId.new()
	assert_true(t is RefCounted,
			"ThemeId трябва да extends RefCounted")


func test_theme_id_is_not_node() -> void:
	var t: Object = ThemeId.new()
	assert_false(t is Node,
			"ThemeId не трябва да extends Node")


func test_theme_id_script_path_is_in_domain_ids() -> void:
	var t := ThemeId.new()
	var path: String = t.get_script().resource_path
	assert_true(path.contains("game/domain/ids/"),
			"ThemeId трябва да е в game/domain/ids/")


# ── Константи ─────────────────────────────────────────────────────────────────

func test_theme_constants_have_expected_values() -> void:
	assert_eq(ThemeId.JUNGLE, &"jungle")
	assert_eq(ThemeId.DESERT, &"desert")


func test_default_is_jungle() -> void:
	assert_eq(ThemeId.DEFAULT, ThemeId.JUNGLE)


func test_count_is_two() -> void:
	assert_eq(ThemeId.COUNT, 2)
	assert_eq(ThemeId.ALL.size(), 2)


func test_all_entries_are_valid() -> void:
	for id in ThemeId.ALL:
		assert_true(ThemeId.is_valid(id),
				"ALL трябва да съдържа само валидни id: %s" % id)


func test_starter_has_exactly_jungle() -> void:
	assert_eq(ThemeId.STARTER.size(), 1)
	assert_true(ThemeId.STARTER.has(ThemeId.JUNGLE))
	assert_false(ThemeId.STARTER.has(ThemeId.DESERT),
			"Desert се отключва през кампанията")


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_all_v1_themes() -> void:
	assert_true(ThemeId.is_valid(ThemeId.JUNGLE))
	assert_true(ThemeId.is_valid(ThemeId.DESERT))


func test_is_valid_rejects_empty_and_unknown() -> void:
	assert_false(ThemeId.is_valid(&""))
	assert_false(ThemeId.is_valid(&"ice"))
	assert_false(ThemeId.is_valid(&"beach"))
	assert_false(ThemeId.is_valid(&"forest"),
			"джунглата е jungle, не forest")


# ── is_starter ────────────────────────────────────────────────────────────────

func test_is_starter_for_unlocked_at_start() -> void:
	assert_true(ThemeId.is_starter(ThemeId.JUNGLE))


func test_is_starter_false_for_campaign_unlock() -> void:
	assert_false(ThemeId.is_starter(ThemeId.DESERT))


func test_is_starter_false_for_unknown() -> void:
	assert_false(ThemeId.is_starter(&""))
	assert_false(ThemeId.is_starter(&"ice"))
