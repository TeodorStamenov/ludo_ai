extends TestCase
## Unit тестове за BoardThemeDefinitionValidator (content/themes/; #234).
##
## Покрива:
##   - Архитектура (RefCounted, не Node, Result).
##   - Валиден запис → Result.ok.
##   - Стабилен error code за всяко договорно нарушение.
##   - Натрупване на няколко грешки в един запис (не спира на първата).
##   - validate_roster: уникалност на theme_id + покритие на ThemeId.ALL.
##   - Презентационните полета НЕ участват във валидацията.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_validator_extends_ref_counted() -> void:
	var v := BoardThemeDefinitionValidator.new()
	assert_true(v is RefCounted,
			"BoardThemeDefinitionValidator трябва да extends RefCounted")


func test_validator_is_not_node() -> void:
	var v: Object = BoardThemeDefinitionValidator.new()
	assert_false(v is Node,
			"BoardThemeDefinitionValidator не трябва да extends Node")


func test_validator_script_path_is_in_content_themes() -> void:
	var path: String = BoardThemeDefinitionValidator.new().get_script().resource_path
	assert_true(path.contains("content/themes/"),
			"валидаторът живее до класа, който валидира (domain не зависи от content)")


func test_result_extends_ref_counted() -> void:
	var result := BoardThemeDefinitionValidator.Result.new()
	assert_true(result is RefCounted,
			"BoardThemeDefinitionValidator.Result трябва да extends RefCounted")


# ── Валиден запис ─────────────────────────────────────────────────────────────

func test_valid_definition_passes() -> void:
	var result := BoardThemeDefinitionValidator.validate(_valid_definition())
	assert_true(result.is_ok(), "пълен валиден запис трябва да мине")
	assert_eq(result.error_codes.size(), 0)
	assert_true(BoardThemeDefinitionValidator.is_valid(_valid_definition()))


func test_valid_for_every_v1_theme_id() -> void:
	for id in ThemeId.ALL:
		var definition := _valid_definition()
		definition.theme_id = id
		assert_true(BoardThemeDefinitionValidator.is_valid(definition),
				"theme_id %s трябва да е валиден" % id)


func test_missing_presentation_fields_still_valid() -> void:
	# gift_visual/ambience_audio/sfx_set са извън обхвата на този валидатор.
	var definition := _valid_definition()
	definition.gift_visual = null
	definition.ambience_audio = null
	definition.sfx_set = {}
	assert_true(BoardThemeDefinitionValidator.is_valid(definition))


# ── Единични нарушения ────────────────────────────────────────────────────────

func test_null_definition_reports_null_error() -> void:
	var result := BoardThemeDefinitionValidator.validate(null)
	assert_true(result.is_invalid())
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_NULL_DEFINITION))
	assert_eq(result.error_codes.size(), 1,
			"null записът излиза веднага — без последващи проверки")


func test_invalid_theme_id_reports_error() -> void:
	var definition := _valid_definition()
	definition.theme_id = &"not_a_theme"
	var result := BoardThemeDefinitionValidator.validate(definition)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_INVALID_THEME_ID))


func test_missing_center_texture_reports_error() -> void:
	var definition := _valid_definition()
	definition.center_texture = null
	var result := BoardThemeDefinitionValidator.validate(definition)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_CENTER_TEXTURE))


func test_missing_path_texture_reports_error() -> void:
	var definition := _valid_definition()
	definition.path_texture = null
	var result := BoardThemeDefinitionValidator.validate(definition)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_PATH_TEXTURE))


func test_missing_player_texture_reports_error_per_player() -> void:
	var definition := _valid_definition()
	definition.player_textures.erase(PlayerId.CYAN)
	var result := BoardThemeDefinitionValidator.validate(definition)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_PLAYER_TEXTURE))


func test_missing_all_player_textures_reports_error_for_each() -> void:
	var definition := _valid_definition()
	definition.player_textures.clear()
	var result := BoardThemeDefinitionValidator.validate(definition)
	var count: int = 0
	for code in result.error_codes:
		if code == BoardThemeDefinitionValidator.ERR_MISSING_PLAYER_TEXTURE:
			count += 1
	assert_eq(count, PlayerId.ALL.size())


# ── Натрупване на грешки ──────────────────────────────────────────────────────

func test_collects_all_violations_without_stopping_at_first() -> void:
	var definition := BoardThemeDefinition.new()  # всички полета празни
	var result := BoardThemeDefinitionValidator.validate(definition)
	assert_true(result.is_invalid())
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_INVALID_THEME_ID))
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_CENTER_TEXTURE))
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_PATH_TEXTURE))
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_PLAYER_TEXTURE))


func test_describe_first_violation_formats_code_and_message() -> void:
	var definition := _valid_definition()
	definition.center_texture = null
	var described := BoardThemeDefinitionValidator.describe_first_violation(definition)
	assert_true(described.begins_with(
			String(BoardThemeDefinitionValidator.ERR_MISSING_CENTER_TEXTURE)))
	assert_eq(BoardThemeDefinitionValidator.describe_first_violation(_valid_definition()), "",
			"валиден запис няма описание на нарушение")


# ── Ростер (колекция) ─────────────────────────────────────────────────────────

func test_full_roster_passes() -> void:
	var result := BoardThemeDefinitionValidator.validate_roster(_full_roster())
	assert_true(result.is_ok(), "пълен ростер от всички ThemeId.ALL трябва да мине")
	assert_eq(result.error_codes.size(), 0)


func test_roster_reports_duplicate_theme_id() -> void:
	var roster := _full_roster()
	roster[1].theme_id = roster[0].theme_id
	var result := BoardThemeDefinitionValidator.validate_roster(roster)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_DUPLICATE_THEME_ID))


func test_roster_reports_missing_theme() -> void:
	var roster := _full_roster()
	roster.remove_at(roster.size() - 1)
	var result := BoardThemeDefinitionValidator.validate_roster(roster)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_MISSING_THEME))


func test_roster_reports_invalid_entry() -> void:
	var roster := _full_roster()
	roster[0].center_texture = null
	var result := BoardThemeDefinitionValidator.validate_roster(roster)
	assert_true(result.has_error(BoardThemeDefinitionValidator.ERR_INVALID_ENTRY))


func test_empty_roster_reports_every_missing_theme() -> void:
	var result := BoardThemeDefinitionValidator.validate_roster([])
	assert_true(result.is_invalid())
	assert_eq(result.error_codes.size(), ThemeId.COUNT,
			"празен ростер → по едно ERR_MISSING_THEME за всяка v1 тема")


# ── Помощни ───────────────────────────────────────────────────────────────────

func _valid_definition() -> BoardThemeDefinition:
	var definition := BoardThemeDefinition.new()
	definition.theme_id = ThemeId.JUNGLE
	definition.center_texture = ImageTexture.new()
	definition.path_texture = ImageTexture.new()
	for player_id in PlayerId.ALL:
		definition.player_textures[player_id] = ImageTexture.new()
	return definition


## По един валиден запис за всяка v1 тема.
func _full_roster() -> Array:
	var roster: Array = []
	for id in ThemeId.ALL:
		var definition := _valid_definition()
		definition.theme_id = id
		roster.append(definition)
	return roster
