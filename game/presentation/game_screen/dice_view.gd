class_name DiceView
extends Node3D
## Визуализация на зара (docs/V1_ARCHITECTURE.md §6.4, Етап C).
##
## Пренесен от scripts/dice.gd. Съдържа само presentation:
##   - получава готов резултат 1–6 и проиграва анимация към това лице;
##   - козметични вариации (spin, wobble, jump) през PresentationRandomSource;
##   - hit target емитира roll_requested — не хвърля сам.
##
## Не генерира gameplay случайността (#160). Целево (#161): стойността идва
## от DiceRolledEvent / domain през GamePresenter / AnimationQueue.

signal dice_rolled(value: int)
signal roll_requested

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

## Козметичен RNG — никога не се подава към GameEngine / MatchSession.
var cosmetic_rng: PresentationRandomSource = PresentationRandomSource.new()

var is_rolling: bool = false


func _ready() -> void:
	click_body.input_ray_pickable = true
	if not click_body.input_event.is_connected(_on_click_area_input_event):
		click_body.input_event.connect(_on_click_area_input_event)
	_snap_to_face(cosmetic_rng.next_int(1, 6))


## Задава presentation RNG (напр. от GamePresenter). Null → нов randomized instance.
func set_cosmetic_rng(rng: PresentationRandomSource) -> void:
	cosmetic_rng = rng if rng != null else PresentationRandomSource.new()


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
		roll_requested.emit()


## Проиграва анимация към даденото лице (1–6). Невалидна стойност → no-op.
func roll(value: int) -> void:
	if is_rolling:
		return
	if not DiceState.is_face_value(value):
		return

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
	var peak: float = jump_height * cosmetic_rng.next_float(0.9, 1.15)

	var spins: Vector3 = Vector3(
		TAU * cosmetic_rng.next_float(2.5, 4.0),
		TAU * cosmetic_rng.next_float(1.5, 3.0),
		TAU * cosmetic_rng.next_float(2.5, 4.0)
	)
	if cosmetic_rng.chance(0.5):
		spins.x *= -1.0
	if cosmetic_rng.chance(0.5):
		spins.y *= -1.0
	if cosmetic_rng.chance(0.5):
		spins.z *= -1.0

	var start_rot: Vector3 = visual.rotation
	var end_rot: Vector3 = target + spins
	var wobble: float = cosmetic_rng.next_float(0.12, 0.22)

	visual.position = Vector3.ZERO

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(visual, "rotation", end_rot, duration)\
		.from(start_rot)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	var up_time: float = duration * 0.42
	var down_time: float = duration - up_time
	tween.tween_property(visual, "position:y", peak, up_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", 0.0, down_time)\
		.set_delay(up_time)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

	var drift_x: float = cosmetic_rng.next_float(-wobble, wobble)
	var drift_z: float = cosmetic_rng.next_float(-wobble, wobble)
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
