extends Node
## Навигация и payload между екраните на приложението
## (`docs/V1_ARCHITECTURE.md`, раздел 8; #287):
##
##   BOOT → MAIN_MENU → MATCH_SETUP/CAMPAIGN → GAME → RESULTS
##                            ▲                          │
##                            └────────── REMATCH ────────┘
##
## `AppFlow` е единствената точка, която познава преходите между екраните;
## самите екрани не навигират директно едни към други и не създават
## `MatchSession` — те произвеждат/консумират `MatchConfig` и `MatchSummary`.
##
## Autoload (`/root/AppFlow`) — регистриран в project.godot. `Bootstrap`
## (#288) го конфигурира веднъж, при старт, през configure(): AppFlow носи
## споделените platform/content singleton-и, за да не строи всеки екран
## своя собствена SaveRepository/AnimalRegistry/BoardThemeRegistry.
## ProfileService/SettingsService/AudioService/PlatformService (§8) са
## отделни, все още несъздадени задачи — засега AppFlow временно носи
## save_repository/telemetry_sink/регистрите директно.

const _MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const _MATCH_SETUP_SCENE := "res://scenes/match_setup.tscn"
const _GAME_SCENE := "res://scenes/ludo_game.tscn"

var save_repository: SaveRepository = null
var telemetry_sink: TelemetrySink = null
var animal_registry: AnimalRegistry = null
var theme_registry: BoardThemeRegistry = null

## Non-null само между navigate_to_game(config) и следващото GameScreen._ready()
## — GameScreen го прочита веднъж и веднага го изчиства (виж game_screen.gd).
## null означава "GameScreen сам да реши" (resume от snapshot / default config).
var pending_match_config: MatchConfig = null


## Викa се веднъж от Bootstrap, преди първата навигация.
func configure(
		save_repo: SaveRepository,
		telemetry: TelemetrySink,
		animals: AnimalRegistry,
		themes: BoardThemeRegistry
) -> void:
	save_repository = save_repo
	telemetry_sink = telemetry
	animal_registry = animals
	theme_registry = themes


func navigate_to_main_menu() -> void:
	get_tree().change_scene_to_file(_MAIN_MENU_SCENE)


func navigate_to_match_setup() -> void:
	get_tree().change_scene_to_file(_MATCH_SETUP_SCENE)


## config == null → GameScreen сам решава (resume от active_match.json snapshot,
## иначе fallback default) — пътят, който Bootstrap ползва при auto-resume (#251).
## config != null → фрешо стартиране с този MatchConfig (Match Setup path, #290).
func navigate_to_game(config: MatchConfig = null) -> void:
	pending_match_config = config
	get_tree().change_scene_to_file(_GAME_SCENE)


## GamePresenter вика това при край на мач (duck-typed lookup, вече съществуващ
## в game_presenter.gd) — прави го реално вместо no-op. Results екранът е
## отделна, все още несъздадена задача; засега само персистира статистиката
## (иначе SaveRepository.record_match_result никога не се извиква извън
## тестове) и се връща в менюто.
func navigate_to_results(payload: Dictionary) -> void:
	if save_repository != null and not payload.is_empty():
		save_repository.record_match_result(payload)
	navigate_to_main_menu()
