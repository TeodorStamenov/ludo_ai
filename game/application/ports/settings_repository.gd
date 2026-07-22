class_name SettingsRepository
extends RefCounted
## Port интерфейс за четене и запис на потребителски настройки
## (docs/V1_ARCHITECTURE.md, раздел 9).
##
## Управлява: звук, музика, haptics, auto-move, colorblind режим.
## SettingsService autoload използва тази имплементация.
##
## Default стойности са embedded тук за standalone употреба.
##
## Имплементации:
##   - platform/persistence/local_save_repository.gd  (production)
##   - [stub за тестове с in-memory storage]

const DEFAULTS := {
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"haptics_enabled": true,
	"auto_move_single": true,
	"colorblind_mode": false,
}


func load_settings() -> Dictionary:
	push_error("SettingsRepository.load_settings: не е имплементирано")
	return DEFAULTS.duplicate()


func save_settings(data: Dictionary) -> bool:
	push_error("SettingsRepository.save_settings: не е имплементирано")
	return false


func get_default_settings() -> Dictionary:
	return DEFAULTS.duplicate()
