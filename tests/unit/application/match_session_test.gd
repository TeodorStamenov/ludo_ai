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
	var captured := {"finished": false}
	session.match_finished.connect(func(_summary): captured.finished = true)
	(parts["engine"] as StubEngine).set_next_events([finish_event])
	session.start(_make_config(), parts["state"], parts["engine"], parts["rng"],
			parts["controllers"], parts["event_queue"])

	assert_true(captured.finished, "match_finished signal must fire when MatchFinished event is present")
	assert_false(session.is_active(), "session must be inactive after MatchFinished")


func test_session_active_before_match_finished() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	assert_true(session.is_active())


func test_snapshot_contains_required_keys() -> void:
	var parts := _make_parts()
	var session := _start(parts)
	var snap := session.to_snapshot()
	assert_true("command_sequence" in snap, "snapshot must have command_sequence")
	assert_true("rng_state" in snap, "snapshot must have rng_state")
	assert_true("state" in snap, "snapshot must have state")


func test_event_queue_populated_after_command() -> void:
	var parts := _make_parts()
	var e := DomainEvent.new()
	e.event_type = &"DiceRolled"
	var session := _start(parts, [e])
	var queue: EventQueue = session.get_event_queue()
	assert_false(queue.is_empty(), "EventQueue must contain events after command")
