class_name GamePresenter
extends Node
## Мост между Application (MatchSession) и Presentation view слоя
## (docs/V1_ARCHITECTURE.md, раздел 6.1).
##
## Отговорности:
##   - слуша events_published(sequence, events) от MatchSession;
##   - предава батча към AnimationQueue;
##   - след AnimationQueue.all_done() извиква session.events_presented(sequence);
##   - преобразува ValidMovesChanged / awaiting_human_action → подсветяване;
##   - преобразува клик/tap върху пионка → HumanController.submit_move;
##   - преобразува клик върху зар → HumanController.submit_roll;
##   - слуша match_finished → results_requested (AppFlow / GameScreen);
##   - излага read-only state_view от GameState.to_view() (#6.1).
##
## Не решава дали ход е валиден. Не мести пионки самостоятелно.
## Не вика GameEngine / MatchSession.receive_command() директно.

signal results_requested(summary: Dictionary)
signal state_view_changed(state_view: Dictionary)
signal human_action_available(player_id: StringName, legal_actions: Array)

var _session: MatchSession = null
var _animation_queue: AnimationQueue = null
var _dice_view: DiceView = null
var _board_view: BoardView = null
var _hud: GameHUD = null
## pawn_id (StringName) → PawnView
var _pawn_views: Dictionary = {}

var _active_human: HumanController = null
var _active_player_id: StringName = &""
var _state_view: Dictionary = {}
var _legal_actions: Array = []
var _can_roll: bool = false
var _input_enabled: bool = false
var _presenting_sequence: int = -1
var _selected_pawn_id: StringName = &""
var _pending_summary: Dictionary = {}


## Свързва MatchSession сигналите. Повторно bind() първо unbind-ва.
func bind(session: MatchSession) -> void:
	unbind()
	if session == null:
		push_error("GamePresenter.bind: session не може да е null")
		return
	_session = session
	_session.events_published.connect(_on_events_published)
	_session.awaiting_human_action.connect(_on_awaiting_human_action)
	_session.match_finished.connect(_on_match_finished)


func unbind() -> void:
	if _session != null:
		_disconnect_session_signals()
	_session = null
	_active_human = null
	_active_player_id = &""
	_state_view = {}
	_legal_actions = []
	_can_roll = false
	_input_enabled = false
	_presenting_sequence = -1
	_selected_pawn_id = &""
	_pending_summary = {}
	_clear_valid_move_highlights()


func is_bound() -> bool:
	return _session != null


func get_session() -> MatchSession:
	return _session


## Read-only view model (§6.1). Кеш от последния awaiting_human / refresh.
func get_state_view() -> Dictionary:
	if not _state_view.is_empty():
		return _state_view.duplicate(true)
	if _session == null:
		return {}
	var state: GameState = _session.get_state()
	if state == null:
		return {}
	return state.to_view()


func set_animation_queue(queue: AnimationQueue) -> void:
	if _animation_queue != null and _animation_queue.all_done.is_connected(_on_animation_all_done):
		_animation_queue.all_done.disconnect(_on_animation_all_done)
	_animation_queue = queue
	if _animation_queue != null and not _animation_queue.all_done.is_connected(_on_animation_all_done):
		_animation_queue.all_done.connect(_on_animation_all_done)


func set_dice_view(dice: DiceView) -> void:
	if _dice_view != null and _dice_view.roll_requested.is_connected(_on_dice_roll_requested):
		_dice_view.roll_requested.disconnect(_on_dice_roll_requested)
	_dice_view = dice
	if _dice_view != null and not _dice_view.roll_requested.is_connected(_on_dice_roll_requested):
		_dice_view.roll_requested.connect(_on_dice_roll_requested)


func set_board_view(board: BoardView) -> void:
	_board_view = board


func get_board_view() -> BoardView:
	return _board_view


func set_hud(hud: GameHUD) -> void:
	_hud = hud


func get_hud() -> GameHUD:
	return _hud


func get_dice_view() -> DiceView:
	return _dice_view


func get_animation_queue() -> AnimationQueue:
	return _animation_queue


## Регистрира PawnView за highlight + input. Повторна регистрация заменя.
func register_pawn_view(pawn: PawnView) -> void:
	if pawn == null or pawn.pawn_id == &"":
		return
	var existing: PawnView = _pawn_views.get(pawn.pawn_id) as PawnView
	if existing != null and existing != pawn:
		if existing.clicked.is_connected(_on_pawn_clicked):
			existing.clicked.disconnect(_on_pawn_clicked)
	_pawn_views[pawn.pawn_id] = pawn
	if not pawn.clicked.is_connected(_on_pawn_clicked):
		pawn.clicked.connect(_on_pawn_clicked)


func unregister_pawn_view(pawn_id: StringName) -> void:
	var pawn: PawnView = _pawn_views.get(pawn_id) as PawnView
	if pawn != null and pawn.clicked.is_connected(_on_pawn_clicked):
		pawn.clicked.disconnect(_on_pawn_clicked)
	_pawn_views.erase(pawn_id)


func clear_pawn_views() -> void:
	for key in _pawn_views.keys():
		var pawn: PawnView = _pawn_views[key] as PawnView
		if pawn != null and is_instance_valid(pawn) and pawn.clicked.is_connected(_on_pawn_clicked):
			pawn.clicked.disconnect(_on_pawn_clicked)
	_pawn_views.clear()


## Подсветява валидните пионки (ValidMovesChanged / awaiting_human). Не валидира правила.
func apply_valid_pawn_ids(pawn_ids: Array) -> void:
	_clear_valid_move_highlights()
	for entry in pawn_ids:
		var pawn_id := StringName(str(entry))
		var pawn: PawnView = _pawn_views.get(pawn_id) as PawnView
		if pawn != null and is_instance_valid(pawn):
			pawn.show_valid_move()


## ValidMovesChanged → подсветяване. AnimationQueue (#167/#168) може да го вика при play.
func apply_valid_moves_changed(event: ValidMovesChangedEvent) -> void:
	if event == null:
		return
	apply_valid_pawn_ids(event.valid_pawn_ids)


func _disconnect_session_signals() -> void:
	if _session.events_published.is_connected(_on_events_published):
		_session.events_published.disconnect(_on_events_published)
	if _session.awaiting_human_action.is_connected(_on_awaiting_human_action):
		_session.awaiting_human_action.disconnect(_on_awaiting_human_action)
	if _session.match_finished.is_connected(_on_match_finished):
		_session.match_finished.disconnect(_on_match_finished)


func _on_events_published(sequence: int, events: Array) -> void:
	_disable_human_input()
	_clear_valid_move_highlights()
	_presenting_sequence = sequence
	if _animation_queue != null:
		_animation_queue.play_batch(sequence, events)
	else:
		_on_animation_all_done(sequence)


func _on_animation_all_done(sequence: int) -> void:
	if _presenting_sequence < 0 or sequence != _presenting_sequence:
		return
	_presenting_sequence = -1
	if _session != null:
		_session.events_presented(sequence)
	if not _pending_summary.is_empty():
		_emit_results(_pending_summary)


func _on_awaiting_human_action(
		player_id: StringName,
		state_view: Dictionary,
		legal_actions: Array
) -> void:
	_active_player_id = player_id
	_state_view = state_view.duplicate(true) if not state_view.is_empty() else {}
	_legal_actions = legal_actions.duplicate()
	_active_human = null
	if _session != null:
		var controller := _session.get_controller(player_id)
		if controller is HumanController:
			_active_human = controller as HumanController
	_can_roll = _legal_actions_allow_roll(legal_actions)
	_input_enabled = _active_human != null
	_selected_pawn_id = &""
	var pawn_ids: Array = _extract_valid_pawn_ids(state_view, legal_actions)
	apply_valid_pawn_ids(pawn_ids)
	state_view_changed.emit(get_state_view())
	human_action_available.emit(player_id, legal_actions)
	_notify_hud_state()


func _on_match_finished(summary: Dictionary) -> void:
	_pending_summary = summary.duplicate(true) if not summary.is_empty() else {}
	_disable_human_input()
	_clear_valid_move_highlights()
	if _presenting_sequence < 0:
		_emit_results(_pending_summary)


func _on_dice_roll_requested() -> void:
	if not _input_enabled or not _can_roll or _active_human == null:
		return
	if not _active_human.is_waiting():
		return
	_disable_human_input()
	_active_human.submit_roll()


func _on_pawn_clicked(pawn: PawnView) -> void:
	if not _input_enabled or _active_human == null or pawn == null:
		return
	if not pawn.is_selectable:
		return
	if not _active_human.is_waiting():
		return

	var pawn_id: StringName = pawn.pawn_id
	if _selected_pawn_id == pawn_id:
		_disable_human_input()
		_clear_valid_move_highlights()
		_active_human.submit_move(pawn_id)
		return

	_clear_selection()
	_selected_pawn_id = pawn_id
	pawn.set_selected(true)


func _extract_valid_pawn_ids(state_view: Dictionary, legal_actions: Array) -> Array:
	var from_view: Variant = state_view.get("valid_pawn_ids", [])
	if from_view is Array and not (from_view as Array).is_empty():
		return (from_view as Array).duplicate()
	var from_actions: Array = []
	for action in legal_actions:
		if action is MovePawnCommand:
			from_actions.append((action as MovePawnCommand).pawn_id)
	return from_actions


func _legal_actions_allow_roll(legal_actions: Array) -> bool:
	for action in legal_actions:
		if action is RollDiceCommand:
			return true
	return false


func _disable_human_input() -> void:
	_input_enabled = false
	_can_roll = false
	_clear_selection()


func _clear_selection() -> void:
	if _selected_pawn_id != &"":
		var selected: PawnView = _pawn_views.get(_selected_pawn_id) as PawnView
		if selected != null and is_instance_valid(selected):
			selected.set_selected(false)
	_selected_pawn_id = &""


func _clear_valid_move_highlights() -> void:
	_clear_selection()
	for key in _pawn_views.keys():
		var pawn: PawnView = _pawn_views[key] as PawnView
		if pawn != null and is_instance_valid(pawn):
			pawn.hide_valid_move()


func _notify_hud_state() -> void:
	if _hud == null:
		return
	if _hud.has_method(&"apply_state_view"):
		_hud.call(&"apply_state_view", get_state_view())


func _emit_results(summary: Dictionary) -> void:
	var payload: Dictionary = summary.duplicate(true) if not summary.is_empty() else {}
	_pending_summary = {}
	results_requested.emit(payload)
	var app_flow: Node = get_node_or_null("/root/AppFlow")
	if app_flow != null and app_flow.has_method(&"navigate_to_results"):
		app_flow.call(&"navigate_to_results", payload)
