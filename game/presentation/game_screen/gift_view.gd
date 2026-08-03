class_name GiftView
extends Node2D
## Визуализация на подарък върху дъската (docs/V1_ARCHITECTURE.md, раздел 6;
## задача "Създаване на GiftView" #219).
##
## Отговорности:
##   - слуша GiftSpawnedEvent → появява се на cell_id с pop-in + идле bob;
##   - слуша GiftCollectedEvent → burst/flash и изчезва (queue_free);
##   - не знае съдържанието на подаръка преди GiftCollectedEvent (винаги
##     показва само Gift.png — конкретната power-up икона е отделен обхват);
##   - не пази gameplay state (gift_id/cell_id са presentation-only огледало).
##
## animation_finished(kind) следва конвенцията от PawnView (#169) —
## AnimationFinishedGate чака преди следващото събитие в опашката.

signal animation_finished(kind: StringName)

const KIND_SPAWN := &"spawn"
const KIND_COLLECTED := &"collected"

const SIZE_RATIO := 0.55
const SPAWN_DURATION := 0.35
const BOB_AMPLITUDE := 4.0
const BOB_DURATION := 0.45
const COLLECT_DURATION := 0.3
const COLLECT_SCALE_PEAK := 1.35

## Стабилен идентификатор — същият StringName като в GiftState (GiftId формат).
var gift_id: StringName = &""
## Клетката, на която стои подаръкът (CellId); празна преди present_gift_spawned.
var cell_id: StringName = &""

@export var grid_pos: Vector2i = Vector2i.ZERO

var _sprite: Sprite2D = null
var _bob_tween: Tween
var _action_tween: Tween
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_ensure_sprite()


func setup(texture_path: String, tile_width_px: float) -> void:
	_ensure_sprite()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.centered = true
	if _sprite.texture == null:
		return
	var s: float = (tile_width_px * SIZE_RATIO) / float(_sprite.texture.get_width())
	scale = Vector2(s, s)
	_base_scale = scale
	# Anchor at feet, same convention as PawnView.setup() — bottom-center of
	# the sprite sits on the tile center so the gift rests on the tile like a
	# pawn, instead of floating with its geometric middle at the tile center.
	_sprite.offset = Vector2(0.0, -float(_sprite.texture.get_height()) * 0.5)


## Instant apply от GiftSpawnedEvent — snap fallback (без AnimationQueue).
func present_gift_spawned(event: GiftSpawnedEvent, local_target: Vector2) -> void:
	if event == null or not event.is_valid():
		return
	gift_id = event.gift_id
	cell_id = event.cell_id
	_apply_cell_z_index(event.cell_id)
	scale = _base_scale
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	position = local_target
	_start_idle_bob()


## Pop-in анимация след приета команда (#219 / AnimationQueue playback).
## Емитира animation_finished(KIND_SPAWN) веднъж след settle (#169).
func present_gift_spawned_animated(event: GiftSpawnedEvent, local_target: Vector2) -> void:
	if event == null or not event.is_valid():
		return
	gift_id = event.gift_id
	cell_id = event.cell_id
	_apply_cell_z_index(event.cell_id)
	_stop_bob_tween()
	_stop_action_tween()
	position = local_target
	scale = Vector2.ZERO
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_action_tween = create_tween()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "scale", _base_scale, SPAWN_DURATION)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "modulate:a", 1.0, SPAWN_DURATION * 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await _action_tween.finished
	scale = _base_scale
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_action_tween = null
	_start_idle_bob()
	animation_finished.emit(KIND_SPAWN)


## Instant apply от GiftCollectedEvent — snap fallback (без AnimationQueue).
func present_gift_collected(_event: GiftCollectedEvent) -> void:
	_stop_bob_tween()
	_stop_action_tween()
	queue_free()


## Burst + fade преди изчезване (#219). Съдържанието (power_up_id) не се
## разкрива визуално тук — извън обхвата на тази задача. Емитира
## animation_finished(KIND_COLLECTED) точно преди queue_free (#169).
func present_gift_collected_animated(_event: GiftCollectedEvent) -> void:
	_stop_bob_tween()
	_stop_action_tween()
	_action_tween = create_tween()
	_action_tween.tween_property(self, "scale", _base_scale * COLLECT_SCALE_PEAK, COLLECT_DURATION * 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "scale", Vector2.ZERO, COLLECT_DURATION * 0.6)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	_action_tween.tween_property(self, "modulate:a", 0.0, COLLECT_DURATION * 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await _action_tween.finished
	_action_tween = null
	animation_finished.emit(KIND_COLLECTED)
	queue_free()


func _start_idle_bob() -> void:
	_stop_bob_tween()
	var base_y: float = position.y
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "position:y", base_y - BOB_AMPLITUDE, BOB_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", base_y + BOB_AMPLITUDE, BOB_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func _stop_bob_tween() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null


func _stop_action_tween() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = null


## Painter's-algorithm z_index спрямо дъската (аналог на PawnView spawn/_apply_cell_pose) —
## без него подаръкът пада зад tiles с по-висок ред за долната/дясната половина.
func _apply_cell_z_index(for_cell_id: StringName) -> void:
	if not CellId.is_valid(for_cell_id):
		return
	grid_pos = CellId.to_vec(for_cell_id)
	z_index = grid_pos.x + grid_pos.y + 1


func _ensure_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
