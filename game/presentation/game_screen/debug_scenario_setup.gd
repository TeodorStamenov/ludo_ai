class_name DebugScenarioSetup
extends Node
## Визуална подредба на дъската преди старта на мач — само в debug build
## (docs/V1_ARCHITECTURE.md §6.4; DebugMode.is_authorized()).
##
## Модел на взаимодействие (огледален на самия геймплей):
##   режим ПИОНКИ  — клик върху пионка я избира, клик върху клетка я мести;
##   режим ПОДАРЪЦИ — клик върху клетка поставя/маха подарък.
##
## ВАЖНО: тук се записват само НАМЕРЕНИЯ, не се мутира GameState. Причината е
## че StartMatchCommand изгражда състоянието от нулата
## (GameEngine._apply_start_match → GameState.create_from_match_config) и би
## изтрил всяка подредба, направена преди begin(). Затова GameScreen вика
## begin() първо и веднага след това apply_to_state() в същия call stack,
## преди AI таймер да е могъл да реагира.
##
## По време на подредбата се местят само изгледите (PawnView / preview
## GiftView), за да вижда потребителят резултата.

signal start_requested

enum Mode {
	PAWNS,
	GIFTS,
}

## Отместване за gift_id при подредба, за да не се сблъскат с подаръците,
## които GiftRules ще създаде по-късно (те ползват command_sequence).
const DEBUG_GIFT_ID_OFFSET: int = 900000

var _board: BoardView = null
var _gifts_root: Node2D = null
## pawn_id (StringName) → PawnView
var _pawn_views: Dictionary = {}

var _active: bool = false
var _mode: int = Mode.PAWNS
var _selected_pawn_id: StringName = &""
var _last_error: String = ""

## pawn_id (StringName) → cell_id (StringName)
var _pawn_cells: Dictionary = {}
## cell_id (StringName) в реда на поставяне
var _gift_cells: Array[StringName] = []
## cell_id (StringName) → GiftView preview
var _gift_previews: Dictionary = {}


func is_active() -> bool:
	return _active


func get_last_error() -> String:
	return _last_error


func get_mode() -> int:
	return _mode


## Влиза в режим подредба. pawn_views: pawn_id → PawnView.
func enter(board: BoardView, pawn_views: Dictionary, gifts_root: Node2D) -> void:
	_board = board
	_pawn_views = pawn_views if pawn_views != null else {}
	_gifts_root = gifts_root
	_active = true
	_mode = Mode.PAWNS
	_selected_pawn_id = &""
	_last_error = ""
	set_process_unhandled_input(true)


## Излиза от режим подредба и чисти preview изгледите.
func exit() -> void:
	_active = false
	_clear_selection()
	set_process_unhandled_input(false)
	_free_gift_previews()


func set_mode(mode: int) -> void:
	if mode != Mode.PAWNS and mode != Mode.GIFTS:
		return
	_mode = mode
	_clear_selection()


## Забравя подредбата и връща изгледите по местата им от началното състояние.
func clear_arrangement(state: GameState) -> void:
	_pawn_cells.clear()
	_gift_cells.clear()
	_free_gift_previews()
	_clear_selection()
	if state == null:
		return
	for pawn_id in _pawn_views.keys():
		var pawn_state := state.get_pawn(StringName(str(pawn_id)))
		if pawn_state != null:
			_move_pawn_view(StringName(str(pawn_id)), pawn_state.cell_id)


## Прилага записаните намерения върху вече стартирано състояние.
## Връща false при невалидна подредба — виж get_last_error().
func apply_to_state(state: GameState) -> bool:
	_last_error = ""
	if state == null:
		_last_error = "липсва GameState"
		return false

	for key in _pawn_cells.keys():
		var pawn_id := StringName(str(key))
		var cell_id: StringName = _pawn_cells[key]
		if not _apply_pawn(state, pawn_id, cell_id):
			return false

	var gift_index: int = 0
	for cell_id in _gift_cells:
		if state.get_gift_at(cell_id) == null:
			state.add_gift(GiftState.create_on_cell(
					cell_id, DEBUG_GIFT_ID_OFFSET + gift_index))
			gift_index += 1

	var check := GameStateInvariantChecker.validate_runtime(state)
	if check.is_invalid():
		_last_error = "%s: %s" % [
			String(check.first_error_code()), check.first_error_message()]
		return false
	return true


func _apply_pawn(state: GameState, pawn_id: StringName, cell_id: StringName) -> bool:
	var pawn := state.get_pawn(pawn_id)
	if pawn == null:
		_last_error = "непозната пионка %s" % pawn_id
		return false
	var player_id: StringName = pawn.get_player_id()

	if Classic15x15Board.is_base_cell_of(player_id, cell_id):
		pawn.place_in_base(cell_id)
		return true

	var route_index: int = Classic15x15Board.player_route_index_of(player_id, cell_id)
	if route_index < 0:
		_last_error = "клетка %s не е по маршрута на %s" % [cell_id, player_id]
		return false

	var zone: int = (
			PawnZone.HOME_STRETCH
			if Classic15x15Board.is_home_stretch_cell_of(player_id, cell_id)
			else PawnZone.MAIN_PATH)
	pawn.set_position(zone, route_index, cell_id)
	return true


# ── Вход ──────────────────────────────────────────────────────────────────────
#
# Едно-единствено _unhandled_input, без PawnView.clicked/Area2D: physics
# picking (Area2D.input_event) и _unhandled_input вървят по различни,
# несинхронизирани тактове в Godot (picking е на физическия тик,
# unhandled_input — веднага при събитието). Опит да се комбинират двата
# (флаг „consume следващия клик") гасеше грешния клик, защото флагът се
# вдигаше след като съответният unhandled_input вече беше минал — кликът
# върху пионка не правеше нищо, а следващият (по клетката) биваше изяден.
# Затова и селекцията на пионка, и посочването на клетка минават оттук.

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _board == null:
		return
	if not _is_primary_press(event):
		return

	if _mode == Mode.PAWNS:
		var pawn_id := _pawn_under_pointer()
		if pawn_id != &"":
			_select_pawn(pawn_id)
			get_viewport().set_input_as_handled()
			return

	var cell_id := _cell_under_pointer()
	if cell_id == &"":
		return
	if _mode == Mode.GIFTS:
		_toggle_gift(cell_id)
	else:
		_place_selected_pawn(cell_id)
	get_viewport().set_input_as_handled()


func _select_pawn(pawn_id: StringName) -> void:
	_clear_selection()
	_selected_pawn_id = pawn_id
	var pawn := _pawn_views.get(pawn_id) as PawnView
	if pawn != null and is_instance_valid(pawn):
		pawn.set_selected(true)


## Най-близката пионка до показалеца в рамките на прага, или &"" ако няма.
## Радиусът е по-малък от този на клетка (cell_id_at_local_position), за да
## не поглъща кликове по съседни празни клетки.
func _pawn_under_pointer() -> StringName:
	var mouse_global: Vector2 = _board.get_global_mouse_position()
	var limit: float = _board.get_tile_display_width() * 0.4
	var best_id: StringName = &""
	var best_distance_sq: float = limit * limit
	for key in _pawn_views.keys():
		var pawn := _pawn_views[key] as PawnView
		if pawn == null or not is_instance_valid(pawn):
			continue
		var distance_sq: float = pawn.global_position.distance_squared_to(mouse_global)
		if distance_sq <= best_distance_sq:
			best_distance_sq = distance_sq
			best_id = StringName(str(key))
	return best_id


func _cell_under_pointer() -> StringName:
	var local_pos: Vector2 = _board.to_local(_board.get_global_mouse_position())
	return _board.cell_id_at_local_position(local_pos)


static func _is_primary_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.device == InputEvent.DEVICE_ID_EMULATION:
			return false
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return false


# ── Намерения + изгледи ───────────────────────────────────────────────────────

func _place_selected_pawn(cell_id: StringName) -> void:
	if _selected_pawn_id == &"":
		return
	_pawn_cells[_selected_pawn_id] = cell_id
	_move_pawn_view(_selected_pawn_id, cell_id)
	_clear_selection()


func _toggle_gift(cell_id: StringName) -> void:
	# Подаръци стоят само на общото трасе (GiftRules / #203).
	if not Classic15x15Board.is_main_loop_cell(cell_id):
		return
	if cell_id in _gift_cells:
		_gift_cells.erase(cell_id)
		_free_gift_preview(cell_id)
		return
	_gift_cells.append(cell_id)
	_add_gift_preview(cell_id)


func _move_pawn_view(pawn_id: StringName, cell_id: StringName) -> void:
	var pawn := _pawn_views.get(pawn_id) as PawnView
	if pawn == null or not is_instance_valid(pawn) or not CellId.is_valid(cell_id):
		return
	pawn.grid_pos = CellId.to_vec(cell_id)
	pawn.z_index = pawn.grid_pos.x + pawn.grid_pos.y + 1
	pawn.set_rest_position(_local_for_node(pawn, cell_id))


func _clear_selection() -> void:
	if _selected_pawn_id == &"":
		return
	var pawn := _pawn_views.get(_selected_pawn_id) as PawnView
	if pawn != null and is_instance_valid(pawn):
		pawn.set_selected(false)
	_selected_pawn_id = &""


func _add_gift_preview(cell_id: StringName) -> void:
	if _gifts_root == null or not is_instance_valid(_gifts_root):
		return
	var preview := GiftView.new()
	preview.name = "DebugGiftPreview_%s" % cell_id
	_gifts_root.add_child(preview)
	preview.setup(
			EventViewBinder.GIFT_TEXTURE_PATH, _board.get_tile_display_width())
	preview.cell_id = cell_id
	preview.grid_pos = CellId.to_vec(cell_id)
	preview.z_index = preview.grid_pos.x + preview.grid_pos.y + 1
	preview.position = _local_for_node(preview, cell_id)
	_gift_previews[cell_id] = preview


func _free_gift_preview(cell_id: StringName) -> void:
	var preview := _gift_previews.get(cell_id) as GiftView
	_gift_previews.erase(cell_id)
	if preview != null and is_instance_valid(preview):
		preview.queue_free()


func _free_gift_previews() -> void:
	for cell_id in _gift_previews.keys():
		var preview := _gift_previews[cell_id] as GiftView
		if preview != null and is_instance_valid(preview):
			preview.queue_free()
	_gift_previews.clear()


## Board cell_id → локална позиция в родителя на node (аналог на
## GameScreen._local_position_for / EventViewBinder._local_for_pawn).
func _local_for_node(node: Node2D, cell_id: StringName) -> Vector2:
	if _board == null or not is_instance_valid(_board):
		return Vector2.ZERO
	var board_local: Vector2 = _board.get_cell_position_by_id(cell_id)
	var global_pos: Vector2 = _board.to_global(board_local)
	var parent_node: Node = node.get_parent()
	if parent_node is Node2D:
		return (parent_node as Node2D).to_local(global_pos)
	return global_pos


## Извиква се от debug панела при натиснат „Start".
func request_start() -> void:
	start_requested.emit()
