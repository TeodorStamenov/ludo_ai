class_name DebugMatchBuffer
extends RefCounted
## Ограничен circular buffer за последните debug мачове
## (roadmap #144; логове / replay политика — последните ~5 подробни записа).
##
## Пази GameplayJournal payloads (и опционален MatchSummary) в памет.
## При надхвърляне на capacity изтрива най-стария запис (FIFO eviction).
## Без FileAccess — platform adapter-и могат да сериализират get_entries()
## към user://logs/. Caller инжектира буфера само в debug builds.

## Приблизително 5 мача в debug builds (roadmap logging policy).
const DEFAULT_CAPACITY := 5

const KEY_MATCH_ID := "match_id"
const KEY_RECORDED_AT := "recorded_at"
const KEY_JOURNAL := "journal"
const KEY_SUMMARY := "summary"


var _capacity: int = DEFAULT_CAPACITY
var _entries: Array[Dictionary] = []


func _init(capacity: int = DEFAULT_CAPACITY) -> void:
	_capacity = maxi(1, capacity)


func get_capacity() -> int:
	return _capacity


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	_entries.clear()


## Добавя готов entry dict. При overflow премахва най-стария.
## Връща изтласкания entry или {} ако няма eviction.
func push(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	_entries.append(entry.duplicate(true))
	if _entries.size() <= _capacity:
		return {}
	var evicted: Dictionary = _entries.pop_front()
	return evicted


## Архивира journal (+ опционален summary) като най-нов debug запис.
## Null journal → no-op. Връща изтласкания entry или {}.
func push_journal(
		journal: GameplayJournal,
		summary: Dictionary = {},
		recorded_at: String = ""
) -> Dictionary:
	if journal == null:
		return {}
	var at := recorded_at
	if at.is_empty():
		at = Time.get_datetime_string_from_system()
	var entry := {
		KEY_MATCH_ID: String(journal.match_id),
		KEY_RECORDED_AT: at,
		KEY_JOURNAL: journal.to_dict(),
		KEY_SUMMARY: summary.duplicate(true),
	}
	return push(entry)


## Записи от най-стар към най-нов (копия).
func get_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		out.append(entry.duplicate(true))
	return out


## Най-новият запис, или {} ако буферът е празен.
func get_latest() -> Dictionary:
	if _entries.is_empty():
		return {}
	return _entries[_entries.size() - 1].duplicate(true)


## True ако entry има journal payload и match_id.
static func is_valid_entry(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if not entry.has(KEY_MATCH_ID):
		return false
	var journal: Variant = entry.get(KEY_JOURNAL, null)
	if not (journal is Dictionary):
		return false
	if (journal as Dictionary).is_empty():
		return false
	return true
