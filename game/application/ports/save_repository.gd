class_name SaveRepository
extends RefCounted
## Port интерфейс за четене и запис на persistence данни
## (docs/V1_ARCHITECTURE.md, раздели 9, 10).
##
## Никоя сцена не пише директно в user://. Всеки запис минава оттук.
##
## Управлява три отделни payload-а:
##   settings     — звук, музика, haptics, auto-move, colorblind (SettingsData, #243)
##   profile      — XP, unlocks, campaign progress, статистика (ProfileData, #242)
##   active_match — snapshot за resume след прекъсване (ActiveMatchSave, #244)
##
## Всеки файл съдържа schema_version, saved_at, payload (envelope-ниво).
## Отделно ProfileData/SettingsData носят собствен schema_version в самия
## payload — двете версии са независими: envelope-ът версионира файловия
## формат, моделът версионира собствената си вътрешна форма (#245).
## Имплементацията трябва да ползва атомичен запис: temp → validate → rename.
##
## Профилните удобни методи (get_xp/unlock/статистика) по-долу бяха
## самостоятелен ProgressRepository порт; settings-специфичният
## get_default_settings() беше самостоятелен SettingsRepository порт —
## консолидирани тук, защото нищо реално не ги имплементираше поотделно
## (само LocalSaveRepository ги duck-type-ваше без формална връзка).
##
## Имплементации:
##   - platform/persistence/local_save_repository.gd  (production)
##   - platform/persistence/stub_save_repository.gd    (in-memory, тестове)


func save_settings(data: Dictionary) -> bool:
	push_error("SaveRepository.save_settings: не е имплементирано")
	return false


func load_settings() -> Dictionary:
	push_error("SaveRepository.load_settings: не е имплементирано")
	return {}


## Стойностите по подразбиране за настройки (SettingsData.create_default()).
func get_default_settings() -> Dictionary:
	push_error("SaveRepository.get_default_settings: не е имплементирано")
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


# --- Профил: XP / unlocks / статистика (бивш ProgressRepository) ---
##
## XP прагове (ориентировъчни, виж V1_GAME_DESIGN.md раздел 5.2):
##   Победа: 100 XP; второ: 40 XP; загуба: 20 XP.
##   Бонуси: взет подарък, взета пионка, прибрана пионка.

func get_xp() -> int:
	push_error("SaveRepository.get_xp: не е имплементирано")
	return 0


func add_xp(amount: int) -> int:
	push_error("SaveRepository.add_xp: не е имплементирано")
	return 0


func get_unlocks() -> Array:
	push_error("SaveRepository.get_unlocks: не е имплементирано")
	return []


func unlock(item_id: StringName) -> void:
	push_error("SaveRepository.unlock: не е имплементирано")


func is_unlocked(item_id: StringName) -> bool:
	push_error("SaveRepository.is_unlocked: не е имплементирано")
	return false


func get_statistics() -> Dictionary:
	push_error("SaveRepository.get_statistics: не е имплементирано")
	return {}


func record_match_result(summary: Dictionary) -> void:
	push_error("SaveRepository.record_match_result: не е имплементирано")
