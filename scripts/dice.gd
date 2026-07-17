extends Node3D

signal dice_rolled(value: int)

## Rest orientation so that face N points world-up (rss/dice mesh).
## +X=6, -X=1, +Y=4, -Y=3, +Z=2, -Z=5
const FACE_ROTATIONS: Dictionary = {
	1: Vector3(0.0, 0.0, -PI / 2.0),
	2: Vector3(-PI / 2.0, 0.0, 0.0),
	3: Vector3(PI, 0.0, 0.0),
	4: Vector3.ZERO,
	5: Vector3(PI / 2.0, 0.0, 0.0),
	6: Vector3(0.0, 0.0, PI / 2.0),
}

@export var roll_duration: float = 1.15
@export var jump_height: float = 0.85

@onready var visual: Node3D = $Visual
@onready var animation_player: AnimationPlayer = $Visual/AnimationPlayer
@onready var click_body: StaticBody3D = $ClickArea

var is_rolling: bool = false


func _ready() -> void:
	click_body.input_ray_pickable = true
	if not click_body.input_event.is_connected(_on_click_area_input_event):
		click_body.input_event.connect(_on_click_area_input_event)
	_snap_to_face(randi_range(1, 6))


func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		roll()


func roll(forced_value: int = 0) -> void:
	if is_rolling:
		return

	var value: int = forced_value if FACE_ROTATIONS.has(forced_value) else randi_range(1, 6)
	is_rolling = true
	await _play_toss_animation(value)
	is_rolling = false
	dice_rolled.emit(value)


func _snap_to_face(value: int) -> void:
	visual.position = Vector3.ZERO
	visual.rotation = FACE_ROTATIONS[value] as Vector3


func _play_toss_animation(value: int) -> void:
	var target: Vector3 = FACE_ROTATIONS[value] as Vector3
	var duration: float = roll_duration
	var peak: float = jump_height * randf_range(0.9, 1.15)

	# Several full turns while airborne, then settle on the result face.
	var spins: Vector3 = Vector3(
		TAU * randf_range(2.5, 4.0),
		TAU * randf_range(1.5, 3.0),
		TAU * randf_range(2.5, 4.0)
	)
	if randf() < 0.5:
		spins.x *= -1.0
	if randf() < 0.5:
		spins.y *= -1.0
	if randf() < 0.5:
		spins.z *= -1.0

	var start_rot: Vector3 = visual.rotation
	var end_rot: Vector3 = target + spins
	var wobble: float = randf_range(0.12, 0.22)

	visual.position = Vector3.ZERO

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Spin for the whole toss, easing out so it "catches" the final face.
	tween.tween_property(visual, "rotation", end_rot, duration)\
		.from(start_rot)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# Jump up (first half), then fall + soft bounce (second half).
	var up_time: float = duration * 0.42
	var down_time: float = duration - up_time
	tween.tween_property(visual, "position:y", peak, up_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", 0.0, down_time)\
		.set_delay(up_time)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

	# Light sideways drift so it doesn't feel glued to one point.
	var drift_x: float = randf_range(-wobble, wobble)
	var drift_z: float = randf_range(-wobble, wobble)
	tween.tween_property(visual, "position:x", drift_x, up_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:z", drift_z, up_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:x", 0.0, down_time)\
		.set_delay(up_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "position:z", 0.0, down_time)\
		.set_delay(up_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	await tween.finished
	_snap_to_face(value)
