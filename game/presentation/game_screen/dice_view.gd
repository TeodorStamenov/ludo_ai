class_name DiceView
extends Node3D
## Визуализация на зара (docs/V1_ARCHITECTURE.md §6.4, Етап C).
##
## Пренесен от scripts/dice.gd. Съдържа само presentation:
##   - получава DiceRolledEvent / лице 1–6 и проиграва анимация към това лице;
##   - запазва шестте крайни анимации roll_1…roll_6 (#162) в AnimationLibrary;
##   - козметични вариации (spin, wobble, jump) през PresentationRandomSource;
##   - hit target емитира roll_requested — не хвърля сам.
##
## Не генерира gameplay случайността (#160). Резултатът идва от domain чрез
## DiceRolledEvent (#161) — GamePresenter / AnimationQueue викат
## present_dice_rolled().
##
## Debug бутоните 1–6 (#163) не са част от този node: живеят в Game HUD /
## прототипния UI и минават през DebugDiceAdapter (само debug build).

signal dice_rolled(value: int)
signal roll_requested
signal animation_finished(kind: StringName)

const KIND_ROLL := &"roll"

## Имена на шестте крайни анимации в animations/dice_rolls.tres (#162).
const ROLL_ANIMATIONS: Dictionary = {
	1: &"roll_1",
	2: &"roll_2",
	3: &"roll_3",
	4: &"roll_4",
	5: &"roll_5",
	6: &"roll_6",
}

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
	_ensure_roll_animation_slots()
	_snap_to_face(cosmetic_rng.next_int(1, 6))


## Задава presentation RNG (напр. от GamePresenter). Null → нов randomized instance.
func set_cosmetic_rng(rng: PresentationRandomSource) -> void:
	cosmetic_rng = rng if rng != null else PresentationRandomSource.new()


## Име на крайната анимация за лице 1–6 (roll_1…roll_6).
static func roll_animation_name(face: int) -> StringName:
	return ROLL_ANIMATIONS.get(face, &"") as StringName


func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	# 3D picking ползва emulate_mouse_from_touch — не филтрираме DEVICE_ID_EMULATION
	# (за разлика от PawnView/Area2D, където идват и двата event-а).
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			roll_requested.emit()
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		roll_requested.emit()


## Instant face update без toss анимация — EventViewBinder / sync gate (#167).
## Animated present_dice_rolled() е за #168 (await animation_finished).
func apply_dice_rolled(event: DiceRolledEvent) -> void:
	if event == null or not event.is_valid():
		return
	_snap_to_face(event.value)
	dice_rolled.emit(event.value)


## Проиграва анимация от DiceRolledEvent (#161). Невалидно / null → no-op.
## AnimationQueue (#168) чака animation_finished(KIND_ROLL) след края.
func present_dice_rolled(event: DiceRolledEvent) -> void:
	if event == null or not event.is_valid():
		return
	await roll(event.value)


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
	animation_finished.emit(KIND_ROLL)


func _snap_to_face(value: int) -> void:
	visual.position = Vector3.ZERO
	visual.rotation = FACE_ROTATIONS[value] as Vector3


## Гарантира, че library-то държи шестте именувани крайни анимации (#162).
func _ensure_roll_animation_slots() -> void:
	var lib: AnimationLibrary = _dice_rolls_library()
	if lib == null:
		return
	for face: int in ROLL_ANIMATIONS.keys():
		var anim_name: StringName = ROLL_ANIMATIONS[face] as StringName
		if not lib.has_animation(anim_name):
			lib.add_animation(anim_name, _make_rest_pose_animation(face))


func _dice_rolls_library() -> AnimationLibrary:
	var lib_names: PackedStringArray = animation_player.get_animation_library_list()
	if lib_names.is_empty():
		return null
	return animation_player.get_animation_library(lib_names[0])


func _play_toss_animation(value: int) -> void:
	var anim_name: StringName = roll_animation_name(value)
	var lib: AnimationLibrary = _dice_rolls_library()
	if lib == null or anim_name == &"":
		_snap_to_face(value)
		return

	var anim: Animation = _make_roll_animation(value)
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, anim)

	if animation_player.is_playing():
		animation_player.stop()
	animation_player.play(anim_name)
	await animation_player.animation_finished
	_snap_to_face(value)


## Крайна поза за лицето — минимална анимация, която държи slot-а валиден.
func _make_rest_pose_animation(value: int) -> Animation:
	var anim := Animation.new()
	anim.length = 0.01
	var target: Vector3 = FACE_ROTATIONS[value] as Vector3
	var rot_track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot_track, NodePath(".:rotation"))
	anim.value_track_set_update_mode(rot_track, Animation.UPDATE_CONTINUOUS)
	anim.track_insert_key(rot_track, 0.0, target)
	var pos_track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos_track, NodePath(".:position"))
	anim.value_track_set_update_mode(pos_track, Animation.UPDATE_CONTINUOUS)
	anim.track_insert_key(pos_track, 0.0, Vector3.ZERO)
	return anim


## Пълна toss анимация към лицето; крайната ориентация е FACE_ROTATIONS[value].
## TYPE_VALUE върху euler rotation запазва многооборотния spin (quaternion slerp не го прави).
func _make_roll_animation(value: int) -> Animation:
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
	var up_time: float = duration * 0.42
	var drift_x: float = cosmetic_rng.next_float(-wobble, wobble)
	var drift_z: float = cosmetic_rng.next_float(-wobble, wobble)

	var anim := Animation.new()
	anim.length = duration

	var rot_track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot_track, NodePath(".:rotation"))
	anim.value_track_set_update_mode(rot_track, Animation.UPDATE_CONTINUOUS)
	anim.track_set_interpolation_type(rot_track, Animation.INTERPOLATION_CUBIC)
	anim.track_insert_key(rot_track, 0.0, start_rot)
	anim.track_insert_key(rot_track, duration, end_rot)

	var pos_track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos_track, NodePath(".:position"))
	anim.value_track_set_update_mode(pos_track, Animation.UPDATE_CONTINUOUS)
	anim.track_set_interpolation_type(pos_track, Animation.INTERPOLATION_CUBIC)
	anim.track_insert_key(pos_track, 0.0, Vector3.ZERO)
	anim.track_insert_key(pos_track, up_time, Vector3(drift_x, peak, drift_z))
	# Soft bounce approximation before settling.
	anim.track_insert_key(
		pos_track,
		up_time + (duration - up_time) * 0.55,
		Vector3(drift_x * 0.25, peak * 0.12, drift_z * 0.25)
	)
	anim.track_insert_key(pos_track, duration, Vector3.ZERO)

	return anim
