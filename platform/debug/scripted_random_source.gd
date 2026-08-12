class_name ScriptedRandomSource
extends RandomSource
## Debug RandomSource, който позволява да се зададе конкретен зар и конкретен
## power-up (docs/V1_ARCHITECTURE.md §4.5 / §6.4).
##
## Обвива истински RandomSource (обикновено SeededRandomSource) и подменя
## резултата САМО когато е заредена стойност — еднократно (one-shot). Всичко
## останало делегира, така че детерминизмът на мача се запазва.
##
## Еднократното зареждане е предпочетено пред разпознаване по диапазон:
## зарът тегли next_int(1, 6), а телепортът next_int(3, 6) — разчитането на
## съвпадение в аргументите би било крехко. Тук forced лицето се консумира от
## първото следващо теглене в диапазона на зара, което на практика е самото
## хвърляне веднага след натискането на debug бутона.
##
## get_state() / set_state() делегират, за да останат GameState.rng_state и
## MatchSession.to_snapshot() валидни.
##
## Никога не се създава в release build — GameScreen го инжектира само когато
## DebugMode.is_authorized().

## Няма заредено лице (NONE == DiceState.VALUE_NONE).
const FACE_NONE: int = 0

var _inner: RandomSource
var _forced_face: int = FACE_NONE
var _forced_power_up: StringName = &""


func _init(inner: RandomSource = null) -> void:
	_inner = inner if inner != null else SeededRandomSource.new()


## Обвитият източник — за диагностика; gameplay винаги минава през този клас.
func get_inner() -> RandomSource:
	return _inner


## Зарежда лице 1–6 за следващото хвърляне. Невалидна стойност изчиства.
func force_next_face(face: int) -> void:
	_forced_face = face if DiceState.is_face_value(face) else FACE_NONE


## Зарежда power_up_id за следващия взет подарък. Невалиден id изчиства.
func force_next_power_up(power_up_id: StringName) -> void:
	_forced_power_up = power_up_id if PowerUpId.is_valid(power_up_id) else &""


func has_forced_face() -> bool:
	return _forced_face != FACE_NONE


func has_forced_power_up() -> bool:
	return _forced_power_up != &""


func get_forced_face() -> int:
	return _forced_face


func get_forced_power_up() -> StringName:
	return _forced_power_up


## Изчиства и двете заредени стойности (бутон „Изчисти" в debug панела).
func clear_forced() -> void:
	_forced_face = FACE_NONE
	_forced_power_up = &""


## Зареденото лице се консумира само от теглене в диапазона на зара —
## телепортът (3–6) и другите вътрешни тегления остават недокоснати.
func next_int(min_val: int, max_val: int) -> int:
	if has_forced_face() and _is_dice_range(min_val, max_val):
		var face: int = _forced_face
		_forced_face = FACE_NONE
		return face
	return _inner.next_int(min_val, max_val)


## Зареденият power-up се консумира само когато масивът съдържа PowerUpId —
## тегленето на клетка за подарък подава CellId и не се засяга.
func pick(array: Array) -> Variant:
	if has_forced_power_up() and _is_power_up_array(array):
		var power_up_id: StringName = _forced_power_up
		_forced_power_up = &""
		return power_up_id
	return _inner.pick(array)


func get_state() -> Dictionary:
	return _inner.get_state()


func set_state(state: Dictionary) -> void:
	_inner.set_state(state)


static func _is_dice_range(min_val: int, max_val: int) -> bool:
	return min_val == DiceState.VALUE_MIN and max_val == DiceState.VALUE_MAX


static func _is_power_up_array(array: Array) -> bool:
	if array.is_empty():
		return false
	return PowerUpId.is_valid(StringName(str(array[0])))
