class_name MatchSession
extends RefCounted
## Application service за управление на един активен мач
## (docs/V1_ARCHITECTURE.md, раздел 5.2).
##
## MatchSession НЕ е глобален вечен singleton. Създава се за конкретен
## мач от MatchFactory и се освобождава след Results екрана.
##
## Отговорности:
##   - притежава GameState, GameEngine и RandomSource;
##   - приема GameCommand-и от PlayerController-ите чрез receive_command();
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

var _config: MatchConfig = null
var _state: GameState = null
var _engine: GameEngine = null
var _rng: RandomSource = null
var _controllers: Dictionary = {}
var _event_queue: EventQueue = null
var _pending_sequence: int = -1
var _command_sequence: int = 0
var _active: bool = false


func start(config: MatchConfig, state: GameState, engine: GameEngine, rng: RandomSource,
		controllers: Dictionary, event_queue: EventQueue) -> void:
	_config = config
	_state = state
	_engine = engine
	_rng = rng
	_controllers = controllers
	_event_queue = event_queue
	_active = true
	receive_command(StartMatchCommand.new(config))


func receive_command(command: GameCommand) -> void:
	if not _active:
		return
	if _pending_sequence >= 0:
		push_warning("MatchSession: command dropped — presentation pending sequence %d" % _pending_sequence)
		return
	if not _engine:
		push_error("MatchSession: no GameEngine bound")
		return

	command.sequence = _command_sequence + 1
	var result: Dictionary = _engine.apply_command(_state, command, _rng)

	if not result.get("accepted", false):
		return

	_state = result.get("state", _state)
	_command_sequence += 1
	var events: Array = result.get("events", [])
	_event_queue.enqueue(events)
	_pending_sequence = _command_sequence
	events_published.emit(_pending_sequence, events)

	if _is_match_over(events):
		_active = false
		match_finished.emit(_build_summary())


func events_presented(sequence: int) -> void:
	if sequence != _pending_sequence:
		return
	_pending_sequence = -1
	if _active:
		_advance()


func _advance() -> void:
	var active_id := _get_active_player_id()
	if active_id.is_empty():
		return
	var controller: PlayerController = _controllers.get(active_id)
	if not controller:
		push_error("MatchSession: no controller for player '%s'" % active_id)
		return
	var state_view := _build_state_view()
	var legal := _build_legal_actions()
	if controller.is_autonomous():
		var cmd: GameCommand = controller.get_action(state_view, legal)
		if cmd:
			cmd.player_id = active_id
			receive_command(cmd)
	else:
		awaiting_human_action.emit(active_id, state_view, legal)


func get_state() -> GameState:
	return _state


func get_event_queue() -> EventQueue:
	return _event_queue


func is_active() -> bool:
	return _active


func to_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"state": _state.to_dict() if _state and _state.has_method("to_dict") else {},
		"rng_state": _rng.get_state() if _rng else {},
		"command_sequence": _command_sequence,
	}


func _get_active_player_id() -> StringName:
	if _state and _state.has_method("get_active_player_id"):
		return _state.get_active_player_id()
	return &""


func _build_state_view() -> Dictionary:
	if _state and _state.has_method("to_view"):
		return _state.to_view()
	return {}


func _build_legal_actions() -> Array:
	if _state and _state.has_method("get_legal_actions"):
		return _state.get_legal_actions()
	return []


func _is_match_over(events: Array) -> bool:
	for event in events:
		if event is DomainEvent and event.event_type == &"MatchFinished":
			return true
	return false


func _build_summary() -> Dictionary:
	var summary: Dictionary = {
		"command_sequence": _command_sequence,
	}
	if _state:
		if _state.has_method("get_match_id"):
			summary["match_id"] = _state.get_match_id()
		if "ranking" in _state:
			summary["ranking"] = _state.ranking
	return summary
