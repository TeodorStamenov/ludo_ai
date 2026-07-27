class_name EventViewBinder
extends RefCounted
## Свързва DomainEvent → визуални изгледи (docs/V1_ARCHITECTURE.md §6.1 / §3).
##
## AnimationQueue вика present() за всеки event в батча. MVP (#167): синхронно
## прилага крайното визуално състояние (snap). Последователните анимации и
## await на animation_finished са #168 / #169 / #172+.
##
## Не валидира правила и не мести логически пионки — само отразява вече
## настъпили факти върху DiceView / PawnView / BoardView / HUD.

var _dice_view: DiceView = null
var _board_view: BoardView = null
var _hud: GameHUD = null
## pawn_id (StringName) → PawnView
var _pawn_views: Dictionary = {}
## Optional: (ValidMovesChangedEvent) -> void — обикновено GamePresenter.apply_valid_moves_changed
var _valid_moves_handler: Callable = Callable()


func set_dice_view(dice: DiceView) -> void:
	_dice_view = dice


func set_board_view(board: BoardView) -> void:
	_board_view = board


func set_hud(hud: GameHUD) -> void:
	_hud = hud


func set_pawn_views(views: Dictionary) -> void:
	_pawn_views = views if views != null else {}


func set_valid_moves_handler(handler: Callable) -> void:
	_valid_moves_handler = handler


## Прилага едно DomainEvent към свързаните изгледи. Невалидно / null → no-op.
func present(event: DomainEvent) -> void:
	if event == null:
		return
	if event is DiceRolledEvent:
		_present_dice_rolled(event as DiceRolledEvent)
	elif event is ValidMovesChangedEvent:
		_present_valid_moves_changed(event as ValidMovesChangedEvent)
	elif event is PawnMovedEvent:
		_present_pawn_moved(event as PawnMovedEvent)
	elif event is PawnExitedBaseEvent:
		_present_pawn_exited_base(event as PawnExitedBaseEvent)
	elif event is PawnSentHomeEvent:
		_present_pawn_sent_home(event as PawnSentHomeEvent)
	elif event is PawnFinishedEvent:
		_present_pawn_finished(event as PawnFinishedEvent)
	elif event is PawnCapturedEvent:
		_present_pawn_captured(event as PawnCapturedEvent)
	elif event is PawnStackFormedEvent:
		_present_pawn_stack_formed(event as PawnStackFormedEvent)
	elif event is TurnChangedEvent:
		_present_turn_changed(event as TurnChangedEvent)
	elif event is PlayerRankedEvent:
		_present_player_ranked(event as PlayerRankedEvent)
	elif event is MatchStartedEvent:
		_present_match_started(event as MatchStartedEvent)
	elif event is MatchFinishedEvent:
		_present_match_finished(event as MatchFinishedEvent)
	elif event is GiftSpawnedEvent:
		_present_gift_spawned(event as GiftSpawnedEvent)
	elif event is PowerUpResolvedEvent:
		_present_power_up_resolved(event as PowerUpResolvedEvent)


func _present_dice_rolled(event: DiceRolledEvent) -> void:
	if _dice_view != null and is_instance_valid(_dice_view):
		_dice_view.apply_dice_rolled(event)
	_notify_hud(&"present_dice_rolled", event)


func _present_valid_moves_changed(event: ValidMovesChangedEvent) -> void:
	if _valid_moves_handler.is_valid():
		_valid_moves_handler.call(event)


func _present_pawn_moved(event: PawnMovedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	var target: Vector2 = _local_for_pawn(pawn, event.to_cell_id)
	pawn.present_pawn_moved(event, target)


func _present_pawn_exited_base(event: PawnExitedBaseEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	var target: Vector2 = _local_for_pawn(pawn, event.spawn_cell_id)
	pawn.present_pawn_exited_base(event, target)


func _present_pawn_sent_home(event: PawnSentHomeEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	var target: Vector2 = _local_for_pawn(pawn, event.base_cell_id)
	pawn.present_pawn_sent_home(event, target)


func _present_pawn_finished(event: PawnFinishedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	var target: Vector2 = _local_for_pawn(pawn, event.center_cell_id)
	pawn.present_pawn_finished(event, target)


func _present_pawn_captured(event: PawnCapturedEvent) -> void:
	# Позицията се обновява от следващия PawnSentHome; тук само cue за capturer.
	if event == null or not event.is_valid():
		return
	var capturer: PawnView = _pawn_of(event.capturing_pawn_id)
	if capturer != null:
		capturer.present_pawn_captured(event)
	_notify_hud(&"present_pawn_captured", event)


func _present_pawn_stack_formed(event: PawnStackFormedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var arriving: PawnView = _pawn_of(event.arriving_pawn_id)
	var resident: PawnView = _pawn_of(event.resident_pawn_id)
	if arriving != null:
		arriving.present_stack_formed(event, true)
	if resident != null:
		resident.present_stack_formed(event, false)


func _present_turn_changed(event: TurnChangedEvent) -> void:
	_notify_hud(&"present_turn_changed", event)


func _present_player_ranked(event: PlayerRankedEvent) -> void:
	_notify_hud(&"present_player_ranked", event)


func _present_match_started(event: MatchStartedEvent) -> void:
	_notify_hud(&"present_match_started", event)


func _present_match_finished(event: MatchFinishedEvent) -> void:
	_notify_hud(&"present_match_finished", event)


func _present_gift_spawned(event: GiftSpawnedEvent) -> void:
	# GiftView wiring — отделна задача; HUD може да наблюдава.
	_notify_hud(&"present_gift_spawned", event)


func _present_power_up_resolved(event: PowerUpResolvedEvent) -> void:
	_notify_hud(&"present_power_up_resolved", event)


func _pawn_of(pawn_id: StringName) -> PawnView:
	if pawn_id == &"":
		return null
	var pawn: PawnView = _pawn_views.get(pawn_id) as PawnView
	if pawn == null or not is_instance_valid(pawn):
		return null
	return pawn


## Board cell_id → локална позиция в parent-а на пионката.
func _local_for_pawn(pawn: PawnView, cell_id: StringName) -> Vector2:
	if pawn == null or _board_view == null or not is_instance_valid(_board_view):
		return Vector2.ZERO
	if not CellId.is_valid(cell_id):
		return Vector2.ZERO
	var board_local: Vector2 = _board_view.get_cell_position_by_id(cell_id)
	var global_pos: Vector2 = _board_view.to_global(board_local)
	var parent_node: Node = pawn.get_parent()
	if parent_node is Node2D:
		return (parent_node as Node2D).to_local(global_pos)
	return global_pos


func _notify_hud(method_name: StringName, event: DomainEvent) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	if _hud.has_method(method_name):
		_hud.call(method_name, event)
