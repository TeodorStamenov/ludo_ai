extends TestCase
## Unit тестове за MatchSession с stub GameEngine и GameState.
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
	assert_eq(session.get_state().compute_hash(),
			int(snap[MatchSession.SNAPSHOT_KEY_STATE_HASH]),
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
