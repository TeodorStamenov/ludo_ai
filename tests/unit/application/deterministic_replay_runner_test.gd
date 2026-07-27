extends TestCase
## Business-critical тестове за DeterministicReplayRunner (Task #137 /
## docs/V1_ARCHITECTURE.md §12 / §16.3).
##
## Инвариант: еднакъв seed + еднакви accepted commands → еднакъв state hash.
## Replay игнорира reject entries; сравнява записаните state_hash (#136).


func _make_valid_config(seed_val: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = seed_val
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	cfg.seats[0].configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.seats[1].configure(
			MatchConfig.ControllerType.AI, AnimalId.RABBIT, AIDifficulty.EASY)
	return cfg


func _record_live_journal(seed_val: int = 42) -> Dictionary:
	## Играе StartMatch + RollDice през реален GameEngine; връща journal + hash.
	MatchId._reset_counter_for_tests()
	var cfg := _make_valid_config(seed_val)
	var session := MatchFactory.new().create(cfg)
	session.events_presented(session.get_pending_sequence())
	var active_id: StringName = session.get_state().get_active_player_id()
	session.receive_command(RollDiceCommand.new(active_id))
	session.events_presented(session.get_pending_sequence())
	return {
		"journal": session.get_journal(),
		"final_hash": session.get_state().compute_hash(),
		"state": session.get_state(),
	}


func test_replay_matches_live_session_state_hash() -> void:
	## §16.3 / #137: replay със същите seed и команди → същият state hash.
	var live := _record_live_journal(777)
	var journal: GameplayJournal = live["journal"]
	var result := DeterministicReplayRunner.new().run(journal)

	assert_true(result[DeterministicReplayRunner.KEY_OK],
			str(result.get(DeterministicReplayRunner.KEY_ERROR, "")))
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_FINAL_HASH]),
			int(live["final_hash"]),
			"replay final hash must equal live MatchSession hash")
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_DIVERGED_AT]),
			DeterministicReplayRunner.DIVERGED_NONE)
	assert_eq(int(result[DeterministicReplayRunner.KEY_COMMANDS_APPLIED]), 2,
			"StartMatch + RollDice")


func test_replay_is_idempotent_for_same_journal() -> void:
	var live := _record_live_journal(99)
	var journal: GameplayJournal = live["journal"]
	var runner := DeterministicReplayRunner.new()
	var a := runner.run(journal)
	var b := runner.run(journal)
	assert_true(a[DeterministicReplayRunner.KEY_OK])
	assert_true(b[DeterministicReplayRunner.KEY_OK])
	assert_eq(
			a[DeterministicReplayRunner.KEY_FINAL_HASH],
			b[DeterministicReplayRunner.KEY_FINAL_HASH])
	assert_eq(
			a[DeterministicReplayRunner.KEY_HASHES],
			b[DeterministicReplayRunner.KEY_HASHES])


func test_replay_ignores_rejected_commands() -> void:
	## Reject entries не влизат в accepted sequence — replay ги пропуска.
	MatchId._reset_counter_for_tests()
	var cfg := _make_valid_config(11)
	var session := MatchFactory.new().create(cfg)
	session.events_presented(session.get_pending_sequence())
	# Невалиден играч → reject; journal го пази, но replay не го прилага.
	session.receive_command(RollDiceCommand.new(&"yellow"))
	var active_id: StringName = session.get_state().get_active_player_id()
	session.receive_command(RollDiceCommand.new(active_id))
	session.events_presented(session.get_pending_sequence())

	var journal := session.get_journal()
	assert_true(journal.entry_count() > journal.get_accepted_commands().size(),
			"journal must contain reject noise beyond accepted commands")

	var result := DeterministicReplayRunner.new().run(journal)
	assert_true(result[DeterministicReplayRunner.KEY_OK],
			str(result.get(DeterministicReplayRunner.KEY_ERROR, "")))
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_FINAL_HASH]),
			session.get_state().compute_hash())


func test_replay_detects_state_hash_divergence() -> void:
	var live := _record_live_journal(55)
	var journal: GameplayJournal = live["journal"]
	var data := journal.to_dict()
	var raw_entries: Array = data["entries"]
	for item in raw_entries:
		if item is Dictionary and str(item.get("kind", "")) == String(GameplayJournal.KIND_STATE_HASH):
			(item as Dictionary)["hash"] = "0"
			break
	var tampered := GameplayJournal.from_dict(data)
	assert_not_null(tampered)

	var result := DeterministicReplayRunner.new().run(tampered, true)
	assert_false(result[DeterministicReplayRunner.KEY_OK])
	assert_eq(int(result[DeterministicReplayRunner.KEY_DIVERGED_AT]), 1)
	assert_true(str(result[DeterministicReplayRunner.KEY_ERROR]).contains("divergence"))


func test_replay_from_json_round_trip() -> void:
	var live := _record_live_journal(123)
	var journal: GameplayJournal = live["journal"]
	var result := DeterministicReplayRunner.new().run_json(journal.to_json())
	assert_true(result[DeterministicReplayRunner.KEY_OK],
			str(result.get(DeterministicReplayRunner.KEY_ERROR, "")))
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_FINAL_HASH]),
			int(live["final_hash"]))


func test_run_rejects_journal_without_start_match() -> void:
	var journal := GameplayJournal.new()
	journal.begin(&"m_100_1")
	journal.record_header(_make_valid_config(1), 1)
	journal.record_accepted_command(
			RollDiceCommand.create_for_player(&"green", &"m_100_1", 1))
	var result := DeterministicReplayRunner.new().run(journal, false)
	assert_false(result[DeterministicReplayRunner.KEY_OK])
	assert_true(str(result[DeterministicReplayRunner.KEY_ERROR]).contains("StartMatchCommand"))


func test_get_recorded_state_hashes_excludes_commands() -> void:
	var live := _record_live_journal(3)
	var journal: GameplayJournal = live["journal"]
	var hashes := journal.get_recorded_state_hashes()
	assert_eq(hashes.size(), journal.get_accepted_commands().size())
	assert_eq(int(hashes[0]["sequence"]), 1)
	assert_false(str(hashes[0]["hash"]).is_empty())
