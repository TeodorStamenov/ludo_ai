class_name AnimationFinishedGate
extends RefCounted
## Потвърждение при завършена event анимация (#169).
## (docs/V1_ARCHITECTURE.md §5.2 / §6.1 — Domain не чака tween).
##
## Договорът: view емитира `animation_finished(kind)` след еднократна анимация;
## AnimationQueue / EventViewBinder изчакват този сигнал преди следващия event.
## Instant/snap пътища не ползват gate-а.

signal confirmed(kind: StringName)

const SIGNAL_ANIMATION_FINISHED := &"animation_finished"

var _view: Object = null
var _expected_kind: StringName = &""
var _armed: bool = false
var _done: bool = false
var _received_kind: StringName = &""


func is_armed() -> bool:
	return _armed


func is_done() -> bool:
	return _done


func get_received_kind() -> StringName:
	return _received_kind


## Свързва се към view.animation_finished преди старт на анимацията.
## Липсващ view / сигнал → маркира done (няма какво да чака).
func arm(view: Object, expected_kind: StringName = &"") -> void:
	disarm()
	_view = view
	_expected_kind = expected_kind
	_received_kind = &""
	_done = false
	if view == null or not is_instance_valid(view):
		_done = true
		return
	if not view.has_signal(SIGNAL_ANIMATION_FINISHED):
		_done = true
		return
	view.connect(SIGNAL_ANIMATION_FINISHED, _on_animation_finished)
	_armed = true


func disarm() -> void:
	if _armed and _view != null and is_instance_valid(_view):
		if _view.is_connected(SIGNAL_ANIMATION_FINISHED, _on_animation_finished):
			_view.disconnect(SIGNAL_ANIMATION_FINISHED, _on_animation_finished)
	_armed = false
	_view = null


## Блокира до animation_finished (филтриран по kind, ако е зададен).
## Ако arm() вече е done (няма сигнал) — връща веднага.
func wait() -> void:
	if _done:
		disarm()
		return
	var kind: StringName = await confirmed
	_received_kind = kind
	disarm()


## Arm → стартира starter без да го await-ва → чака animation_finished.
## Confirmation-ът е сигналът (#169), не вътрешният await на starter-а.
## Ако няма signalable view — await-ва starter като fallback.
static func await_started(
		view: Object,
		expected_kind: StringName,
		starter: Callable
) -> void:
	var gate := AnimationFinishedGate.new()
	gate.arm(view, expected_kind)
	if not gate.is_armed():
		if starter.is_valid():
			await starter.call()
		return
	if starter.is_valid():
		starter.call()
	await gate.wait()


func _on_animation_finished(kind: StringName) -> void:
	if _done:
		return
	if _expected_kind != &"" and kind != _expected_kind:
		return
	_received_kind = kind
	_done = true
	if _armed and _view != null and is_instance_valid(_view):
		if _view.is_connected(SIGNAL_ANIMATION_FINISHED, _on_animation_finished):
			_view.disconnect(SIGNAL_ANIMATION_FINISHED, _on_animation_finished)
	_armed = false
	confirmed.emit(kind)
