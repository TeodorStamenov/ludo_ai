extends TestCase
## Тестове за DebugMatchBuffer — circular eviction на последните debug мачове (#144).
##
## Покрива capacity invariant: при overflow се изтрива най-старият запис,
## най-новият се запазва. Без I/O.


func _make_journal(match_id: StringName, seed_value: int = 1) -> GameplayJournal:
	var journal := GameplayJournal.new()
	journal.begin(match_id)
	journal.record_header(null, seed_value, &"1")
	return journal


func test_push_under_capacity_keeps_all() -> void:
	var buffer := DebugMatchBuffer.new(3)
	buffer.push_journal(_make_journal(&"m1"), {}, "t1")
	buffer.push_journal(_make_journal(&"m2"), {}, "t2")
	assert_eq(buffer.size(), 2)
	var entries := buffer.get_entries()
	assert_eq(entries[0].get(DebugMatchBuffer.KEY_MATCH_ID), "m1")
	assert_eq(entries[1].get(DebugMatchBuffer.KEY_MATCH_ID), "m2")


func test_overflow_evicts_oldest_fifo() -> void:
	var buffer := DebugMatchBuffer.new(2)
	buffer.push_journal(_make_journal(&"m1"), {}, "t1")
	buffer.push_journal(_make_journal(&"m2"), {}, "t2")
	var evicted := buffer.push_journal(_make_journal(&"m3"), {}, "t3")
	assert_eq(buffer.size(), 2, "capacity must not be exceeded")
	assert_eq(evicted.get(DebugMatchBuffer.KEY_MATCH_ID), "m1", "oldest must be evicted")
	var entries := buffer.get_entries()
	assert_eq(entries[0].get(DebugMatchBuffer.KEY_MATCH_ID), "m2")
	assert_eq(entries[1].get(DebugMatchBuffer.KEY_MATCH_ID), "m3")
	assert_eq(
			buffer.get_latest().get(DebugMatchBuffer.KEY_MATCH_ID),
			"m3",
			"latest must be newest")


func test_default_capacity_is_five() -> void:
	var buffer := DebugMatchBuffer.new()
	assert_eq(buffer.get_capacity(), DebugMatchBuffer.DEFAULT_CAPACITY)
	assert_eq(DebugMatchBuffer.DEFAULT_CAPACITY, 5)
	for i in 6:
		buffer.push_journal(_make_journal(StringName("m%d" % i)), {}, "t%d" % i)
	assert_eq(buffer.size(), 5)
	var ids: Array[String] = []
	for entry: Dictionary in buffer.get_entries():
		ids.append(str(entry.get(DebugMatchBuffer.KEY_MATCH_ID, "")))
	assert_false(ids.has("m0"), "first of six must be gone")
	assert_true(ids.has("m5"), "newest must remain")


func test_push_journal_stores_journal_and_summary() -> void:
	var buffer := DebugMatchBuffer.new(1)
	var journal := _make_journal(&"match_abc", 42)
	var summary := {"ranking": ["a", "b"], "schema_version": 1}
	buffer.push_journal(journal, summary, "2026-07-27T12:00:00")
	var entry := buffer.get_latest()
	assert_true(DebugMatchBuffer.is_valid_entry(entry))
	assert_eq(entry.get(DebugMatchBuffer.KEY_MATCH_ID), "match_abc")
	assert_eq(entry.get(DebugMatchBuffer.KEY_RECORDED_AT), "2026-07-27T12:00:00")
	var stored_journal: Dictionary = entry.get(DebugMatchBuffer.KEY_JOURNAL, {})
	assert_eq(stored_journal.get(GameplayJournal.KEY_MATCH_ID), "match_abc")
	assert_eq(int(stored_journal.get(GameplayJournal.KEY_RNG_SEED, 0)), 42)
	var stored_summary: Dictionary = entry.get(DebugMatchBuffer.KEY_SUMMARY, {})
	assert_eq(stored_summary.get("schema_version"), 1)


func test_null_journal_is_noop() -> void:
	var buffer := DebugMatchBuffer.new(2)
	var evicted := buffer.push_journal(null)
	assert_true(evicted.is_empty())
	assert_true(buffer.is_empty())
