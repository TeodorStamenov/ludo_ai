class_name LevelModifierIdTest
extends TestCase
## Unit тестове за LevelModifierId (Task #25 / docs/V1_GAME_DESIGN.md §5.1,
## content/campaign/levels/, docs/V1_ARCHITECTURE.md §5.1: level_modifiers[]).
##
## Покрива:
##   - Стабилен gifts_double_frequency идентификатор.
##   - ALL / COUNT / is_valid().
##   - Domain слой: extends RefCounted, път game/domain/ids/.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_level_modifier_id_extends_ref_counted() -> void:
	var m := LevelModifierId.new()
	assert_true(m is RefCounted,
			"LevelModifierId трябва да extends RefCounted")


func test_level_modifier_id_is_not_node() -> void:
	var m: Object = LevelModifierId.new()
	assert_false(m is Node,
			"LevelModifierId не трябва да extends Node")


func test_level_modifier_id_script_path_is_in_domain_ids() -> void:
	var m := LevelModifierId.new()
	var path: String = m.get_script().resource_path
	assert_true(path.contains("game/domain/ids/"),
			"LevelModifierId трябва да е в game/domain/ids/")


# ── Константи ─────────────────────────────────────────────────────────────────

func test_gifts_double_frequency_constant() -> void:
	assert_eq(LevelModifierId.GIFTS_DOUBLE_FREQUENCY, &"gifts_double_frequency")


func test_count_matches_all() -> void:
	assert_eq(LevelModifierId.COUNT, 1)
	assert_eq(LevelModifierId.ALL.size(), 1)
	assert_eq(LevelModifierId.ALL[0], LevelModifierId.GIFTS_DOUBLE_FREQUENCY)


func test_all_entries_are_valid() -> void:
	for id in LevelModifierId.ALL:
		assert_true(LevelModifierId.is_valid(id),
				"ALL трябва да съдържа само валидни id: %s" % id)


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_known_modifiers() -> void:
	assert_true(LevelModifierId.is_valid(LevelModifierId.GIFTS_DOUBLE_FREQUENCY))


func test_is_valid_rejects_empty_and_unknown() -> void:
	assert_false(LevelModifierId.is_valid(&""))
	assert_false(LevelModifierId.is_valid(&"double_gifts"),
			"каноничното id е gifts_double_frequency")
	assert_false(LevelModifierId.is_valid(&"mod_a"))
	assert_false(LevelModifierId.is_valid(&"extra_xp"))
