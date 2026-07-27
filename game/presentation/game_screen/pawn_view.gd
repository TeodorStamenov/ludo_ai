class_name PawnView
extends Sprite2D
## Визуален представител на една пионка (docs/V1_ARCHITECTURE.md §6.3, Етап C).
##
## Съдържа само presentation данни: pawn_id, визуален asset/skin,
## selected / valid-move / move / home (sleep) анимации и hit target.
## Логическите in_base, path_index, shield и valid move живеят в PawnState.
##
## animation_finished(kind) се емитира след еднократни move/home анимации
## за AnimationQueue (#168 / #169). Loop cues (valid-move, selected) не го емитират.

signal clicked(pawn: PawnView)
signal animation_finished(kind: StringName)

const KIND_MOVE := &"move"
const KIND_HOME := &"home"

const BOB_AMPLITUDE := 5.0
const BOB_DURATION := 0.35
const SELECTED_SCALE := 1.12
const SELECTED_PULSE_DURATION := 0.45
const SELECTED_MODULATE := Color(1.45, 1.35, 0.75, 1.0)
const MOVE_HOP_PX := 10.0
const HOME_DURATION := 0.55
const HOME_SCALE_MIN := 0.82
const HOME_MODULATE := Color(0.88, 0.90, 1.0, 0.85)
const SIZE_RATIO := 0.7

## Стабилен идентификатор — същият StringName като в PawnState (PawnId формат).
var pawn_id: StringName = &""

@export var player_id: StringName = &"yellow"
@export var grid_pos: Vector2i = Vector2i.ZERO

var is_selectable: bool = false
var is_selected: bool = false

var _rest_position: Vector2 = Vector2.ZERO
var _bob_tween: Tween
var _select_tween: Tween
var _action_tween: Tween
var _base_modulate: Color = Color.WHITE
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_modulate = modulate
	_base_scale = scale
	_ensure_click_area()


func setup(texture_path: String, tile_width_px: float) -> void:
	texture = load(texture_path) as Texture2D
	centered = true
	if texture == null:
		return
	var s: float = (tile_width_px * SIZE_RATIO) / float(texture.get_width())
	scale = Vector2(s, s)
	_base_scale = scale
	# Anchor at feet: bottom-center of the sprite sits on the tile center.
	offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	_ensure_click_area()


func set_rest_position(pos: Vector2) -> void:
	_rest_position = pos
	position = pos


## Valid-move cue: gentle vertical bob while the pawn is selectable.
func show_valid_move() -> void:
	is_selectable = true
	_stop_bob_tween()
	position = _rest_position
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "position:y", _rest_position.y - BOB_AMPLITUDE, BOB_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", _rest_position.y + BOB_AMPLITUDE, BOB_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func hide_valid_move() -> void:
	is_selectable = false
	_stop_bob_tween()
	position = _rest_position


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


## Ход по дъската: лек hop към local_target, после rest + animation_finished.
func move_to_local(local_target: Vector2, duration: float = 0.28) -> void:
	_prepare_for_action()
	_stop_action_tween()
	var start: Vector2 = position
	var mid: Vector2 = (start + local_target) * 0.5
	mid.y -= MOVE_HOP_PX
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
	_rest_position = local_target
	position = local_target
	_action_tween = null
	animation_finished.emit(KIND_MOVE)


## Меко „прибиране вкъщи да подремне“ (PawnSentHome) — shrink + settle в базата.
func play_home_to(local_target: Vector2, duration: float = HOME_DURATION) -> void:
	_prepare_for_action()
	_stop_action_tween()
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
	animation_finished.emit(KIND_HOME)


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
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
