class_name MainMenu
extends Control
## Главното меню на Cosy Ludo (docs/V1_GAME_DESIGN.md §8.1; #289).
##
## Минималистично, cosy: бутони „Нова игра", „Кампания", „Настройки".
## Стилов ориентир: Monument Valley / Alba — чисти, спокойни менюта.
##
## Бутоните навигират чрез AppFlow, никога директно към сцени. „Кампания"/
## „Настройки" остават disabled — Campaign (#291?) и Settings екраните са
## отделни, все още несъздадени задачи.

const _NOT_AVAILABLE_TOOLTIP := "Очаквайте скоро"

@onready var _new_game_button: Button = $Panel/NewGameButton
@onready var _campaign_button: Button = $Panel/CampaignButton
@onready var _settings_button: Button = $Panel/SettingsButton


func _ready() -> void:
	_campaign_button.disabled = true
	_campaign_button.tooltip_text = _NOT_AVAILABLE_TOOLTIP
	_settings_button.disabled = true
	_settings_button.tooltip_text = _NOT_AVAILABLE_TOOLTIP

	_new_game_button.pressed.connect(_on_new_game_pressed)


func _on_new_game_pressed() -> void:
	var app_flow := get_node(^"/root/AppFlow")
	app_flow.navigate_to_match_setup()
