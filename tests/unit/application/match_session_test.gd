extends TestCase
## Business-critical тестове за MatchSession (Task #131 /
## docs/V1_ARCHITECTURE.md §5.2 / §9 / §12).
##
## Инварианти: команди през session; events_published + presentation gate;
## rejected не пипа state/RNG; AI auto-submit след events_presented;
## MatchFinished → MatchSummary; snapshot/restore без загуба.
##
## StubEngine — приема всяка команда и връща предварително зададени events.
## StubState  — минимален GameState stub.


class StubState extends GameState:
	var _active_id: StringName = &"p1"

	func get_active_player_id() -> StringName:
		return _active_id

	func to_view() -> Dictionary:
		return {"active_player_id": _active_id}

	func get_legal_actions() -> Array:
		return [RollDiceCommand.new(_active_id)]

	func to_dict() -> Dictionary:
		return {}

	## Orchestration stub — не е пълен GameState; §12 board checks са N/A.
	func is_valid() -> bool:
		return true

	func is_in_progress() -> bool:
		return false

	func compute_hash() -> int:
		return 0


class StubEngine extends GameEngine:
	var _events_to_return: Array = []
	var last_command: GameCommand = null
	var call_count: int = 0

	func set_next_events(events: Array) -> void:
		_events_to_return = events

	func apply_command(state: GameState, command: GameCommand, _rng: RandomSource) -> Dictionary:
		last_command = command
		call_count += 1
		return {
			"accepted": true,
			"state": state,
			"events": _events_to_return.duplicate(),
			"error": null,
		}

	func get_legal_actions(state: GameState) -> Array:
		if state == null:
			return []
		return state.get_legal_actions()


class RejectEngine extends GameEngine:
	func apply_command(state: GameState, command: GameCommand, _rng: RandomSource) -> Dictionary:
		return {
			"accepted": false,
			"state": state,
			"events": [],
			"error": "illegal_move",
		}


class SpyTelemetrySink extends TelemetrySink:
	var finished_count: int = 0
	var last_summary: Dictionary = {}
	var violation_count: int = 0

	func record_match_finished(summary: Dictionary) -> void:
		finished_count += 1
		last_summary = summary.duplicate(true)

	func record_invariant_violation(
			_match_id: StringName,
			_description: String,
			_snapshot: Dictionary = {}
	) -> void:
		violation_count += 1


func _make_parts() -> Dictionary:
	var state := StubState.new()
	var engine := StubEngine.new()
	var rng := SeededRandomSource.new(42)
	var event_queue := EventQueue.new()
	var ai_policy := EasyAIPolicy.new()
	var ai_ctrl := AIController.new(&"p2", ai_policy)
	var human_ctrl := HumanController.new(&"p1")
	var controllers: Dictionary = {&"p1": human_ctrl, &"p2": ai_ctrl}
	return {
		"state": state,
		"engine": engine,
		"rng": rng,
		"event_queue": event_queue,
		"controllers": controllers,
		"human": human_ctrl,
		"ai": ai_ctrl,
	}


func _make_config() -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 42
	cfg.add_seat(&"p1", MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(&"p2", MatchConfig.ControllerType.AI, &"rabbit")
	return cfg


func _start(parts: Dictionary, events: Array = []) -> MatchSession:
	var engine: StubEngine = parts["engine"]
	engine.set_next_events(events)
	var session := MatchSession.new()
	session.start(_make_config(), parts["state"], engine, parts["rng"],
			parts["controllers"], parts["event_queue"])
	return session


func test_start_applies_start_match_command() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	var engine: StubEngine = parts["engine"]
	assert_true(engine.call_count >= 1, "Engine must be called at start")
	assert_true(engine.last_command is StartMatchCommand,
			"First command must be StartMatchCommand")


func test_events_published_signal_emitted() -> void:
	var parts := _make_parts()
	var captured := {"seq": -1, "events": []}
	var session := MatchSession.new()
	session.events_published.connect(func(seq, evts):
		captured.seq = seq
		captured.events = evts
	)
	var e := DomainEvent.new()
	e.event_type = &"MatchStarted"
	(parts["engine"] as StubEngine).set_next_events([e])
	session.start(_make_config(), parts["state"], parts["engine"], parts["rng"],
			parts["controllers"], parts["event_queue"])

	assert_eq(captured.seq, 1, "First sequence must be 1")
	assert_eq(captured.events.size(), 1)
	assert_eq((captured.events[0] as DomainEvent).event_type, &"MatchStarted")


func test_receive_command_blocked_while_pending() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	var engine: StubEngine = parts["engine"]
	var count_before := engine.call_count

	session.receive_command(RollDiceCommand.new(&"p1"))

	assert_eq(engine.call_count, count_before,
			"receive_command must be blocked while presentation is pending")


func test_events_presented_clears_block() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	var engine: StubEngine = parts["engine"]

	session.events_presented(1)

	var awaiting_fired := false
	session.awaiting_human_action.connect(func(_id, _sv, _la): awaiting_fired = true)

	engine.set_next_events([])
	session.receive_command(RollDiceCommand.new(&"p1"))

	assert_eq(engine.call_count, 2,
			"Engine must be called after events_presented unblocks session")


func test_human_turn_signal_emitted_after_advance() -> void:
	var parts := _make_parts()
	var captured := {"pid": &""}
	var session := MatchSession.new()
	session.awaiting_human_action.connect(func(pid, _sv, _la): captured.pid = pid)
	(parts["engine"] as StubEngine).set_next_events([])
	session.start(_make_config(), parts["state"], parts["engine"], parts["rng"],
			parts["controllers"], parts["event_queue"])

	session.events_presented(1)

	assert_eq(captured.pid, &"p1",
			"awaiting_human_action must fire with active human player_id")


func test_match_finished_signal_on_match_finished_event() -> void:
	var parts := _make_parts()
	var finish_event := DomainEvent.new()
	finish_event.event_type = &"MatchFinished"
	var session := MatchSession.new()
	var captured := {"finished": false, "summary": {}}
	session.match_finished.connect(func(summary):
		captured.finished = true
		captured.summary = summary
	)
	(parts["engine"] as StubEngine).set_next_events([finish_event])
	session.start(_make_config(), parts["state"], parts["engine"], parts["rng"],
			parts["controllers"], parts["event_queue"])

	assert_true(captured.finished, "match_finished signal must fire when MatchFinished event is present")
	assert_false(session.is_active(), "session must be inactive after MatchFinished")
	assert_true(captured.summary.has("ranking"), "MatchSummary must include ranking")
	assert_true(captured.summary.has("match_id"), "MatchSummary must include match_id")
	assert_true(captured.summary.has("schema_version"), "MatchSummary must include schema_version")
	assert_true(captured.summary.has(MatchSummary.KEY_COMMAND_SEQUENCE),
			"MatchSummary must include command_sequence")


func test_match_finished_records_summary_via_telemetry() -> void:
	var parts := _make_parts()
	var finish_event := DomainEvent.new()
	finish_event.event_type = &"MatchFinished"
	var session := MatchSession.new()
	var spy := SpyTelemetrySink.new()
	session.set_telemetry_sink(spy)
	(parts["engine"] as StubEngine).set_next_events([finish_event])
	session.start(_make_config(), parts["state"], parts["engine"], parts["rng"],
			parts["controllers"], parts["event_queue"])

	assert_eq(spy.finished_count, 1, "normal finish must record MatchSummary once")
	assert_false(spy.last_summary.is_empty(), "recorded summary must be non-empty")
	assert_true(spy.last_summary.has(MatchSummary.KEY_RANKING))
	assert_true(spy.last_summary.has(MatchSummary.KEY_COMMAND_SEQUENCE))


func test_match_finished_archives_journal_into_debug_match_buffer() -> void:
	var parts := _make_parts()
	var finish_event := DomainEvent.new()
	finish_event.event_type = &"MatchFinished"
	var session := MatchSession.new()
	var buffer := DebugMatchBuffer.new(3)
	session.set_debug_match_buffer(buffer)
	(parts["engine"] as StubEngine).set_next_events([finish_event])
	session.start(_make_config(), parts["state"], parts["engine"], parts["rng"],
			parts["controllers"], parts["event_queue"])

	assert_eq(buffer.size(), 1, "finished match must archive one debug entry")
	var entry := buffer.get_latest()
	assert_true(DebugMatchBuffer.is_valid_entry(entry))
	var journal_dict: Dictionary = entry.get(DebugMatchBuffer.KEY_JOURNAL, {})
	assert_true(journal_dict.has(GameplayJournal.KEY_ENTRIES),
			"archived journal must include entries")
	assert_false(entry.get(DebugMatchBuffer.KEY_SUMMARY, {}).is_empty(),
			"archived entry should include MatchSummary")


func test_session_active_before_match_finished() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	assert_true(session.is_active())


func test_snapshot_contains_required_keys() -> void:
	var session := _start_with_real_state()
	var snap := session.to_snapshot()
	assert_true(snap.has(MatchSession.SNAPSHOT_KEY_SCHEMA_VERSION),
			"snapshot must have schema_version")
	assert_true(snap.has(MatchSession.SNAPSHOT_KEY_MATCH_ID),
			"snapshot must have match_id")
	assert_true(snap.has(MatchSession.SNAPSHOT_KEY_STATE),
			"snapshot must have state")
	assert_true(snap.has(MatchSession.SNAPSHOT_KEY_RNG_STATE),
			"snapshot must have rng_state")
	assert_true(snap.has(MatchSession.SNAPSHOT_KEY_COMMAND_SEQUENCE),
			"snapshot must have command_sequence")
	assert_true(snap.has(MatchSession.SNAPSHOT_KEY_STATE_HASH),
			"snapshot must have state_hash")
	assert_eq(int(snap[MatchSession.SNAPSHOT_KEY_SCHEMA_VERSION]),
			MatchSession.SNAPSHOT_SCHEMA_VERSION)


func test_snapshot_state_round_trip_preserves_hash() -> void:
	## Критичен инвариант за resume (#130): state в snapshot → from_dict без загуба.
	var session := _start_with_real_state()
	var snap := session.to_snapshot()
	assert_true(MatchSession.is_snapshot_valid(snap),
			"fresh to_snapshot() must be valid")
	var restored := GameState.from_dict(snap[MatchSession.SNAPSHOT_KEY_STATE])
	assert_true(session.get_state().equals(restored),
			"snapshot state must round-trip without loss")
	assert_eq(str(session.get_state().compute_hash()),
			str(snap[MatchSession.SNAPSHOT_KEY_STATE_HASH]),
			"state_hash must match live GameState")
	assert_eq(session.get_state().command_sequence,
			int(snap[MatchSession.SNAPSHOT_KEY_COMMAND_SEQUENCE]))
	assert_eq(String(session.get_state().match_id),
			str(snap[MatchSession.SNAPSHOT_KEY_MATCH_ID]))


func test_snapshot_rng_matches_live_rng() -> void:
	var session := _start_with_real_state()
	var snap := session.to_snapshot()
	var live_rng := session.get_rng().get_state()
	var snap_rng: Dictionary = snap[MatchSession.SNAPSHOT_KEY_RNG_STATE]
	assert_eq(str(snap_rng.get("seed", "")), str(live_rng.get("seed", "")),
			"snapshot rng seed must match live RNG")
	assert_eq(str(snap_rng.get("state", "")), str(live_rng.get("state", "")),
			"snapshot rng state must match live RNG")


func test_last_stable_snapshot_updated_after_events_presented() -> void:
	var session := _start_with_real_state()
	assert_true(session.get_last_stable_snapshot().is_empty(),
			"no stable snapshot while presentation is pending")
	session.events_presented(session.get_pending_sequence())
	var stable := session.get_last_stable_snapshot()
	assert_false(stable.is_empty(),
			"events_presented must capture last stable snapshot")
	assert_true(MatchSession.is_snapshot_valid(stable),
			"stable snapshot must be valid payload")
	assert_eq(int(stable[MatchSession.SNAPSHOT_KEY_COMMAND_SEQUENCE]),
			session.get_state().command_sequence)


func test_is_snapshot_valid_rejects_incomplete_payload() -> void:
	assert_false(MatchSession.is_snapshot_valid({}),
			"empty dict is invalid")
	assert_false(MatchSession.is_snapshot_valid({
		MatchSession.SNAPSHOT_KEY_SCHEMA_VERSION: MatchSession.SNAPSHOT_SCHEMA_VERSION,
		MatchSession.SNAPSHOT_KEY_STATE: {},
	}), "empty nested state is invalid")
	var session := _start_with_real_state()
	var snap := session.to_snapshot()
	snap[MatchSession.SNAPSHOT_KEY_COMMAND_SEQUENCE] = (
			int(snap[MatchSession.SNAPSHOT_KEY_COMMAND_SEQUENCE]) + 99)
	assert_false(MatchSession.is_snapshot_valid(snap),
			"diverged command_sequence must invalidate snapshot")


func test_restore_from_snapshot_preserves_state_hash_and_rng() -> void:
	## Критичен инвариант (#130 / §9 / §16.2): snapshot → restore без загуба.
	var live := _start_real_match_stable()
	var snap := live.to_snapshot()
	var hash_before := live.get_state().compute_hash()
	var seq_before := live.get_state().command_sequence
	var rng_before: Dictionary = live.get_rng().get_state().duplicate(true)
	var match_id_before := live.get_state().match_id

	var restored := MatchFactory.new().create_from_snapshot(snap)
	assert_not_null(restored, "create_from_snapshot must accept valid payload")
	assert_true(restored.is_active(), "IN_PROGRESS match stays active after restore")
	assert_false(restored.is_presentation_pending(),
			"restore lands in stable phase")
	assert_true(live.get_state().equals(restored.get_state()),
			"restored GameState must equal live state")
	assert_eq(hash_before, restored.get_state().compute_hash())
	assert_eq(seq_before, restored.get_state().command_sequence)
	assert_eq(match_id_before, restored.get_state().match_id)
	var rng_after: Dictionary = restored.get_rng().get_state()
	assert_eq(str(rng_before.get("seed", "")), str(rng_after.get("seed", "")))
	assert_eq(str(rng_before.get("state", "")), str(rng_after.get("state", "")))
	assert_true(MatchSession.is_snapshot_valid(restored.get_last_stable_snapshot()),
			"restore must seed last_stable_snapshot")


func test_restore_from_snapshot_rejects_invalid_without_mutation() -> void:
	var session := MatchSession.new()
	assert_false(session.restore_from_snapshot({}),
			"empty snapshot must be rejected")
	assert_false(session.is_active())
	assert_true(session.get_state() == null,
			"failed restore must not bind GameState")
	assert_true(MatchFactory.new().create_from_snapshot({}) == null,
			"factory must return null for invalid snapshot")


func test_restore_from_snapshot_continues_accepting_commands() -> void:
	## Resume: следващата команда се приема със същия sequence timeline.
	var live := _start_real_match_stable()
	var snap := live.to_snapshot()
	var restored := MatchFactory.new().create_from_snapshot(snap)
	assert_not_null(restored)
	var seq_before := restored.get_state().command_sequence
	var active_id := restored.get_state().get_active_player_id()
	assert_false(active_id.is_empty())

	restored.receive_command(RollDiceCommand.new(active_id))
	assert_true(restored.is_presentation_pending(),
			"roll after restore must be accepted")
	assert_eq(restored.get_state().command_sequence, seq_before + 1,
			"command_sequence must advance from restored baseline")


func test_restore_from_snapshot_json_round_trip() -> void:
	var live := _start_real_match_stable()
	var json_text := live.to_snapshot_json()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary)
	assert_true(MatchSession.is_snapshot_valid(parsed as Dictionary),
			"JSON round-trip must keep snapshot valid (string state_hash)")

	var blank := MatchSession.new()
	assert_false(blank.restore_from_snapshot_json("{"),
			"malformed JSON must fail")
	assert_false(blank.restore_from_snapshot_json("{}"),
			"empty JSON object must fail validation")

	var restored := MatchFactory.new().create_from_snapshot(parsed as Dictionary)
	assert_not_null(restored)
	assert_true(live.get_state().equals(restored.get_state()))
	assert_eq(
			str(live.get_state().compute_hash()),
			str(restored.to_snapshot()[MatchSession.SNAPSHOT_KEY_STATE_HASH]))


func _start_real_match_stable() -> MatchSession:
	MatchId._reset_counter_for_tests()
	var session := MatchFactory.new().create(_make_valid_two_player_config())
	assert_true(session.is_presentation_pending())
	session.events_presented(session.get_pending_sequence())
	assert_false(session.is_presentation_pending())
	assert_true(session.is_active())
	return session


func _start_with_real_state() -> MatchSession:
	MatchId._reset_counter_for_tests()
	var config := _make_valid_two_player_config()
	var state := GameState.create_from_match_config(config)
	var rng := SeededRandomSource.new(config.rng_seed)
	var engine := StubEngine.new()
	engine.set_next_events([])
	var p1: StringName = config.seats[0].player_id
	var p2: StringName = config.seats[1].player_id
	var controllers: Dictionary = {
		p1: HumanController.new(p1),
		p2: AIController.new(p2, EasyAIPolicy.new()),
	}
	var session := MatchSession.new()
	session.start(config, state, engine, rng, controllers, EventQueue.new())
	return session


func _make_valid_two_player_config() -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 42
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	cfg.seats[0].configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	cfg.seats[1].configure(
			MatchConfig.ControllerType.AI, AnimalId.RABBIT, AIDifficulty.EASY)
	return cfg


func test_event_queue_populated_after_command() -> void:
	var parts := _make_parts()
	var e := DomainEvent.new()
	e.event_type = &"DiceRolled"
	var session := _start(parts, [e])
	var queue: EventQueue = session.get_event_queue()
	assert_false(queue.is_empty(), "EventQueue must contain events after command")


func test_events_presented_acknowledges_event_queue() -> void:
	var parts := _make_parts()
	var e := DomainEvent.new()
	e.event_type = &"DiceRolled"
	var session := _start(parts, [e])
	var queue: EventQueue = session.get_event_queue()
	assert_false(queue.is_empty(), "queue must hold events while presentation pending")
	var pending := session.get_pending_sequence()
	session.events_presented(pending)
	assert_true(queue.is_empty(),
			"events_presented must acknowledge/clear the presented sequence")


func test_command_bus_bound_and_forwards_submit() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	var bus: CommandBus = session.get_command_bus()
	assert_not_null(bus, "MatchSession must expose CommandBus")
	assert_true(bus.is_bound(), "CommandBus must be bound after start")

	session.events_presented(1)
	var engine: StubEngine = parts["engine"]
	engine.set_next_events([])
	var count_before := engine.call_count

	assert_true(bus.submit(RollDiceCommand.new(&"p1")),
			"CommandBus.submit must forward when session accepts commands")
	assert_eq(engine.call_count, count_before + 1,
			"submit must reach GameEngine through MatchSession")


func test_human_action_ready_routes_through_command_bus() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	session.events_presented(1)

	var engine: StubEngine = parts["engine"]
	engine.set_next_events([])
	var count_before := engine.call_count
	var human: HumanController = parts["human"]
	human.notify_turn([RollDiceCommand.new(&"p1")])
	human.submit_roll()

	assert_eq(engine.call_count, count_before + 1,
			"HumanController.action_ready must reach engine via CommandBus")
	assert_true(engine.last_command is RollDiceCommand,
			"Last command must be RollDiceCommand from human submit_roll")


func test_command_bus_forwards_rejection() -> void:
	var parts := _make_parts()
	var reject_engine := RejectEngine.new()
	var session := MatchSession.new()
	session.start(_make_config(), parts["state"], reject_engine, parts["rng"],
			parts["controllers"], parts["event_queue"])
	var bus: CommandBus = session.get_command_bus()
	var captured := {"cmd": null, "reason": ""}
	bus.command_rejected.connect(func(cmd, reason):
		captured.cmd = cmd
		captured.reason = reason
	)
	bus.submit(RollDiceCommand.new(&"p1"))

	assert_not_null(captured.cmd, "CommandBus must forward command_rejected")
	assert_eq(str(captured.reason), "illegal_move",
			"Rejection reason must be forwarded unchanged")


func test_rejected_command_does_not_mutate_state_or_rng() -> void:
	## §12: невалидна команда не променя state или RNG.
	var session := _start_real_match_stable()
	var hash_before := session.get_state().compute_hash()
	var seq_before := session.get_state().command_sequence
	var rng_before: Dictionary = session.get_rng().get_state().duplicate(true)
	var active_id := session.get_state().get_active_player_id()
	var pawn := session.get_state().get_active_player().get_pawn_by_index(0)
	assert_not_null(pawn)

	var rejected := {"fired": false}
	session.command_rejected.connect(func(_cmd, _reason): rejected.fired = true)
	session.receive_command(MovePawnCommand.create_for_pawn(active_id, pawn.pawn_id))

	assert_true(rejected.fired, "illegal MovePawn while AWAITING_ROLL must reject")
	assert_eq(hash_before, session.get_state().compute_hash(),
			"rejected command must not change GameState hash")
	assert_eq(seq_before, session.get_state().command_sequence,
			"rejected command must not advance command_sequence")
	var rng_after: Dictionary = session.get_rng().get_state()
	assert_eq(str(rng_before.get("seed", "")), str(rng_after.get("seed", "")))
	assert_eq(str(rng_before.get("state", "")), str(rng_after.get("state", "")),
			"rejected command must not advance RNG")
	assert_false(session.is_presentation_pending(),
			"rejection must not open a presentation gate")
	assert_true(session.is_active())


func test_ai_turn_auto_submits_after_events_presented() -> void:
	## §5.2 / §5.3: след events_presented autonomous controller подава команда.
	var parts := _make_parts()
	(parts["state"] as StubState)._active_id = &"p2"
	var session := _start(parts)
	var engine: StubEngine = parts["engine"]
	var count_before := engine.call_count
	engine.set_next_events([])

	session.events_presented(session.get_pending_sequence())

	assert_eq(engine.call_count, count_before + 1,
			"AI turn must auto-submit through CommandBus after events_presented")
	assert_true(engine.last_command is RollDiceCommand,
			"AI must choose a legal RollDiceCommand")
	assert_eq((engine.last_command as GameCommand).player_id, &"p2")


func test_inactive_session_ignores_commands_after_match_finished() -> void:
	var parts := _make_parts()
	var finish_event := DomainEvent.new()
	finish_event.event_type = DomainEvent.TYPE_MATCH_FINISHED
	var session := _start(parts, [finish_event])
	assert_false(session.is_active())
	var engine: StubEngine = parts["engine"]
	var count_before := engine.call_count

	session.receive_command(RollDiceCommand.new(&"p1"))

	assert_eq(engine.call_count, count_before,
			"inactive MatchSession must drop commands after MatchFinished")


func test_events_presented_ignores_mismatched_sequence() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	var pending := session.get_pending_sequence()
	assert_true(pending >= 0)

	session.events_presented(pending + 99)

	assert_true(session.is_presentation_pending(),
			"wrong sequence must leave presentation gate closed")
	assert_eq(session.get_pending_sequence(), pending)
	assert_true(session.get_last_stable_snapshot().is_empty(),
			"mismatched ack must not capture stable snapshot")


func test_real_engine_roll_dice_through_session() -> void:
	## Оркестрация с реален GameEngine: приета команда → events + gate.
	var session := _start_real_match_stable()
	var active_id := session.get_state().get_active_player_id()
	var seq_before := session.get_state().command_sequence
	var published := {"seq": -1, "count": 0}
	session.events_published.connect(func(seq, events):
		published.seq = seq
		published.count = events.size()
	)

	session.receive_command(RollDiceCommand.new(active_id))

	assert_true(session.is_presentation_pending())
	assert_eq(session.get_state().command_sequence, seq_before + 1)
	assert_true(session.get_state().turn.has_dice_result(),
			"accepted RollDice must set turn.dice_value via GameEngine")
	assert_eq(published.seq, session.get_pending_sequence())
	assert_true(published.count > 0, "accepted roll must publish domain events")
	assert_false(session.get_event_queue().is_empty())
