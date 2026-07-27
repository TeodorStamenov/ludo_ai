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
##   - прави snapshot след стабилна фаза (to_snapshot / get_last_stable_snapshot);
##   - възстановява се от snapshot без StartMatchCommand (restore_from_snapshot);
##   - притежава GameplayJournal за активния мач (replay / bug report / #132–#137);
##   - при MatchFinished произвежда MatchSummary чрез match_finished сигнал.
##
## Snapshot API (§5.2 / §9 / §11): to_snapshot(), to_snapshot_json(),
## is_snapshot_valid(), get_last_stable_snapshot(), restore_from_snapshot(),
## restore_from_snapshot_json() — payload за active_match.json / resume.

signal events_published(sequence: int, events: Array)
signal match_finished(summary: Dictionary)
signal awaiting_human_action(player_id: StringName, state_view: Dictionary, legal_actions: Array)
signal command_rejected(command: GameCommand, reason: String)

## Snapshot payload за SaveRepository.active_match (§5.2 / §9 / §11).
## LocalSaveRepository обвива с envelope {schema_version, saved_at, payload}.
const SNAPSHOT_SCHEMA_VERSION := 1

const SNAPSHOT_KEY_SCHEMA_VERSION := "schema_version"
const SNAPSHOT_KEY_MATCH_ID := "match_id"
const SNAPSHOT_KEY_STATE := "state"
const SNAPSHOT_KEY_RNG_STATE := "rng_state"
const SNAPSHOT_KEY_COMMAND_SEQUENCE := "command_sequence"
const SNAPSHOT_KEY_STATE_HASH := "state_hash"

var _config: MatchConfig = null
var _state: GameState = null
var _engine: GameEngine = null
var _rng: RandomSource = null
var _controllers: Dictionary = {}
var _event_queue: EventQueue = null
var _command_bus: CommandBus = null
var _journal: GameplayJournal = null
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
	_begin_journal()
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
		# Replay (#137) игнорира reject entries; bug report / debug ги четат (#135).
		var reason := str(result.get("error", "rejected"))
		if _journal != null:
			_journal.record_rejected_command(command, reason)
		command_rejected.emit(command, reason)
		return

	_state = result.get("state", _state)
	# GameEngine може вече да е записал sequence; иначе го записваме тук.
	if _state.command_sequence != command.sequence:
		if not _state.record_accepted_command(command.sequence):
			push_error(
					"MatchSession: command_sequence divergence (state=%d, command=%d)"
					% [_state.command_sequence, command.sequence])
			return
	# Replay (#137) чете само приети команди — записваме след успешен apply (#134).
	if _journal != null:
		_journal.record_accepted_command(command)
	# Синхронизира GameState.rng_state след приета команда (дори ако RNG не е
	# ползван — snapshot трябва да съвпада с живия RandomSource).
	_state.capture_rng(_rng)
	# Divergence / bug report (#136): hash след приета команда, с актуален rng_state.
	if _journal != null:
		_journal.record_state_hash(_state.command_sequence, _state.compute_hash())
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


func get_journal() -> GameplayJournal:
	return _journal


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


## JSON-safe snapshot на текущия мач за save / resume / divergence (§5.2 / §9).
## Синхронизира GameState.rng_state ← жив RNG преди export, за да няма drift.
## Не пише във файлова система — потребителят подава към SaveRepository.
func to_snapshot() -> Dictionary:
	if _state != null and _rng != null:
		_state.capture_rng(_rng)

	var state_dict: Dictionary = {}
	var match_id_str := ""
	var sequence := GameState.COMMAND_SEQUENCE_START
	var snap_rng: Dictionary = {}
	var state_hash := 0
	if _state != null:
		state_dict = _state.to_dict()
		match_id_str = String(_state.match_id)
		sequence = _state.command_sequence
		snap_rng = _state.rng_state.duplicate(true)
		state_hash = _state.compute_hash()
	elif _rng != null:
		snap_rng = _rng.get_state()

	return {
		SNAPSHOT_KEY_SCHEMA_VERSION: SNAPSHOT_SCHEMA_VERSION,
		SNAPSHOT_KEY_MATCH_ID: match_id_str,
		SNAPSHOT_KEY_STATE: state_dict,
		SNAPSHOT_KEY_RNG_STATE: snap_rng,
		SNAPSHOT_KEY_COMMAND_SEQUENCE: sequence,
		# String — JSON number губи int64 precision (IEEE-754).
		SNAPSHOT_KEY_STATE_HASH: str(state_hash),
	}


## Компактен JSON низ на to_snapshot() за persistence / bug report.
func to_snapshot_json() -> String:
	return JSON.stringify(to_snapshot())


## True ако payload-ът има договорните ключове и вложеният GameState е валиден
## и съгласуван с top-level match_id / command_sequence / state_hash.
## restore_from_snapshot() ползва това преди GameState.from_dict.
static func is_snapshot_valid(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if int(snapshot.get(SNAPSHOT_KEY_SCHEMA_VERSION, 0)) != SNAPSHOT_SCHEMA_VERSION:
		return false
	var state_data: Variant = snapshot.get(SNAPSHOT_KEY_STATE, null)
	if not (state_data is Dictionary) or (state_data as Dictionary).is_empty():
		return false
	var state := GameState.from_dict(state_data as Dictionary)
	if state == null or not state.is_valid():
		return false
	if state.match_config == null or not state.match_config.is_valid():
		return false
	if snapshot.has(SNAPSHOT_KEY_MATCH_ID):
		if StringName(str(snapshot[SNAPSHOT_KEY_MATCH_ID])) != state.match_id:
			return false
	if snapshot.has(SNAPSHOT_KEY_COMMAND_SEQUENCE):
		if int(snapshot[SNAPSHOT_KEY_COMMAND_SEQUENCE]) != state.command_sequence:
			return false
	if snapshot.has(SNAPSHOT_KEY_RNG_STATE):
		var top_rng: Variant = snapshot[SNAPSHOT_KEY_RNG_STATE]
		if not (top_rng is Dictionary):
			return false
		if not _rng_dicts_equal(state.rng_state, top_rng as Dictionary):
			return false
	if snapshot.has(SNAPSHOT_KEY_STATE_HASH):
		if str(snapshot[SNAPSHOT_KEY_STATE_HASH]) != str(state.compute_hash()):
			return false
	return true


## Възстановява MatchSession от snapshot payload (§5.2 / §9 / #130).
## Без StartMatchCommand — запазва GameState, RNG и command_sequence.
## При невалиден snapshot връща false и не мутира session (§12).
## След успех: стабилна фаза (без presentation pending); при IN_PROGRESS вика _advance().
func restore_from_snapshot(
		snapshot: Dictionary,
		engine: GameEngine = null,
		rng: RandomSource = null,
		controllers: Dictionary = {},
		event_queue: EventQueue = null
) -> bool:
	if not is_snapshot_valid(snapshot):
		return false
	var state := GameState.from_dict(snapshot[SNAPSHOT_KEY_STATE] as Dictionary)
	if state == null or state.match_config == null or not state.match_config.is_valid():
		return false

	_config = state.match_config.duplicate_config()
	_state = state
	_engine = engine if engine != null else GameEngine.new()
	_controllers = controllers
	_event_queue = event_queue if event_queue != null else EventQueue.new()
	_pending_sequence = -1
	_active = _state.is_in_progress()
	_last_stable_snapshot = snapshot.duplicate(true)

	if rng != null:
		_rng = rng
		if not _state.restore_rng(_rng):
			push_warning("MatchSession: restore_from_snapshot rng sync failed")
			_rng = _state.create_random_source_from_state()
	else:
		_rng = _state.create_random_source_from_state()

	_setup_command_bus()
	_begin_journal()
	if _active:
		_advance()
	return true


## JSON текст → restore_from_snapshot. Невалиден JSON / payload → false.
func restore_from_snapshot_json(
		text: String,
		engine: GameEngine = null,
		rng: RandomSource = null,
		controllers: Dictionary = {},
		event_queue: EventQueue = null
) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	return restore_from_snapshot(
			parsed as Dictionary, engine, rng, controllers, event_queue)


static func _rng_dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() and b.is_empty():
		return true
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
		if str(a[key]) != str(b[key]):
			return false
	return true


func _get_active_player_id() -> StringName:
	if _state == null:
		return &""
	return _state.get_active_player_id()


func _build_state_view() -> Dictionary:
	if _state == null:
		return {}
	return _state.to_view()


func _build_legal_actions() -> Array:
	if _state == null or _engine == null:
		return []
	# §5.3: controllers ползват същия набор от GameEngine (не директно GameState).
	return _engine.get_legal_actions(_state)


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


## Създава / нулира GameplayJournal за текущия match_id (#132).
## Записва MatchConfig, seed и content version в header-а (#133).
## Приети/отхвърлени команди и state hash се добавят в receive_command (#134–#136).
func _begin_journal() -> void:
	if _journal == null:
		_journal = GameplayJournal.new()
	var id: StringName = _state.match_id if _state != null else &""
	_journal.begin(id)
	# Replay / bug report четат seed от header (не от живия RNG state).
	var seed_value: int = _config.rng_seed if _config != null else 0
	_journal.record_header(_config, seed_value)
