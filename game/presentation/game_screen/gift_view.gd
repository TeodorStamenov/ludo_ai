class_name GiftView
extends Node2D
## Визуализация на подарък върху дъската (docs/V1_ARCHITECTURE.md, раздел 6;
## задача "Създаване на GiftView" #219).
##
## Отговорности:
##   - слуша GiftSpawnedEvent → появява се на cell_id с pop-in + идле bob;
##   - слуша GiftCollectedEvent → "slot-cycle" разкриване на изтегления
##     power-up (#221: бързо превключване през 4-те икони, детерминирано
##     каца на верния, кратка пауза, после fade) и изчезва (queue_free);
##   - не знае съдържанието на подаръка преди GiftCollectedEvent (показва
##     само Gift.png до тогава);
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

## Иконите за "slot-cycle" разкриването (#221) — preload-нати, за да няма
## disk I/O hitch по време на бързите превключвания.
const POWER_UP_TEXTURES: Dictionary = {
	PowerUpId.TELEPORT_FORWARD: preload("res://rss/powerups/Teleport.png"),
	PowerUpId.SHIELD: preload("res://rss/powerups/Shield.png"),
	PowerUpId.EXTRA_TURN: preload("res://rss/powerups/Luck.png"),
	PowerUpId.PUSH: preload("res://rss/powerups/Lightning.png"),
}
## Фиксиран кръгов ред за cycle-а — произволен, но стабилен избор.
const CYCLE_ORDER: Array[StringName] = [
	PowerUpId.TELEPORT_FORWARD, PowerUpId.SHIELD,
	PowerUpId.EXTRA_TURN, PowerUpId.PUSH,
]
## Минимален брой превключвания в cycle-а (реалният брой се коригира нагоре,
## за да падне последното превключване точно на изтегления power-up).
const REVEAL_MIN_SWAPS := 10
## Обща продължителност на cycle-а (сборът на всички интервали между превключванията).
const REVEAL_CYCLE_DURATION := 0.85
## Landing pop преди кратката пауза, в която играчът разчита иконата.
const REVEAL_LANDING_POP_DURATION := 0.2
const REVEAL_HOLD_DURATION := 0.2
## При collect подаръкът и пионката, която го взема, стоят на същата клетка —
## повдигаме reveal-а над главата ѝ вместо да седи върху нея (bug report).
const REVEAL_HEAD_CLEARANCE_RATIO := 0.9

## Стабилен идентификатор — същият StringName като в GiftState (GiftId формат).
var gift_id: StringName = &""
## Клетката, на която стои подаръкът (CellId); празна преди present_gift_spawned.
var cell_id: StringName = &""

@export var grid_pos: Vector2i = Vector2i.ZERO

var _sprite: Sprite2D = null
var _bob_tween: Tween
var _action_tween: Tween
var _base_scale: Vector2 = Vector2.ONE
## Запазен от setup() — нужен за преоразмеряване на power-up иконите (различни
## resolutions от Gift.png) по време на reveal cycle-а (#221).
var _tile_width_px: float = 0.0


func _ready() -> void:
	_ensure_sprite()


func setup(texture_path: String, tile_width_px: float) -> void:
	_ensure_sprite()
	_tile_width_px = tile_width_px
	_sprite.centered = true
	_apply_icon_texture(load(texture_path) as Texture2D)
	_base_scale = scale


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


## "Slot-cycle" разкриване (#221) + burst/fade преди изчезване. Бързо
## превключва през 4-те power-up икони (детерминирано каца на
## event.power_up_id — виж _play_power_up_reveal), кратък landing pop +
## пауза за четене, после shrink+fade. Емитира animation_finished(KIND_COLLECTED)
## точно преди queue_free (#169).
func present_gift_collected_animated(event: GiftCollectedEvent) -> void:
	_stop_bob_tween()
	_stop_action_tween()
	position.y -= _tile_width_px * REVEAL_HEAD_CLEARANCE_RATIO

	await _play_power_up_reveal(event.power_up_id if event != null else &"")

	_action_tween = create_tween()
	_action_tween.tween_property(self, "scale", _base_scale * COLLECT_SCALE_PEAK, REVEAL_LANDING_POP_DURATION)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	await _action_tween.finished
	scale = _base_scale * COLLECT_SCALE_PEAK
	_action_tween = null

	await get_tree().create_timer(REVEAL_HOLD_DURATION).timeout

	_action_tween = create_tween()
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


## Бързо превключва текстурата през CYCLE_ORDER, интервалите растат
## (deceleration), и детерминирано спира на power_up_id — броят превключвания
## се коригира нагоре така че последното винаги съвпада с целта, без
## special-case "snap" в края (#221).
func _play_power_up_reveal(power_up_id: StringName) -> void:
	var target_index: int = CYCLE_ORDER.find(power_up_id)
	if target_index < 0:
		target_index = 0

	var total_swaps: int = REVEAL_MIN_SWAPS
	while (total_swaps - 1) % CYCLE_ORDER.size() != target_index:
		total_swaps += 1

	for i in total_swaps:
		var icon_id: StringName = CYCLE_ORDER[i % CYCLE_ORDER.size()]
		_apply_icon_texture(POWER_UP_TEXTURES.get(icon_id) as Texture2D)
		var interval: float = REVEAL_CYCLE_DURATION * (2.0 * (i + 1)) / float(total_swaps * (total_swaps + 1))
		await get_tree().create_timer(interval).timeout


## Задава текстура + преизчислява scale/anchor спрямо _tile_width_px (#221) —
## power-up иконите имат различни resolutions от Gift.png, но трябва да
## изглеждат еднакво "тежки" на клетката и да стоят със същия feet-anchor.
func _apply_icon_texture(texture: Texture2D) -> void:
	if texture == null or _tile_width_px <= 0.0:
		return
	_sprite.texture = texture
	var s: float = (_tile_width_px * SIZE_RATIO) / float(texture.get_width())
	scale = Vector2(s, s)
	_sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.5)


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
