class_name MatchSession
extends RefCounted
## Application service за управление на един активен мач
## (docs/V1_ARCHITECTURE.md, раздел 5.2).
##
## MatchSession НЕ е глобален вечен singleton. Създава се за конкретен
## мач от MatchFactory и се освобождава след Results екрана.
##
## Отговорности:
##   - притежава GameState, GameEngine, RandomSource и CommandBus;
##   - външни GameCommand-и влизат само през CommandBus.submit();
##   - публикува DomainEvent-и след приета команда (events_published сигнал);
##   - блокира следваща команда, докато Presentation потвърди
##     events_presented(sequence) — без да прехвърля правилата към анимацията;
##   - след потвърждение прогресира автоматично: задейства AI или
##     сигнализира Presentation за очакван human input;
##   - прави snapshot след стабилна фаза (за save/restore);
##   - при MatchFinished произвежда MatchSummary чрез match_finished сигнал.

signal events_published(sequence: int, events: Array)
signal match_finished(summary: Dictionary)
signal awaiting_human_action(player_id: StringName, state_view: Dictionary, legal_actions: Array)
signal command_rejected(command: GameCommand, reason: String)

var _config: MatchConfig = null
var _state: GameState = null
var _engine: GameEngine = null
var _rng: RandomSource = null
var _controllers: Dictionary = {}
var _event_queue: EventQueue = null
var _command_bus: CommandBus = null
var _pending_sequence: int = -1
var _active: bool = false
var _last_stable_snapshot: Dictionary = {}


func start(
		config: MatchConfig,
		state: GameState = null,
		engine: GameEngine = null,
		rng: RandomSource = null,
		controllers: Dictionary = {},
		event_queue: EventQueue = null
) -> void:
	assert(config != null, "MatchSession.start: config не може да е null")
	_config = config
	_state = state if state != null else GameState.create_from_match_config(config)
	_engine = engine if engine != null else GameEngine.new()
	_rng = rng if rng != null else config.create_random_source()
	_controllers = controllers
	_event_queue = event_queue if event_queue != null else EventQueue.new()
	_pending_sequence = -1
	_active = true
	_last_stable_snapshot = {}
	_setup_command_bus()
	# GameState.rng_state е source of truth (§4.1 / §4.5 / #60).
	# При mid-match restore: живият RNG ← snapshot; иначе snapshot ← жив RNG.
	_sync_rng_on_start()
	receive_command(StartMatchCommand.new(config))


func receive_command(command: GameCommand) -> void:
	if not _active:
		return
	if command == null:
		push_error("MatchSession: null command")
		return
	if _pending_sequence >= 0:
		push_warning(
				"MatchSession: command dropped — presentation pending sequence %d"
				% _pending_sequence)
		return
	if _engine == null:
		push_error("MatchSession: no GameEngine bound")
		return
	if _state == null:
		push_error("MatchSession: no GameState bound")
		return

	# GameState.command_sequence е source of truth (§4.1 / §11).
	_state.stamp_command(command)
	var result: Dictionary = _engine.apply_command(_state, command, _rng)

	if not result.get("accepted", false):
		# §12: отхвърлена команда не променя state или RNG — без capture_rng.
		command_rejected.emit(command, str(result.get("error", "rejected")))
		return

	_state = result.get("state", _state)
	# GameEngine може вече да е записал sequence; иначе го записваме тук.
	if _state.command_sequence != command.sequence:
		if not _state.record_accepted_command(command.sequence):
			push_error(
					"MatchSession: command_sequence divergence (state=%d, command=%d)"
					% [_state.command_sequence, command.sequence])
			return
	# Синхронизира GameState.rng_state след приета команда (дори ако RNG не е
	# ползван — snapshot трябва да съвпада с живия RandomSource).
	_state.capture_rng(_rng)
	var events: Array = result.get("events", [])
	_stamp_events(events, command.sequence)
	_event_queue.enqueue(events)
	_pending_sequence = _state.command_sequence
	events_published.emit(_pending_sequence, events)

	if _is_match_over(events):
		_active = false
		match_finished.emit(_build_summary())


func events_presented(sequence: int) -> void:
	if sequence != _pending_sequence:
		return
	# Presentation gate: изчиства представената поредица от EventQueue
	# (no-op ако Presenter вече е dequeue-нал / take_sequence-нал).
	if _event_queue != null:
		_event_queue.acknowledge(sequence)
	_pending_sequence = -1
	_last_stable_snapshot = to_snapshot()
	if _active:
		_advance()


func _advance() -> void:
	var active_id := _get_active_player_id()
	if active_id.is_empty():
		return
	var controller: PlayerController = _controllers.get(active_id)
	if controller == null:
		push_error("MatchSession: no controller for player '%s'" % active_id)
		return
	var state_view := _build_state_view()
	var legal := _build_legal_actions()
	if controller.is_autonomous():
		var cmd: GameCommand = controller.get_action(state_view, legal)
		if cmd != null:
			cmd.player_id = active_id
			_command_bus.submit(cmd)
	else:
		if controller is HumanController:
			(controller as HumanController).notify_turn(legal)
		awaiting_human_action.emit(active_id, state_view, legal)


func get_state() -> GameState:
	return _state


func get_config() -> MatchConfig:
	return _config


func get_event_queue() -> EventQueue:
	return _event_queue


func get_command_bus() -> CommandBus:
	return _command_bus


func get_rng() -> RandomSource:
	return _rng


func is_active() -> bool:
	return _active


func is_presentation_pending() -> bool:
	return _pending_sequence >= 0


func get_pending_sequence() -> int:
	return _pending_sequence


func get_last_stable_snapshot() -> Dictionary:
	return _last_stable_snapshot.duplicate(true)


func to_snapshot() -> Dictionary:
	# rng_state / command_sequence идват от GameState (source of truth).
	var snap_rng: Dictionary = {}
	if _state != null:
		snap_rng = _state.rng_state.duplicate(true)
	elif _rng != null:
		snap_rng = _rng.get_state()
	return {
		"schema_version": 1,
		"state": _state.to_dict() if _state != null else {},
		"rng_state": snap_rng,
		"command_sequence": (
				_state.command_sequence if _state != null
				else GameState.COMMAND_SEQUENCE_START),
	}


func _get_active_player_id() -> StringName:
	if _state == null:
		return &""
	return _state.get_active_player_id()


func _build_state_view() -> Dictionary:
	if _state == null:
		return {}
	return _state.to_view()


func _build_legal_actions() -> Array:
	if _state == null:
		return []
	return _state.get_legal_actions()


func _is_match_over(events: Array) -> bool:
	if _state != null and _state.is_finished():
		return true
	for event in events:
		if event is MatchFinishedEvent:
			return true
		if (
				event is DomainEvent
				and (event as DomainEvent).event_type == DomainEvent.TYPE_MATCH_FINISHED
		):
			return true
	return false


## MatchSummary = MatchResult.to_dict() (§5.2); command_sequence е session метаданни.
func _build_summary() -> Dictionary:
	var result := MatchResult.create_from_game_state(_state)
	var summary: Dictionary = result.to_dict()
	summary["command_sequence"] = (
			_state.command_sequence if _state != null
			else GameState.COMMAND_SEQUENCE_START)
	return summary


## Попълва DomainEvent.command_sequence за replay / presentation gate.
func _stamp_events(events: Array, sequence: int) -> void:
	for entry in events:
		if entry is DomainEvent:
			(entry as DomainEvent).command_sequence = sequence


## При старт: restore от GameState.rng_state ако snapshot е по-напреднал от
## свежия seed; иначе capture началния жив RNG в GameState (#60).
func _sync_rng_on_start() -> void:
	if _state == null or _rng == null:
		return
	if _state.has_rng_state() and not _state.rng_matches(_rng):
		if not _state.restore_rng(_rng):
			push_warning("MatchSession: rng_state restore failed — capturing live RNG")
			_state.capture_rng(_rng)
	else:
		_state.capture_rng(_rng)


## Създава CommandBus и свързва HumanController.action_ready → submit.
func _setup_command_bus() -> void:
	_clear_human_action_routes()
	if _command_bus != null:
		_command_bus.unbind()
	_command_bus = CommandBus.new()
	_command_bus.bind(self)
	for controller in _controllers.values():
		if controller is HumanController:
			(controller as HumanController).action_ready.connect(_command_bus.submit)


func _clear_human_action_routes() -> void:
	for controller in _controllers.values():
		if controller is HumanController:
			var human := controller as HumanController
			for connection in human.action_ready.get_connections():
				human.action_ready.disconnect(connection["callable"])
