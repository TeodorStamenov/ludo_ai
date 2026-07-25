class_name PawnId
extends RefCounted
## Стабилни идентификатори за пионките.
##
## Всеки играч (seat) има точно 4 пионки с индекси 0–3.
## Форматът е "{player_id}_{index}", напр. &"yellow_0", &"green_3".
##
## Пионките са стратегически равноценни — индексът е само за уникалност,
## не за наредба или специална роля.
##
## Общият брой пионки в мач: PlayerId.COUNT × PAWNS_PER_PLAYER = 4 × 4 = 16.

## Брой пионки на играч (архитектурен инвариант — никога не се променя за v1).
const PAWNS_PER_PLAYER: int = 4


## Генерира стабилен pawn_id за даден player_id и индекс.
## Пример: PawnId.for_player(&"yellow", 2) → &"yellow_2"
static func for_player(player_id: StringName, index: int) -> StringName:
	assert(index >= 0 and index < PAWNS_PER_PLAYER,
			"pawn index must be 0–%d, got %d" % [PAWNS_PER_PLAYER - 1, index])
	return StringName("%s_%d" % [player_id, index])


## Връща всички 4 pawn_id за даден player_id в ред 0→3.
static func all_for_player(player_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for i in PAWNS_PER_PLAYER:
		result.append(for_player(player_id, i))
	return result


## Извлича player_id от pawn_id чрез разбиване по последното '_'.
## Пример: &"yellow_2" → &"yellow". При невалиден формат → &"".
static func get_player_id(pawn_id: StringName) -> StringName:
	var s: String = pawn_id
	var sep: int = s.rfind("_")
	if sep <= 0:
		return &""
	return StringName(s.left(sep))


## Извлича индекса от pawn_id. Пример: &"yellow_2" → 2.
## При невалиден формат връща -1.
static func get_index(pawn_id: StringName) -> int:
	var s: String = pawn_id
	var sep: int = s.rfind("_")
	if sep < 0 or sep >= s.length() - 1:
		return -1
	return s.substr(sep + 1).to_int()


## Проверява дали pawn_id е валидно форматиран:
## player_id трябва да е валиден и index в [0, PAWNS_PER_PLAYER).
static func is_valid(pawn_id: StringName) -> bool:
	var player := get_player_id(pawn_id)
	if not PlayerId.is_valid(player):
		return false
	var index := get_index(pawn_id)
	return index >= 0 and index < PAWNS_PER_PLAYER
