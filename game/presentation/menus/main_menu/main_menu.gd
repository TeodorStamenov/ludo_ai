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

@onready var _resume_game_button: Button = $Panel/ResumeGameButton
@onready var _new_game_button: Button = $Panel/NewGameButton
@onready var _campaign_button: Button = $Panel/CampaignButton
@onready var _settings_button: Button = $Panel/SettingsButton

var _app_flow: Node = null


func _ready() -> void:
	_campaign_button.disabled = true
	_campaign_button.tooltip_text = _NOT_AVAILABLE_TOOLTIP
	_settings_button.disabled = true
	_settings_button.tooltip_text = _NOT_AVAILABLE_TOOLTIP

	_app_flow = get_node(^"/root/AppFlow")
	# Прекъснат мач (#250 auto-save) → показва „Продължи играта"; иначе бутонът
	# е скрит — Bootstrap вече auto-resume-ва при старт на приложението (#251),
	# този бутон покрива връщането в менюто ОТ активен мач (#292).
	var has_saved_match: bool = (
			_app_flow.save_repository != null
			and _app_flow.save_repository.has_match_snapshot())
	_resume_game_button.visible = has_saved_match

	_resume_game_button.pressed.connect(_on_resume_game_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)


func _on_resume_game_pressed() -> void:
	_app_flow.navigate_to_game(null)


func _on_new_game_pressed() -> void:
	_app_flow.navigate_to_match_setup()
