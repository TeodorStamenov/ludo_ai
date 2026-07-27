extends TestCase
## Симулационен тест: еднакъв state hash при replay
## (Task #138 / docs/V1_ARCHITECTURE.md §12 / §16.3).
##
## Критичен инвариант: еднакъв seed + еднакви accepted commands →
## еднакви GameState hashes (на всяка стъпка и финално).
## Live MatchSession → GameplayJournal → DeterministicReplayRunner.


const TARGET_ACCEPTED_COMMANDS := 24


func _make_config(seed_val: int) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = seed_val
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	cfg.seats[0].configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.seats[1].configure(MatchConfig.ControllerType.HUMAN, AnimalId.RABBIT)
	return cfg


func _first_legal_action(state: GameState) -> GameCommand:
	var actions: Array = GameEngine.new().get_legal_actions(state)
	if actions.is_empty():
		return null
	return actions[0] as GameCommand


func _drain_presentation(session: MatchSession) -> void:
	if session.is_presentation_pending():
		session.events_presented(session.get_pending_sequence())


## Играе до target accepted команди чрез първото legal action (детерминистичен избор).
## Връща journal + final_hash + per-step hashes от live session.
func _play_live(seed_val: int, target_accepted: int = TARGET_ACCEPTED_COMMANDS) -> Dictionary:
	MatchId._reset_counter_for_tests()
	var session := MatchFactory.new().create(_make_config(seed_val))
	_drain_presentation(session)

	var safety := 0
	while (
			session.is_active()
			and session.get_journal().get_accepted_commands().size() < target_accepted
	):
		safety += 1
		if safety > target_accepted * 8:
			break
		var action := _first_legal_action(session.get_state())
		if action == null:
			break
		session.receive_command(action)
		_drain_presentation(session)

	var step_hashes: Array[int] = []
	for entry: Dictionary in session.get_journal().get_recorded_state_hashes():
		step_hashes.append(int(str(entry.get(GameplayJournal.ENTRY_HASH, "0"))))

	return {
		"journal": session.get_journal(),
		"final_hash": session.get_state().compute_hash(),
		"step_hashes": step_hashes,
		"accepted_count": session.get_journal().get_accepted_commands().size(),
		"state": session.get_state(),
	}


func test_replay_matches_live_state_hashes_at_every_step() -> void:
	## §16.3 / #138: replay със същите seed и commands → същите state hashes.
	var live := _play_live(4242)
	var journal: GameplayJournal = live["journal"]
	assert_true(int(live["accepted_count"]) >= 8,
			"need a multi-command sequence for meaningful replay hash check")

	var result := DeterministicReplayRunner.new().run(journal, true)
	assert_true(result[DeterministicReplayRunner.KEY_OK],
			str(result.get(DeterministicReplayRunner.KEY_ERROR, "")))
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_DIVERGED_AT]),
			DeterministicReplayRunner.DIVERGED_NONE)
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_FINAL_HASH]),
			int(live["final_hash"]),
			"replay final hash must equal live MatchSession hash")
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_COMMANDS_APPLIED]),
			int(live["accepted_count"]))

	var replay_hashes: Array = result[DeterministicReplayRunner.KEY_HASHES]
	var live_hashes: Array = live["step_hashes"]
	assert_eq(replay_hashes.size(), live_hashes.size(),
			"replay must produce one hash per accepted command")
	for i in replay_hashes.size():
		assert_eq(int(replay_hashes[i]), int(live_hashes[i]),
				"state hash divergence at step %d (seq ~%d)" % [i, i + 1])


func test_replay_from_json_preserves_state_hash_equality() -> void:
	var live := _play_live(13579, 12)
	var journal: GameplayJournal = live["journal"]
	var result := DeterministicReplayRunner.new().run_json(journal.to_json(), true)
	assert_true(result[DeterministicReplayRunner.KEY_OK],
			str(result.get(DeterministicReplayRunner.KEY_ERROR, "")))
	assert_eq(
			int(result[DeterministicReplayRunner.KEY_FINAL_HASH]),
			int(live["final_hash"]))


func test_different_seeds_diverge_in_state_hash() -> void:
	var a := _play_live(1001, 12)
	var b := _play_live(1002, 12)
	assert_ne(int(a["final_hash"]), int(b["final_hash"]),
			"different seeds must produce different state hashes")
