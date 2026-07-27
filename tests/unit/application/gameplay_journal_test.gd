extends TestCase
## Business-critical тестове за GameplayJournal (Task #132 /
## docs/V1_ARCHITECTURE.md §11 / §12 / §16.3).
##
## Инварианти: append-only ред; accepted commands за replay без reject/hash шум;
## command_from_dict диспеч; round-trip без загуба; MatchSession притежава journal.


func _make_config() -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 42
	cfg.add_seat(&"green", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"yellow", MatchConfig.ControllerType.AI, &"rabbit")
	return cfg


func test_begin_sets_match_id_and_clears_entries() -> void:
	var journal := GameplayJournal.new()
	journal.record_accepted_command(RollDiceCommand.new(&"green"))
	journal.begin(&"m_100_1")
	assert_eq(journal.match_id, &"m_100_1")
	assert_eq(journal.entry_count(), 0)
	assert_true(journal.is_valid())


func test_entries_preserve_append_order() -> void:
	var journal := GameplayJournal.new()
	journal.begin(&"m_100_2")
	var roll := RollDiceCommand.create_for_player(&"green", &"m_100_2", 1)
	var move := MovePawnCommand.create_for_pawn(&"green", &"green_0", &"m_100_2", 2)
	journal.record_accepted_command(roll)
	journal.record_state_hash(1, 111)
	journal.record_rejected_command(move, "illegal_move")
	journal.record_accepted_command(move)
	journal.record_state_hash(2, 222)

	var entries := journal.get_entries()
	assert_eq(entries.size(), 5)
	assert_eq(StringName(str(entries[0]["kind"])), GameplayJournal.KIND_ACCEPTED_COMMAND)
	assert_eq(StringName(str(entries[1]["kind"])), GameplayJournal.KIND_STATE_HASH)
	assert_eq(StringName(str(entries[2]["kind"])), GameplayJournal.KIND_REJECTED_COMMAND)
	assert_eq(StringName(str(entries[3]["kind"])), GameplayJournal.KIND_ACCEPTED_COMMAND)
	assert_eq(StringName(str(entries[4]["kind"])), GameplayJournal.KIND_STATE_HASH)


func test_get_accepted_commands_excludes_rejects_and_hashes() -> void:
	## Replay чете само приети команди — reject/hash не влизат в поредицата.
	var journal := GameplayJournal.new()
	journal.begin(&"m_100_3")
	var roll := RollDiceCommand.create_for_player(&"green", &"m_100_3", 1)
	var bad := MovePawnCommand.create_for_pawn(&"green", &"green_0", &"m_100_3", 2)
	var move := MovePawnCommand.create_for_pawn(&"green", &"green_1", &"m_100_3", 2)
	journal.record_accepted_command(roll)
	journal.record_state_hash(1, 99)
	journal.record_rejected_command(bad, "not_your_turn")
	journal.record_accepted_command(move)

	var accepted := journal.get_accepted_commands()
	assert_eq(accepted.size(), 2)
	assert_true(accepted[0] is RollDiceCommand)
	assert_true(accepted[1] is MovePawnCommand)
	assert_eq(accepted[1].sequence, 2)
	assert_eq((accepted[1] as MovePawnCommand).pawn_id, &"green_1")


func test_command_from_dict_dispatches_subclasses() -> void:
	var start_data := StartMatchCommand.new(_make_config()).to_dict()
	var roll_data := RollDiceCommand.new(&"green").to_dict()
	var move_data := MovePawnCommand.new(&"green", &"green_0").to_dict()

	assert_true(GameplayJournal.command_from_dict(start_data) is StartMatchCommand)
	assert_true(GameplayJournal.command_from_dict(roll_data) is RollDiceCommand)
	var restored_move := GameplayJournal.command_from_dict(move_data)
	assert_true(restored_move is MovePawnCommand)
	assert_eq((restored_move as MovePawnCommand).pawn_id, &"green_0")


func test_round_trip_preserves_replay_payload() -> void:
	var journal := GameplayJournal.new()
	journal.begin(&"m_100_4")
	journal.record_header(_make_config(), 42, GameplayJournal.CONTENT_VERSION)
	journal.record_accepted_command(
			RollDiceCommand.create_for_player(&"green", &"m_100_4", 1))
	journal.record_state_hash(1, 9876543210)
	journal.record_rejected_command(
			MovePawnCommand.create_for_pawn(&"green", &"green_0", &"m_100_4", 2),
			"illegal_move")

	var restored := GameplayJournal.from_dict(journal.to_dict())
	assert_not_null(restored)
	assert_true(restored.is_valid())
	assert_eq(restored.match_id, &"m_100_4")
	assert_eq(restored.rng_seed, 42)
	assert_eq(restored.content_version, GameplayJournal.CONTENT_VERSION)
	assert_false(restored.match_config.is_empty())
	assert_eq(restored.entry_count(), 3)

	var accepted := restored.get_accepted_commands()
	assert_eq(accepted.size(), 1)
	assert_true(accepted[0] is RollDiceCommand)
	assert_eq(accepted[0].sequence, 1)

	var entries := restored.get_entries()
	assert_eq(str(entries[1]["hash"]), "9876543210")
	assert_eq(str(entries[2]["reason"]), "illegal_move")


func test_json_round_trip() -> void:
	var journal := GameplayJournal.new()
	journal.begin(&"m_100_5")
	journal.record_accepted_command(
			RollDiceCommand.create_for_player(&"yellow", &"m_100_5", 1))
	var restored := GameplayJournal.from_json(journal.to_json())
	assert_not_null(restored)
	assert_eq(restored.match_id, &"m_100_5")
	assert_eq(restored.get_accepted_commands().size(), 1)


func test_from_dict_rejects_unknown_schema() -> void:
	var data := {
		"schema_version": GameplayJournal.SCHEMA_VERSION + 1,
		"match_id": "m_1_0",
		"entries": [],
	}
	assert_null(GameplayJournal.from_dict(data))


func test_from_dict_rejects_unknown_entry_kind() -> void:
	var data := {
		"schema_version": GameplayJournal.SCHEMA_VERSION,
		"match_id": "m_100_6",
		"match_config": {},
		"rng_seed": 0,
		"content_version": "",
		"entries": [{"kind": "unknown", "command": {"command_type": "RollDice"}}],
	}
	assert_null(GameplayJournal.from_dict(data),
			"unknown entry kind must fail journal validation")


func test_match_session_owns_journal_after_start() -> void:
	var state := GameState.new()
	state.match_id = &"m_200_1"
	var session := MatchSession.new()
	var cfg := _make_config()
	var engine := GameEngine.new()
	# Stub apply за да не зависи тестът от пълните правила при StartMatch.
	session.start(cfg, state, _AcceptEngine.new(), SeededRandomSource.new(1), {}, EventQueue.new())
	var journal := session.get_journal()
	assert_not_null(journal, "MatchSession must own a GameplayJournal after start")
	assert_eq(journal.match_id, &"m_200_1")
	assert_true(journal.is_valid())


class _AcceptEngine extends GameEngine:
	func apply_command(state: GameState, command: GameCommand, _rng: RandomSource) -> Dictionary:
		if state != null and command != null:
			state.record_accepted_command(command.sequence)
		return {
			"accepted": true,
			"state": state,
			"events": [],
			"error": null,
		}

	func get_legal_actions(_state: GameState) -> Array:
		return []
