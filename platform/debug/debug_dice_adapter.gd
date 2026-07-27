class_name DebugDiceAdapter
extends RefCounted
## Разрешен канал за forced dice rolls в debug builds
## (docs/V1_ARCHITECTURE.md §6.4, #163).
##
## Debug бутоните 1–6 изпращат тестова стойност само през този adapter.
## В release/production export `is_authorized()` е false — UI трябва да се
## скрие и `request_forced_face` връща 0 (нормален RNG път).
##
## Не е command към GameEngine: клиентът продължава с RollDiceCommand /
## прототипен roll; adapter-ът само гейтва forced лицето.


## True само в editor / debug export (`OS.is_debug_build()`).
static func is_authorized() -> bool:
	return OS.is_debug_build()


## Инстанция при authorized debug build; иначе null (caller скрива UI).
static func create_authorized() -> DebugDiceAdapter:
	if not is_authorized():
		return null
	return DebugDiceAdapter.new()


## Валидно лице 1–6 ако adapter-ът е authorized; иначе 0.
func request_forced_face(face: int) -> int:
	if not is_authorized():
		return 0
	if not DiceState.is_face_value(face):
		return 0
	return face
