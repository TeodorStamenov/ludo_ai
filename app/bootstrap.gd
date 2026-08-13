extends Node
## Начална точка на приложението (фаза BOOT от `docs/V1_ARCHITECTURE.md`,
## раздел 8; #288). `run/main_scene` (project.godot) сочи към
## `scenes/bootstrap.tscn` — този скрипт е единственото му съдържание, без
## видим UI.
##
## Отговорности:
## - конструира platform adapters/singleton-и веднъж (SaveRepository,
##   TelemetrySink, AnimalRegistry, BoardThemeRegistry) и ги подава на
##   `AppFlow.configure()`, за да не строи всеки екран свои копия;
## - решава първата навигация: ако има запазен `active_match.json`
##   (прекъснат мач), отива директно в Game (запазва #251 auto-resume
##   поведението, вместо да пита през Main Menu); иначе → Main Menu.
##
## Ads/Audio/Haptics platform услуги (§10) и content валидация при старт
## остават извън обхвата на #288 — засега AnimalRegistry/BoardThemeRegistry
## само се конструират (собствената им `_init()` вече валидира наличните
## `.tres` записи чрез `load()`).


func _ready() -> void:
	var save_repository: SaveRepository = LocalSaveRepository.new()
	var telemetry_sink: TelemetrySink = LocalTelemetrySink.new()
	var animal_registry := AnimalRegistry.new()
	var theme_registry := BoardThemeRegistry.new()

	var app_flow := get_node(^"/root/AppFlow")
	app_flow.configure(save_repository, telemetry_sink, animal_registry, theme_registry)

	if save_repository.has_match_snapshot():
		app_flow.navigate_to_game(null)
	else:
		app_flow.navigate_to_main_menu()
