extends TestCase
## Unit тестове за BoardThemeDefinition (content/themes/board_theme_definition.gd; #234).
##
## Покрива: Resource-базов authoring формат (огледало на AnimalDefinition/
## PowerUpDefinition/GiftDefinition), is_valid() делегиране, texture_for_player().


func test_board_theme_definition_extends_resource() -> void:
	var definition := BoardThemeDefinition.new()
	assert_not_null(definition)
	assert_true(definition is Resource,
			"BoardThemeDefinition трябва да extends Resource (authoring формат, #7)")


func test_board_theme_definition_script_path_is_in_content_themes() -> void:
	var path: String = BoardThemeDefinition.new().get_script().resource_path
	assert_true(path.contains("content/themes/"),
			"BoardThemeDefinition трябва да е в content/themes/")


func test_default_fields_are_empty_and_invalid() -> void:
	var definition := BoardThemeDefinition.new()
	assert_eq(definition.theme_id, &"")
	assert_null(definition.center_texture)
	assert_null(definition.path_texture)
	assert_true(definition.player_textures.is_empty())
	assert_null(definition.gift_visual)
	assert_null(definition.ambience_audio)
	assert_true(definition.sfx_set.is_empty())
	assert_false(definition.is_valid())


func test_texture_for_player_returns_null_when_missing() -> void:
	var definition := BoardThemeDefinition.new()
	assert_null(definition.texture_for_player(PlayerId.GREEN))


func test_texture_for_player_returns_registered_texture() -> void:
	var definition := BoardThemeDefinition.new()
	var texture := ImageTexture.new()
	definition.player_textures[PlayerId.GREEN] = texture
	assert_eq(definition.texture_for_player(PlayerId.GREEN), texture)


func test_is_valid_delegates_to_validator() -> void:
	var definition := BoardThemeDefinition.new()
	definition.theme_id = ThemeId.JUNGLE
	definition.center_texture = ImageTexture.new()
	definition.path_texture = ImageTexture.new()
	for player_id in PlayerId.ALL:
		definition.player_textures[player_id] = ImageTexture.new()
	assert_eq(definition.is_valid(), BoardThemeDefinitionValidator.is_valid(definition))
	assert_true(definition.is_valid())
