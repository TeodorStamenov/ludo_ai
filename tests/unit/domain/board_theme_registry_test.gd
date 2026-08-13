extends TestCase
## Unit тестове за BoardThemeRegistry и реалния content/themes/jungle.tres (#234).
##
## Покрива: зареждане на .tres дефиницията, fallback към DEFAULT тема, и че
## авторизираният запис минава BoardThemeDefinitionValidator.


var _registry: BoardThemeRegistry


func before_each() -> void:
	_registry = BoardThemeRegistry.new()


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_registry_extends_ref_counted() -> void:
	assert_true(_registry is RefCounted,
			"BoardThemeRegistry трябва да extends RefCounted")


func test_registry_is_not_node() -> void:
	var registry: Object = _registry
	assert_false(registry is Node,
			"BoardThemeRegistry не трябва да extends Node")


# ── Заредени дефиниции ────────────────────────────────────────────────────────

func test_loads_definition_for_jungle() -> void:
	var definition := _registry.definition_for(ThemeId.JUNGLE)
	assert_not_null(definition, "липсва content/themes/jungle.tres")
	assert_eq(definition.theme_id, ThemeId.JUNGLE)


func test_jungle_definition_passes_validator() -> void:
	var definition := _registry.definition_for(ThemeId.JUNGLE)
	var result := BoardThemeDefinitionValidator.validate(definition)
	assert_true(result.is_ok(),
			"jungle.tres не минава валидатора: %s" % result.first_error_message())


func test_jungle_has_distinct_texture_per_player() -> void:
	var definition := _registry.definition_for(ThemeId.JUNGLE)
	var seen: Array = []
	for player_id in PlayerId.ALL:
		var texture := definition.texture_for_player(player_id)
		assert_not_null(texture, "липсва текстура за %s" % player_id)
		assert_false(texture in seen, "%s преизползва чужда текстура" % player_id)
		seen.append(texture)


func test_desert_has_no_definition_yet() -> void:
	# Desert още няма арт/звук — регистърът честно връща null.
	assert_false(_registry.has_definition(ThemeId.DESERT))
	assert_null(_registry.definition_for(ThemeId.DESERT))


# ── fallback ───────────────────────────────────────────────────────────────────

func test_definition_for_or_default_returns_own_definition_when_authored() -> void:
	var jungle := _registry.definition_for_or_default(ThemeId.JUNGLE)
	assert_not_null(jungle)
	assert_eq(jungle, _registry.definition_for(ThemeId.JUNGLE))


func test_definition_for_or_default_falls_back_to_default_theme() -> void:
	# Presentation винаги трябва да получи използваема тема.
	var desert_fallback := _registry.definition_for_or_default(ThemeId.DESERT)
	assert_not_null(desert_fallback,
			"тема без запис пада към ThemeId.DEFAULT, не към null")
	assert_eq(desert_fallback, _registry.definition_for(ThemeId.DEFAULT))


func test_definition_for_or_default_unknown_theme_falls_back_too() -> void:
	assert_not_null(_registry.definition_for_or_default(&"snow"))
