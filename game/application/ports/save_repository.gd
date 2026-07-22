class_name SaveRepository
extends RefCounted
## Port интерфейс за четене и запис на persistence данни
## (docs/V1_ARCHITECTURE.md, раздели 9, 10).
##
## Никоя сцена не пише директно в user://. Всеки запис минава оттук.
##
## Управлява три отделни payload-а:
##   settings     — звук, музика, haptics, auto-move, colorblind
##   profile      — XP, unlocks, campaign progress, статистика
##   active_match — snapshot за resume след прекъсване
##
## Всеки файл съдържа schema_version, saved_at, payload.
## Имплементацията трябва да ползва атомичен запис: temp → validate → rename.
##
## Имплементации:
##   - platform/persistence/local_save_repository.gd  (production)
##   - [stub за тестове с in-memory storage]


func save_settings(data: Dictionary) -> bool:
	push_error("SaveRepository.save_settings: не е имплементирано")
	return false


func load_settings() -> Dictionary:
	push_error("SaveRepository.load_settings: не е имплементирано")
	return {}


func save_profile(data: Dictionary) -> bool:
	push_error("SaveRepository.save_profile: не е имплементирано")
	return false


func load_profile() -> Dictionary:
	push_error("SaveRepository.load_profile: не е имплементирано")
	return {}


func save_match_snapshot(snapshot: Dictionary) -> bool:
	push_error("SaveRepository.save_match_snapshot: не е имплементирано")
	return false


func load_match_snapshot() -> Dictionary:
	push_error("SaveRepository.load_match_snapshot: не е имплементирано")
	return {}


func clear_match_snapshot() -> bool:
	push_error("SaveRepository.clear_match_snapshot: не е имплементирано")
	return false


func has_match_snapshot() -> bool:
	push_error("SaveRepository.has_match_snapshot: не е имплементирано")
	return false
