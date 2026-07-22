class_name ProgressRepository
extends RefCounted
## Port интерфейс за четене и запис на профил данни
## (docs/V1_ARCHITECTURE.md, раздел 9).
##
## Управлява XP, unlocks, campaign progress и агрегирана статистика.
## Структурата е сериализуема — във v2 се мигрира към профил в облака.
##
## XP прагове (ориентировъчни, виж V1_GAME_DESIGN.md раздел 5.2):
##   Победа: 100 XP; второ: 40 XP; загуба: 20 XP.
##   Бонуси: взет подарък, взета пионка, прибрана пионка.
##
## Имплементации:
##   - platform/persistence/local_save_repository.gd  (чрез SaveRepository)
##   - [stub за тестове с in-memory storage]


func get_xp() -> int:
	push_error("ProgressRepository.get_xp: не е имплементирано")
	return 0


func add_xp(amount: int) -> int:
	push_error("ProgressRepository.add_xp: не е имплементирано")
	return 0


func get_unlocks() -> Array:
	push_error("ProgressRepository.get_unlocks: не е имплементирано")
	return []


func unlock(item_id: StringName) -> void:
	push_error("ProgressRepository.unlock: не е имплементирано")


func is_unlocked(item_id: StringName) -> bool:
	push_error("ProgressRepository.is_unlocked: не е имплементирано")
	return false


func get_statistics() -> Dictionary:
	push_error("ProgressRepository.get_statistics: не е имплементирано")
	return {}


func record_match_result(summary: Dictionary) -> void:
	push_error("ProgressRepository.record_match_result: не е имплементирано")
