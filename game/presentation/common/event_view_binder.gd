class_name EventViewBinder
extends RefCounted
## Свързва DomainEvent → визуални изгледи (docs/V1_ARCHITECTURE.md §6.1 / §3).
##
## `present()` — синхронен snap (#167), за instant apply без tween.
## `present_for_playback()` — async за AnimationQueue (#168): стартира
## анимация и чака `animation_finished` чрез AnimationFinishedGate (#169).
## DiceRolled → present_dice_rolled + gate(KIND_ROLL).
## PawnMoved → hop клетка по клетка по маршрута (#172 / YEL-040) след приет
## MovePawnCommand (#171 / YEL-023); разпадане на купчина преди hop (#174).
## PawnExitedBase → hop база → spawn (#173 / YEL-030).
## PawnStackFormed → offset settle на двете пионки (#174).
## PawnSentHome → меко „вкъщи“ shrink+settle в базата (#175).
## PawnFinished → pulse на място (V1.1: играчът прибира пионка веднага щом
## всичките 4 влязат в home stretch — флаг-превключване, без движение) (#176).
##
## Не валидира правила и не мести логически пионки — само отразява вече
## настъпили факти върху DiceView / PawnView / BoardView / HUD.

const GIFT_TEXTURE_PATH := "res://rss/gifts/GiftNew.png"

var _dice_view: DiceView = null
var _board_view: BoardView = null
var _hud: GameHUD = null
## pawn_id (StringName) → PawnView
var _pawn_views: Dictionary = {}
## Контейнерен Node2D за динамично създадени GiftView (GameScreen/GamePresenter #219).
var _gifts_root: Node2D = null
## gift_id (StringName) → GiftView — за разлика от пионките, gift views се
## създават/унищожават реактивно от GiftSpawned/GiftCollected, не при bootstrap.
var _gift_views: Dictionary = {}
## Optional: (ValidMovesChangedEvent) -> void — обикновено GamePresenter.apply_valid_moves_changed.
## Ако липсва, binder-ът сам вика PawnView.show_valid_move / hide_valid_move (#170).
var _valid_moves_handler: Callable = Callable()


func set_dice_view(dice: DiceView) -> void:
	_dice_view = dice


func set_board_view(board: BoardView) -> void:
	_board_view = board


func set_hud(hud: GameHUD) -> void:
	_hud = hud


func set_pawn_views(views: Dictionary) -> void:
	_pawn_views = views if views != null else {}


func set_gifts_root(root: Node2D) -> void:
	_gifts_root = root


func set_valid_moves_handler(handler: Callable) -> void:
	_valid_moves_handler = handler


## Прилага едно DomainEvent синхронно (snap). Невалидно / null → no-op.
func present(event: DomainEvent) -> void:
	if event == null:
		return
	if event is DiceRolledEvent:
		_present_dice_rolled_snap(event as DiceRolledEvent)
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
	elif event is GiftCollectedEvent:
		_present_gift_collected(event as GiftCollectedEvent)
	elif event is PowerUpResolvedEvent:
		_present_power_up_resolved(event as PowerUpResolvedEvent)


## Async playback за AnimationQueue (#168). Анимираните events чакат
## animation_finished (#169); останалите минават през present() без yield.
func present_for_playback(event: DomainEvent) -> void:
	if event == null:
		return
	if event is DiceRolledEvent:
		await _present_dice_rolled_animated(event as DiceRolledEvent)
	elif event is PawnMovedEvent:
		await _present_pawn_moved_animated(event as PawnMovedEvent)
	elif event is PawnExitedBaseEvent:
		await _present_pawn_exited_base_animated(event as PawnExitedBaseEvent)
	elif event is PawnStackFormedEvent:
		await _present_pawn_stack_formed_animated(event as PawnStackFormedEvent)
	elif event is PawnSentHomeEvent:
		await _present_pawn_sent_home_animated(event as PawnSentHomeEvent)
	elif event is PawnFinishedEvent:
		await _present_pawn_finished_animated(event as PawnFinishedEvent)
	elif event is GiftSpawnedEvent:
		await _present_gift_spawned_animated(event as GiftSpawnedEvent)
	elif event is GiftCollectedEvent:
		await _present_gift_collected_animated(event as GiftCollectedEvent)
	else:
		present(event)


func _present_dice_rolled_snap(event: DiceRolledEvent) -> void:
	if _dice_view != null and is_instance_valid(_dice_view):
		_dice_view.apply_dice_rolled(event)
	_notify_hud(&"present_dice_rolled", event)


## Toss анимация; потвърждението е animation_finished(KIND_ROLL) (#169).
## При липсващ/занят зар — snap fallback (без deadlock).
func _present_dice_rolled_animated(event: DiceRolledEvent) -> void:
	if event == null or not event.is_valid():
		return
	if _dice_view != null and is_instance_valid(_dice_view) and not _dice_view.is_rolling:
		await AnimationFinishedGate.await_started(
				_dice_view,
				DiceView.KIND_ROLL,
				_dice_view.present_dice_rolled.bind(event)
		)
	elif _dice_view != null and is_instance_valid(_dice_view):
		_dice_view.apply_dice_rolled(event)
	_notify_hud(&"present_dice_rolled", event)


## ValidMovesChanged → bob на валидните пионки (YEL-020 / #170).
## Handler (GamePresenter) има приоритет — пази selection state; иначе директен apply.
func _present_valid_moves_changed(event: ValidMovesChangedEvent) -> void:
	if event == null:
		return
	if _valid_moves_handler.is_valid():
		_valid_moves_handler.call(event)
		return
	apply_valid_pawn_ids(event.valid_pawn_ids)


## Изчиства bob на всички регистрирани пионки, после show_valid_move за списъка.
## Празен списък = само изчистване (няма избираеми / край на хода).
func apply_valid_pawn_ids(pawn_ids: Array) -> void:
	for key in _pawn_views.keys():
		var pawn: PawnView = _pawn_of(StringName(str(key)))
		if pawn != null:
			pawn.hide_valid_move()
	if pawn_ids == null:
		return
	for entry in pawn_ids:
		var pawn: PawnView = _pawn_of(StringName(str(entry)))
		if pawn != null:
			pawn.show_valid_move()


func _present_pawn_moved(event: PawnMovedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_snap(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.to_cell_id)
	pawn.present_pawn_moved(event, target)


## Hop клетка по клетка след приет MovePawnCommand (#172 / YEL-040).
## Разпадане на купчина преди hop (#174). Busy pawn → snap към to_cell.
## KIND_MOVE едва след последната стъпка.
func _present_pawn_moved_animated(event: PawnMovedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_before_departure(pawn)
	var step_cell_ids: Array[StringName] = _resolve_move_step_cell_ids(event)
	var step_locals: Array[Vector2] = []
	var step_jump_over: Array[bool] = []
	for cell_id in step_cell_ids:
		step_locals.append(_local_for_pawn(pawn, cell_id))
		step_jump_over.append(_is_cell_occupied_for_jump(cell_id, event.pawn_id))
	if step_cell_ids.is_empty() or step_locals.is_empty():
		return
	if not pawn.is_moving:
		await AnimationFinishedGate.await_started(
				pawn,
				PawnView.KIND_MOVE,
				pawn.present_pawn_moved_animated.bind(event, step_cell_ids, step_locals, step_jump_over)
		)
	else:
		pawn.present_pawn_moved(event, step_locals[step_locals.size() - 1])


## Exclusive-from → inclusive-to по player route (board геометрия, не MoveRules).
## Finish (CENTER / FINISHED): само остатъкът от home stretch — центърът е
## PawnFinished (#176). Непоследователен скок → само to_cell.
func _resolve_move_step_cell_ids(event: PawnMovedEvent) -> Array[StringName]:
	var cells: Array[StringName] = []
	if event == null:
		return cells
	var route: Array[StringName] = _player_route_for(event.get_player_id())
	var from_idx: int = route.find(event.from_cell_id)
	if CellId.is_center(event.to_cell_id) or event.zone == PawnZone.FINISHED:
		if from_idx >= 0:
			for i in range(from_idx + 1, route.size()):
				cells.append(route[i])
		return cells
	var to_idx: int = route.find(event.to_cell_id)
	if from_idx < 0 or to_idx < 0 or to_idx <= from_idx:
		cells.append(event.to_cell_id)
		return cells
	for i in range(from_idx + 1, to_idx + 1):
		cells.append(route[i])
	return cells


func _player_route_for(player_id: StringName) -> Array[StringName]:
	if _board_view != null and is_instance_valid(_board_view):
		var definition: BoardDefinition = _board_view.get_board_definition()
		if definition != null:
			var route: Array[StringName] = definition.build_player_route(player_id)
			if not route.is_empty():
				return route
	return Classic15x15Board.player_route_cell_ids_for(player_id)


func _present_pawn_exited_base(event: PawnExitedBaseEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_snap(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.spawn_cell_id)
	pawn.present_pawn_exited_base(event, target)


## Hop база → spawn след приет MovePawnCommand (#173 / YEL-030).
## Busy pawn → snap към spawn (без deadlock). KIND_MOVE след кацане.
func _present_pawn_exited_base_animated(event: PawnExitedBaseEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_before_departure(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.spawn_cell_id)
	var is_jump: bool = _is_cell_occupied_for_jump(event.spawn_cell_id, event.pawn_id)
	if not pawn.is_moving:
		await AnimationFinishedGate.await_started(
				pawn,
				PawnView.KIND_MOVE,
				pawn.present_pawn_exited_base_animated.bind(event, target, is_jump)
		)
	else:
		pawn.present_pawn_exited_base(event, target)


func _present_pawn_sent_home(event: PawnSentHomeEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_snap(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.base_cell_id)
	pawn.present_pawn_sent_home(event, target)


## Меко shrink+settle към база след capture (#175). Busy → snap. KIND_HOME след settle.
func _present_pawn_sent_home_animated(event: PawnSentHomeEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_before_departure(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.base_cell_id)
	if not pawn.is_moving:
		await AnimationFinishedGate.await_started(
				pawn,
				PawnView.KIND_HOME,
				pawn.present_pawn_sent_home_animated.bind(event, target)
		)
	else:
		pawn.present_pawn_sent_home(event, target)


func _present_pawn_finished(event: PawnFinishedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_snap(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.final_cell_id)
	pawn.present_pawn_finished(event, target)


## Pulse на място (V1.1: final_cell_id == from_cell_id, без движение) (#176).
## Busy → snap. KIND_FINISH след settle.
func _present_pawn_finished_animated(event: PawnFinishedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var pawn: PawnView = _pawn_of(event.pawn_id)
	if pawn == null:
		return
	_dissolve_stack_before_departure(pawn)
	var target: Vector2 = _local_for_pawn(pawn, event.final_cell_id)
	if not pawn.is_moving:
		await AnimationFinishedGate.await_started(
				pawn,
				PawnView.KIND_FINISH,
				pawn.present_pawn_finished_animated.bind(event, target)
		)
	else:
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


## Паралелен settle към stack offsets (#174). Busy → snap. KIND_STACK от двете.
func _present_pawn_stack_formed_animated(event: PawnStackFormedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var arriving: PawnView = _pawn_of(event.arriving_pawn_id)
	var resident: PawnView = _pawn_of(event.resident_pawn_id)
	var arriving_busy: bool = arriving != null and arriving.is_moving
	var resident_busy: bool = resident != null and resident.is_moving
	if arriving_busy or resident_busy:
		_present_pawn_stack_formed(event)
		return
	var gate_arriving := AnimationFinishedGate.new()
	var gate_resident := AnimationFinishedGate.new()
	if arriving != null:
		gate_arriving.arm(arriving, PawnView.KIND_STACK)
		arriving.present_stack_formed_animated(event, true)
	else:
		gate_arriving.arm(null, PawnView.KIND_STACK)
	if resident != null:
		gate_resident.arm(resident, PawnView.KIND_STACK)
		resident.present_stack_formed_animated(event, false)
	else:
		gate_resident.arm(null, PawnView.KIND_STACK)
	await gate_arriving.wait()
	await gate_resident.wait()


## Snap разпадане: напускащата маха membership; партньорът се връща в центъра.
func _dissolve_stack_snap(pawn: PawnView) -> void:
	if pawn == null or not pawn.is_stacked:
		return
	var partner: PawnView = _pawn_of(pawn.stack_partner_id)
	pawn.clear_stack_for_departure()
	if partner != null and partner.is_stacked:
		partner.present_stack_dissolved()


## Разпадане на купчина при departure (#174). Умишлено НЕ се await-ва от
## caller-ите (bug report: изглеждаше като бъг двете пионки да "нулират" и да
## се наслагват в центъра, преди избраната изобщо да тръгне) — тук само
## изчистваме stack membership-а синхронно (без визуален скок за напускащата),
## а партньорът settle-ва към центъра ПАРАЛЕЛНО с departure hop-а на
## напускащата, не преди него.
func _dissolve_stack_before_departure(pawn: PawnView) -> void:
	if pawn == null or not pawn.is_stacked:
		return
	var partner: PawnView = _pawn_of(pawn.stack_partner_id)
	pawn.clear_stack_for_departure()
	if partner == null or not partner.is_stacked:
		return
	if partner.is_moving:
		partner.present_stack_dissolved()
		return
	await AnimationFinishedGate.await_started(
			partner,
			PawnView.KIND_STACK,
			partner.present_stack_dissolved_animated
	)


func _present_turn_changed(event: TurnChangedEvent) -> void:
	_notify_hud(&"present_turn_changed", event)


func _present_player_ranked(event: PlayerRankedEvent) -> void:
	_notify_hud(&"present_player_ranked", event)


func _present_match_started(event: MatchStartedEvent) -> void:
	_notify_hud(&"present_match_started", event)


func _present_match_finished(event: MatchFinishedEvent) -> void:
	_notify_hud(&"present_match_finished", event)


func _present_gift_spawned(event: GiftSpawnedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var gift: GiftView = _ensure_gift_view(event.gift_id)
	if gift == null:
		return
	var target: Vector2 = _local_for_gift(event.cell_id)
	gift.present_gift_spawned(event, target)
	_notify_hud(&"present_gift_spawned", event)


## Pop-in анимация (#219). Busy/missing board → snap fallback без deadlock.
func _present_gift_spawned_animated(event: GiftSpawnedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var gift: GiftView = _ensure_gift_view(event.gift_id)
	if gift == null:
		return
	var target: Vector2 = _local_for_gift(event.cell_id)
	await AnimationFinishedGate.await_started(
			gift,
			GiftView.KIND_SPAWN,
			gift.present_gift_spawned_animated.bind(event, target)
	)
	_notify_hud(&"present_gift_spawned", event)


func _present_gift_collected(event: GiftCollectedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var gift: GiftView = _gift_views.get(event.gift_id) as GiftView
	_gift_views.erase(event.gift_id)
	if gift != null and is_instance_valid(gift):
		gift.present_gift_collected(event)
	_notify_hud(&"present_gift_collected", event)


## Burst + fade преди изчезване (#219). Липсващ view (вече премахнат) → само HUD notify.
func _present_gift_collected_animated(event: GiftCollectedEvent) -> void:
	if event == null or not event.is_valid():
		return
	var gift: GiftView = _gift_views.get(event.gift_id) as GiftView
	_gift_views.erase(event.gift_id)
	if gift != null and is_instance_valid(gift):
		await AnimationFinishedGate.await_started(
				gift,
				GiftView.KIND_COLLECTED,
				gift.present_gift_collected_animated.bind(event)
		)
	_notify_hud(&"present_gift_collected", event)


func _present_power_up_resolved(event: PowerUpResolvedEvent) -> void:
	_notify_hud(&"present_power_up_resolved", event)


## Създава (веднъж) или връща съществуващ GiftView за gift_id, добавен в _gifts_root.
func _ensure_gift_view(gift_id: StringName) -> GiftView:
	if gift_id == &"" or _gifts_root == null or not is_instance_valid(_gifts_root):
		return null
	var existing: GiftView = _gift_views.get(gift_id) as GiftView
	if existing != null and is_instance_valid(existing):
		return existing
	var gift := GiftView.new()
	gift.name = String(gift_id)
	_gifts_root.add_child(gift)
	var tile_w: float = (
			_board_view.get_tile_display_width()
			if _board_view != null and is_instance_valid(_board_view) else 0.0)
	gift.setup(GIFT_TEXTURE_PATH, tile_w)
	_gift_views[gift_id] = gift
	return gift


## Board cell_id → локална позиция в _gifts_root (аналог на _local_for_pawn).
func _local_for_gift(cell_id: StringName) -> Vector2:
	if _gifts_root == null or not is_instance_valid(_gifts_root):
		return Vector2.ZERO
	if _board_view == null or not is_instance_valid(_board_view):
		return Vector2.ZERO
	if not CellId.is_valid(cell_id):
		return Vector2.ZERO
	var board_local: Vector2 = _board_view.get_cell_position_by_id(cell_id)
	var global_pos: Vector2 = _board_view.to_global(board_local)
	return _gifts_root.to_local(global_pos)


## True ако cell_id в момента е заета от друга пионка (различна от
## excluding_pawn_id) или от активен GiftView — hop-ът към/над тази клетка
## трябва да е по-висок за визуален "прескок" ефект (bug report).
func _is_cell_occupied_for_jump(cell_id: StringName, excluding_pawn_id: StringName) -> bool:
	if not CellId.is_valid(cell_id):
		return false
	var target_grid: Vector2i = CellId.to_vec(cell_id)
	for key in _pawn_views.keys():
		if key == excluding_pawn_id:
			continue
		var other: PawnView = _pawn_views[key] as PawnView
		if other != null and is_instance_valid(other) and other.grid_pos == target_grid:
			return true
	for entry in _gift_views.values():
		var gift := entry as GiftView
		if gift != null and is_instance_valid(gift) and gift.cell_id == cell_id:
			return true
	return false


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
