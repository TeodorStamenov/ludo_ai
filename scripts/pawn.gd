class_name Pawn
extends Sprite2D

signal clicked(pawn: Pawn)

const BOB_AMPLITUDE := 5.0
const BOB_DURATION := 0.35
const SIZE_RATIO := 0.7

@export var player_id: StringName = &"yellow"
@export var grid_pos: Vector2i = Vector2i.ZERO

## -1 while in base; otherwise index into that player's path.
var path_index: int = -1
var in_base: bool = true
var is_selectable: bool = false
var is_selected: bool = false

var _rest_position: Vector2 = Vector2.ZERO
var _bob_tween: Tween
var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	_base_modulate = modulate
	_ensure_click_area()


func setup(texture_path: String, tile_width_px: float) -> void:
	texture = load(texture_path) as Texture2D
	centered = true
	if texture == null:
		return
	var s: float = (tile_width_px * SIZE_RATIO) / float(texture.get_width())
	scale = Vector2(s, s)
	# Anchor at feet: bottom-center of the sprite sits on the tile center.
	offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	_ensure_click_area()


func set_rest_position(pos: Vector2) -> void:
	_rest_position = pos
	position = pos


func start_bob() -> void:
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


func stop_bob() -> void:
	is_selectable = false
	_stop_bob_tween()
	position = _rest_position


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		modulate = Color(1.45, 1.35, 0.75, 1.0)
	else:
		modulate = _base_modulate


func move_to_local(local_target: Vector2, duration: float = 0.28) -> void:
	_stop_bob_tween()
	is_selectable = false
	set_selected(false)
	var tween := create_tween()
	tween.tween_property(self, "position", local_target, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	_rest_position = local_target


func _stop_bob_tween() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null


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
