class_name PawnView
extends Sprite2D
## Визуален представител на една пионка (docs/V1_ARCHITECTURE.md §6.3, Етап C).
##
## Съдържа само presentation данни: pawn_id, визуален asset/skin,
## selected / valid-move / move / stack / home (sleep) / finish анимации,
## colorblind marker и hit target за mouse + touch (GAP-011). Логическите
## in_base, path_index, shield и valid move живеят в PawnState.
##
## animation_finished(kind) се емитира след еднократни move/exit/stack/home/finish.
## AnimationFinishedGate (#169) го чака преди следващия event в опашката.
## Loop cues (valid-move, selected) не го емитират.
##
## Colorblind marker (V1_GAME_DESIGN): форма по seat, не само цвят.
## Видим само при set_colorblind_mode(true); икона може да се подаде от
## AnimalDefinition.colorblind_icon (иначе procedural shape по player_id).

signal clicked(pawn: PawnView)
signal animation_finished(kind: StringName)

const KIND_MOVE := &"move"
const KIND_HOME := &"home"
const KIND_STACK := &"stack"
const KIND_FINISH := &"finish"

const BOB_AMPLITUDE := 5.0
const BOB_DURATION := 0.35
const SELECTED_SCALE := 1.12
const SELECTED_PULSE_DURATION := 0.45
const SELECTED_MODULATE := Color(1.45, 1.35, 0.75, 1.0)
const MOVE_HOP_PX := 10.0
## По-висок hop за клетка, на която в момента стои друга пионка или подарък —
## визуален "прескок" ефект вместо плъзгане през/върху заетата клетка (bug report).
const JUMP_OVER_HOP_PX := 24.0
## Продължителност на един hop между съседни клетки (YEL-040 / yellow prototype).
const STEP_DURATION := 0.18
## Hop от база към spawn (YEL-030 / yellow prototype move_to_local).
const EXIT_DURATION := 0.28
const HOME_DURATION := 0.55
const HOME_SCALE_MIN := 0.82
const HOME_MODULATE := Color(0.88, 0.90, 1.0, 0.85)
## Изометричен offset за две пионки на една клетка (#174) — arriving +, resident −.
const STACK_OFFSET := Vector2(12.0, -7.0)
const STACK_DURATION := 0.2
const STACK_PULSE_SCALE := 1.08
## Меко прибиране в центъра (#176) — hop + топъл pulse.
const FINISH_DURATION := 0.42
const FINISH_SCALE_PEAK := 1.16
const FINISH_MODULATE := Color(1.32, 1.22, 0.78, 1.0)
const SIZE_RATIO := 0.7

const MARKER_NODE_NAME := &"ColorblindMarker"
const MARKER_PX := 28
const MARKER_OUTLINE := Color(0.08, 0.08, 0.10, 1.0)
const MARKER_FILL := Color(0.96, 0.96, 0.94, 1.0)

## Стабилен идентификатор — същият StringName като в PawnState (PawnId формат).
var pawn_id: StringName = &""

@export var player_id: StringName = PlayerId.YELLOW:
	set(value):
		player_id = value
		if is_inside_tree():
			_refresh_colorblind_marker()

@export var grid_pos: Vector2i = Vector2i.ZERO

var is_selectable: bool = false
var is_selected: bool = false
## True докато move/exit/stack/home/finish tween тече — EventViewBinder ползва за snap fallback.
var is_moving: bool = false
## Presentation-only: в купчина с друга пионка (#174). Domain stack е в GameState.
var is_stacked: bool = false
## Партньор в купчината (PawnId); празен когато не е stacked.
var stack_partner_id: StringName = &""

var _rest_position: Vector2 = Vector2.ZERO
var _stack_offset: Vector2 = Vector2.ZERO
var _bob_tween: Tween
var _select_tween: Tween
var _action_tween: Tween
var _base_modulate: Color = Color.WHITE
var _base_scale: Vector2 = Vector2.ONE

var _colorblind_mode: bool = false
var _colorblind_icon: Texture2D = null
var _marker: Sprite2D = null

## Кеш на procedural форми по player_id — споделен между всички PawnView.
static var _marker_shape_cache: Dictionary = {}


func _ready() -> void:
	_base_modulate = modulate
	_base_scale = scale
	_ensure_click_area()
	_ensure_colorblind_marker()


## sprite идва от AnimalDefinition.sprite (content/animals/*.tres; #233) —
## Presentation не хардкодва пътища към текстури.
func setup(sprite: Texture2D, tile_width_px: float) -> void:
	texture = sprite
	centered = true
	if texture == null:
		return
	var s: float = (tile_width_px * SIZE_RATIO) / float(texture.get_width())
	scale = Vector2(s, s)
	_base_scale = scale
	# Anchor at feet: bottom-center of the sprite sits on the tile center.
	offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	_ensure_click_area()
	_refresh_colorblind_marker()


## Показва/скрива colorblind badge-а (SettingsService.colorblind_mode).
func set_colorblind_mode(enabled: bool) -> void:
	_colorblind_mode = enabled
	_ensure_colorblind_marker()
	_marker.visible = enabled
	if enabled:
		_refresh_colorblind_marker()


## Опционална икона от AnimalDefinition; null → procedural форма по player_id.
func set_colorblind_icon(icon: Texture2D) -> void:
	_colorblind_icon = icon
	_refresh_colorblind_marker()


func set_rest_position(pos: Vector2) -> void:
	_rest_position = pos
	position = _posed_position()


## Valid-move cue: gentle vertical bob while the pawn is selectable.
func show_valid_move() -> void:
	is_selectable = true
	_stop_bob_tween()
	var posed: Vector2 = _posed_position()
	position = posed
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "position:y", posed.y - BOB_AMPLITUDE, BOB_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", posed.y + BOB_AMPLITUDE, BOB_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func hide_valid_move() -> void:
	is_selectable = false
	_stop_bob_tween()
	position = _posed_position()


## Alias за жълтия прототип (scripts/ludo_game.gd).
func start_bob() -> void:
	show_valid_move()


## Alias за жълтия прототип (scripts/ludo_game.gd).
func stop_bob() -> void:
	hide_valid_move()


func set_selected(selected: bool) -> void:
	is_selected = selected
	_stop_select_tween()
	if selected:
		modulate = SELECTED_MODULATE
		scale = _base_scale
		_select_tween = create_tween()
		_select_tween.set_loops()
		_select_tween.tween_property(self, "scale", _base_scale * SELECTED_SCALE, SELECTED_PULSE_DURATION)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		_select_tween.tween_property(self, "scale", _base_scale, SELECTED_PULSE_DURATION)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	else:
		modulate = _base_modulate
		scale = _base_scale


## Instant apply от PawnMovedEvent (#167). Клетъчна анимация е #172.
func present_pawn_moved(event: PawnMovedEvent, local_target: Vector2) -> void:
	if event == null or not event.is_valid():
		return
	_apply_cell_pose(event.to_cell_id, local_target)


## Hop клетка по клетка след приет MovePawnCommand (#172 / YEL-040).
## step_cell_ids / step_locals са exclusive-from → inclusive-to по маршрута.
## step_jump_over[i] == true → по-висок hop за тази стъпка (клетката вече е
## заета от друга пионка/подарък — визуален "прескок" вместо плъзгане отгоре).
## Емитира animation_finished(KIND_MOVE) веднъж след последната клетка (#169).
func present_pawn_moved_animated(
		event: PawnMovedEvent,
		step_cell_ids: Array[StringName],
		step_locals: Array[Vector2],
		step_jump_over: Array[bool] = []
) -> void:
	if event == null or not event.is_valid():
		return
	var count: int = mini(step_cell_ids.size(), step_locals.size())
	if count <= 0:
		return
	_prepare_for_action()
	_stop_action_tween()
	is_moving = true
	for i in count:
		var cell_id: StringName = step_cell_ids[i]
		if CellId.is_valid(cell_id):
			grid_pos = CellId.to_vec(cell_id)
			z_index = grid_pos.x + grid_pos.y + 1
		var is_jump: bool = i < step_jump_over.size() and step_jump_over[i]
		var hop_height: float = JUMP_OVER_HOP_PX if is_jump else MOVE_HOP_PX
		await _tween_hop_to(step_locals[i], STEP_DURATION, hop_height)
	var final_local: Vector2 = step_locals[count - 1]
	_rest_position = final_local
	position = final_local
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_MOVE)


## Instant apply от PawnExitedBaseEvent (#167). Анимираният hop е #173.
func present_pawn_exited_base(event: PawnExitedBaseEvent, local_target: Vector2) -> void:
	if event == null or not event.is_valid():
		return
	_apply_cell_pose(event.spawn_cell_id, local_target)


## Hop от база към spawn след приет MovePawnCommand (#173 / YEL-030).
## is_jump_over == true → по-висок hop (spawn клетката вече е заета).
## Емитира animation_finished(KIND_MOVE) след кацане на spawn (#169).
func present_pawn_exited_base_animated(
		event: PawnExitedBaseEvent,
		local_target: Vector2,
		is_jump_over: bool = false
) -> void:
	if event == null or not event.is_valid():
		return
	_prepare_for_action()
	_stop_action_tween()
	if CellId.is_valid(event.spawn_cell_id):
		grid_pos = CellId.to_vec(event.spawn_cell_id)
		z_index = grid_pos.x + grid_pos.y + 1
	is_moving = true
	await _tween_hop_to(local_target, EXIT_DURATION, JUMP_OVER_HOP_PX if is_jump_over else MOVE_HOP_PX)
	_rest_position = local_target
	position = local_target
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_MOVE)


## Instant apply от PawnSentHomeEvent (#167). Мекото „вкъщи“ tween е #175.
func present_pawn_sent_home(event: PawnSentHomeEvent, local_target: Vector2) -> void:
	if event == null or not event.is_valid():
		return
	_apply_cell_pose(event.base_cell_id, local_target)


## Меко „прибиране вкъщи да подремне“ след capture (#175 / V1_GAME_DESIGN §1).
## Емитира animation_finished(KIND_HOME) след settle в базата (#169).
func present_pawn_sent_home_animated(
		event: PawnSentHomeEvent,
		local_target: Vector2
) -> void:
	if event == null or not event.is_valid():
		return
	if CellId.is_valid(event.base_cell_id):
		grid_pos = CellId.to_vec(event.base_cell_id)
		z_index = grid_pos.x + grid_pos.y + 1
	await play_home_to(local_target)


## Instant apply от PawnFinishedEvent (#167). Флаг-превключване на място
## (V1.1) — pulse-ът е #176.
func present_pawn_finished(event: PawnFinishedEvent, local_target: Vector2) -> void:
	if event == null or not event.is_valid():
		return
	_apply_cell_pose(event.final_cell_id, local_target)


## Pulse на място, без движение (V1.1 / #176 / V1_GAME_DESIGN §3.2).
## Емитира animation_finished(KIND_FINISH) след settle (#169).
func present_pawn_finished_animated(
		event: PawnFinishedEvent,
		local_target: Vector2
) -> void:
	if event == null or not event.is_valid():
		return
	if CellId.is_valid(event.final_cell_id):
		grid_pos = CellId.to_vec(event.final_cell_id)
		z_index = grid_pos.x + grid_pos.y + 1
	await play_finish_to(local_target)


## Capture cue (#167). Позицията на взетата пионка идва от PawnSentHome.
func present_pawn_captured(_event: PawnCapturedEvent) -> void:
	pass


## Instant stack offset от PawnStackFormedEvent (#174).
func present_stack_formed(event: PawnStackFormedEvent, is_arriving: bool) -> void:
	if event == null or not event.is_valid():
		return
	_prepare_for_action()
	_stop_action_tween()
	_apply_stack_membership(event, is_arriving)
	position = _posed_position()


## Settle към stack offset след PawnMoved/PawnExitedBase (#174).
## Емитира animation_finished(KIND_STACK) след settle (#169).
func present_stack_formed_animated(
		event: PawnStackFormedEvent,
		is_arriving: bool
) -> void:
	if event == null or not event.is_valid():
		return
	_prepare_for_action()
	_stop_action_tween()
	_apply_stack_membership(event, is_arriving)
	var target: Vector2 = _posed_position()
	is_moving = true
	var pulse: Vector2 = _base_scale * STACK_PULSE_SCALE
	_action_tween = create_tween()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "position", target, STACK_DURATION)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "scale", pulse, STACK_DURATION * 0.45)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.chain()
	_action_tween.tween_property(self, "scale", _base_scale, STACK_DURATION * 0.55)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await _action_tween.finished
	position = target
	scale = _base_scale
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_STACK)


## Instant clear на stack offset (#174) — оставащата пионка на центъра на клетката.
func present_stack_dissolved() -> void:
	_prepare_for_action()
	_stop_action_tween()
	_clear_stack_membership()
	position = _posed_position()


## Разпадане: tween към центъра на клетката (#174). KIND_STACK след settle.
func present_stack_dissolved_animated() -> void:
	_prepare_for_action()
	_stop_action_tween()
	_clear_stack_membership()
	var target: Vector2 = _posed_position()
	is_moving = true
	_action_tween = create_tween()
	_action_tween.tween_property(self, "position", target, STACK_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await _action_tween.finished
	position = target
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_STACK)


## Напускаща пионка: маха stack membership, запазва текущата позиция за hop.
func clear_stack_for_departure() -> void:
	_clear_stack_membership()


func _posed_position() -> Vector2:
	return _rest_position + _stack_offset


func _apply_stack_membership(event: PawnStackFormedEvent, is_arriving: bool) -> void:
	is_stacked = true
	if is_arriving:
		stack_partner_id = event.resident_pawn_id
		_stack_offset = STACK_OFFSET
	else:
		stack_partner_id = event.arriving_pawn_id
		_stack_offset = -STACK_OFFSET
	if CellId.is_valid(event.cell_id):
		grid_pos = CellId.to_vec(event.cell_id)
	var base_z: int = grid_pos.x + grid_pos.y + 1
	z_index = base_z + (1 if is_arriving else 0)


func _clear_stack_membership() -> void:
	is_stacked = false
	stack_partner_id = &""
	_stack_offset = Vector2.ZERO
	z_index = grid_pos.x + grid_pos.y + 1


func _apply_cell_pose(cell_id: StringName, local_target: Vector2) -> void:
	_prepare_for_action()
	_stop_action_tween()
	_clear_stack_membership()
	if CellId.is_valid(cell_id):
		grid_pos = CellId.to_vec(cell_id)
		z_index = grid_pos.x + grid_pos.y + 1
	set_rest_position(local_target)


## Единичен hop към local_target, после rest + animation_finished.
## За клетъчна поредица ползвай present_pawn_moved_animated (#172).
func move_to_local(local_target: Vector2, duration: float = 0.28) -> void:
	_prepare_for_action()
	_stop_action_tween()
	is_moving = true
	await _tween_hop_to(local_target, duration)
	_rest_position = local_target
	position = local_target
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_MOVE)


## Един hop tween без emit — междинна стъпка или сграден блок за move_to_local.
func _tween_hop_to(local_target: Vector2, duration: float, hop_height_px: float = MOVE_HOP_PX) -> void:
	var start: Vector2 = position
	var mid: Vector2 = (start + local_target) * 0.5
	mid.y -= hop_height_px
	var hop_in: float = duration * 0.45
	var hop_out: float = duration * 0.55
	_action_tween = create_tween()
	_action_tween.tween_property(self, "position", mid, hop_in)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "position", local_target, hop_out)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	await _action_tween.finished


## Меко „прибиране вкъщи да подремне“ (PawnSentHome) — shrink + settle в базата.
func play_home_to(local_target: Vector2, duration: float = HOME_DURATION) -> void:
	_prepare_for_action()
	_stop_action_tween()
	is_moving = true
	var shrink_time: float = duration * 0.45
	var settle_time: float = duration * 0.55
	var mid: Vector2 = position.lerp(local_target, 0.55)
	_action_tween = create_tween()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "position", mid, shrink_time)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "modulate", HOME_MODULATE, shrink_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "scale", _base_scale * HOME_SCALE_MIN, shrink_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.chain()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "position", local_target, settle_time)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(self, "scale", _base_scale, settle_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "modulate", _base_modulate, settle_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await _action_tween.finished
	_rest_position = local_target
	position = local_target
	scale = _base_scale
	modulate = _base_modulate
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_HOME)


## Меко прибиране в центъра (PawnFinished) — hop + топъл pulse (#176).
func play_finish_to(local_target: Vector2, duration: float = FINISH_DURATION) -> void:
	_prepare_for_action()
	_stop_action_tween()
	is_moving = true
	var hop_time: float = duration * 0.55
	var settle_time: float = duration * 0.45
	var start: Vector2 = position
	var mid: Vector2 = (start + local_target) * 0.5
	mid.y -= MOVE_HOP_PX * 1.4
	var peak: Vector2 = _base_scale * FINISH_SCALE_PEAK
	_action_tween = create_tween()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "position", mid, hop_time * 0.45)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "scale", peak, hop_time * 0.45)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "modulate", FINISH_MODULATE, hop_time * 0.45)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.chain()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "position", local_target, hop_time * 0.55)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	_action_tween.chain()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "scale", _base_scale, settle_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "modulate", _base_modulate, settle_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await _action_tween.finished
	_rest_position = local_target
	position = local_target
	scale = _base_scale
	modulate = _base_modulate
	_action_tween = null
	is_moving = false
	animation_finished.emit(KIND_FINISH)


func _prepare_for_action() -> void:
	_stop_bob_tween()
	is_selectable = false
	if is_selected:
		set_selected(false)
	else:
		_stop_select_tween()
		modulate = _base_modulate
		scale = _base_scale


func _stop_bob_tween() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null


func _stop_select_tween() -> void:
	if _select_tween != null and _select_tween.is_valid():
		_select_tween.kill()
	_select_tween = null


func _stop_action_tween() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = null
	is_moving = false


func _ensure_click_area() -> void:
	var area := get_node_or_null("ClickArea") as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "ClickArea"
		area.input_pickable = true
		add_child(area)
		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		area.add_child(shape_node)

	var shape_node := area.get_node("CollisionShape2D") as CollisionShape2D
	var rect := RectangleShape2D.new()
	if texture != null:
		rect.size = texture.get_size()
		shape_node.position = offset
	else:
		rect.size = Vector2(64, 64)
		shape_node.position = Vector2.ZERO
	shape_node.shape = rect

	if not area.input_event.is_connected(_on_click_area_input_event):
		area.input_event.connect(_on_click_area_input_event)


func _on_click_area_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if _is_primary_press(event):
		clicked.emit(self)


## Primary press: native touch, or real mouse left-click.
## Emulated mouse from touch (device == DEVICE_ID_EMULATION) is ignored so a
## single finger tap does not emit clicked twice when emulate_mouse_from_touch
## is on (Godot default).
static func _is_primary_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.device == InputEvent.DEVICE_ID_EMULATION:
			return false
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return false


func _ensure_colorblind_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		return
	_marker = get_node_or_null(NodePath(String(MARKER_NODE_NAME))) as Sprite2D
	if _marker == null:
		_marker = Sprite2D.new()
		_marker.name = String(MARKER_NODE_NAME)
		_marker.centered = true
		_marker.z_index = 2
		add_child(_marker)
	_marker.visible = _colorblind_mode
	_refresh_colorblind_marker()


func _refresh_colorblind_marker() -> void:
	if _marker == null or not is_instance_valid(_marker):
		return
	if _colorblind_icon != null:
		_marker.texture = _colorblind_icon
	else:
		_marker.texture = _shape_texture_for(player_id)
	_marker.position = _marker_local_position()


func _marker_local_position() -> Vector2:
	var tex_h: float = 64.0
	var tex_w: float = 64.0
	if texture != null:
		tex_h = float(texture.get_height())
		tex_w = float(texture.get_width())
	# Near the head, slightly to the side — readable when pawns stack.
	return offset + Vector2(tex_w * 0.28, -tex_h * 0.42)


static func _shape_texture_for(for_player_id: StringName) -> Texture2D:
	var key: StringName = for_player_id if PlayerId.is_valid(for_player_id) else PlayerId.YELLOW
	if _marker_shape_cache.has(key):
		return _marker_shape_cache[key] as Texture2D
	var img := Image.create(MARKER_PX, MARKER_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match key:
		PlayerId.GREEN:
			_fill_circle(img)
		PlayerId.ORANGE:
			_fill_square(img)
		PlayerId.YELLOW:
			_fill_triangle(img)
		PlayerId.CYAN:
			_fill_diamond(img)
		_:
			_fill_circle(img)
	var tex := ImageTexture.create_from_image(img)
	_marker_shape_cache[key] = tex
	return tex


static func _fill_circle(img: Image) -> void:
	var cx: float = (MARKER_PX - 1) * 0.5
	var cy: float = (MARKER_PX - 1) * 0.5
	var outer_r: float = MARKER_PX * 0.42
	var inner_r: float = outer_r - 2.5
	for y in MARKER_PX:
		for x in MARKER_PX:
			var d: float = Vector2(float(x) - cx, float(y) - cy).length()
			if d <= inner_r:
				img.set_pixel(x, y, MARKER_FILL)
			elif d <= outer_r:
				img.set_pixel(x, y, MARKER_OUTLINE)


static func _fill_square(img: Image) -> void:
	var margin: int = 4
	var inset: int = 2
	for y in range(margin, MARKER_PX - margin):
		for x in range(margin, MARKER_PX - margin):
			var on_edge: bool = (
					x < margin + inset
					or x >= MARKER_PX - margin - inset
					or y < margin + inset
					or y >= MARKER_PX - margin - inset
			)
			img.set_pixel(x, y, MARKER_OUTLINE if on_edge else MARKER_FILL)


static func _fill_triangle(img: Image) -> void:
	var cx: float = (MARKER_PX - 1) * 0.5
	var top := Vector2(cx, 3.0)
	var bl := Vector2(3.0, float(MARKER_PX - 4))
	var br := Vector2(float(MARKER_PX - 4), float(MARKER_PX - 4))
	for y in MARKER_PX:
		for x in MARKER_PX:
			var p := Vector2(float(x), float(y))
			if not _point_in_triangle(p, top, bl, br):
				continue
			var edge_d: float = minf(
					_dist_to_segment(p, top, bl),
					minf(_dist_to_segment(p, bl, br), _dist_to_segment(p, br, top))
			)
			img.set_pixel(x, y, MARKER_OUTLINE if edge_d < 2.2 else MARKER_FILL)


static func _fill_diamond(img: Image) -> void:
	var cx: float = (MARKER_PX - 1) * 0.5
	var cy: float = (MARKER_PX - 1) * 0.5
	var outer_r: float = MARKER_PX * 0.42
	var inner_r: float = outer_r - 2.5
	for y in MARKER_PX:
		for x in MARKER_PX:
			var d: float = absf(float(x) - cx) + absf(float(y) - cy)
			if d <= inner_r:
				img.set_pixel(x, y, MARKER_FILL)
			elif d <= outer_r:
				img.set_pixel(x, y, MARKER_OUTLINE)


static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0: Vector2 = c - a
	var v1: Vector2 = b - a
	var v2: Vector2 = p - a
	var dot00: float = v0.dot(v0)
	var dot01: float = v0.dot(v1)
	var dot02: float = v0.dot(v2)
	var dot11: float = v1.dot(v1)
	var dot12: float = v1.dot(v2)
	var inv: float = 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u: float = (dot11 * dot02 - dot01 * dot12) * inv
	var v: float = (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and (u + v) <= 1.0


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
