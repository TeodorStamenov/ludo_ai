class_name DiceState
extends RefCounted
## Текущ/последен резултат от зара в GameState (docs/V1_ARCHITECTURE.md, §4.1).
##
## GameState.dice е DiceState. Presentation (DiceView) не генерира стойността —
## тя идва от авторитетния RNG през RollDiceCommand → DiceRolled (§4.3 / §6.4).
##
## Правила (docs/V1_GAME_DESIGN.md §3 / CURRENT_YELLOW_BEHAVIOR YEL-013/030/032):
##   - един зар със стойност 1–6 (VALUE_NONE = още няма / изчистен);
##   - 6 → излизане от база + право на допълнително хвърляне.
##
## TurnState също пази dice_value за turn machine (§4.2); DiceState е
## сериализируемият snapshot на зара (стойност + кой го е хвърлил).
## Синхронизацията между двете е отговорност на GameEngine.

## Няма хвърлен резултат (преди зар / след изчистване).
const VALUE_NONE: int = 0
const VALUE_MIN: int = 1
const VALUE_MAX: int = 6
## Лице, което дава излизане от база и допълнително хвърляне.
const EXTRA_TURN_VALUE: int = 6
const EXIT_BASE_VALUE: int = 6


## Хвърлен резултат 1–6; VALUE_NONE ако още няма / е изчистен.
var value: int = VALUE_NONE
## Играчът, хвърлил зара (PlayerId); празен когато няма резултат.
var player_id: StringName = &""


## Фабрика за пълно конфигуриран DiceState.
static func create(p_value: int, p_player_id: StringName = &"") -> DiceState:
	var dice := DiceState.new()
	dice.value = p_value
	dice.player_id = p_player_id
	return dice


## Начално / изчистено състояние — няма резултат.
static func create_none() -> DiceState:
	return create(VALUE_NONE, &"")


## Фабрика за валидно хвърляне (player_id + стойност 1–6).
static func create_roll(p_player_id: StringName, p_value: int) -> DiceState:
	return create(p_value, p_player_id)


func has_result() -> bool:
	return value >= VALUE_MIN and value <= VALUE_MAX


func is_six() -> bool:
	return value == EXTRA_TURN_VALUE


## True ако хвърлянето дава допълнителен ход (зар 6).
func grants_extra_turn() -> bool:
	return value == EXTRA_TURN_VALUE


## True ако хвърлянето позволява излизане от база (зар 6).
func allows_exit_base() -> bool:
	return value == EXIT_BASE_VALUE


## Записва хвърляне; не валидира правилата на хода (engine решава).
func set_roll(p_player_id: StringName, p_value: int) -> void:
	player_id = p_player_id
	value = p_value


func clear() -> void:
	value = VALUE_NONE
	player_id = &""


## True ако полетата са в договорните self-contained граници (§4.1 / §12).
## VALUE_NONE изисква празен player_id; 1–6 изисква валиден PlayerId.
func is_valid() -> bool:
	if not _is_value_in_range(value):
		return false
	if value == VALUE_NONE:
		return player_id == &""
	return PlayerId.is_valid(player_id)


## JSON-safe Dictionary: StringName → String. Без Vector2 / NodePath (§4.1).
func to_dict() -> Dictionary:
	return {
		"value": value,
		"player_id": String(player_id),
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> DiceState:
	var dice := DiceState.new()
	dice.value = int(data.get("value", VALUE_NONE))
	dice.player_id = StringName(str(data.get("player_id", "")))
	return dice


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_state() -> DiceState:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: DiceState) -> bool:
	if other == null:
		return false
	return value == other.value and player_id == other.player_id


static func is_face_value(p_value: int) -> bool:
	return p_value >= VALUE_MIN and p_value <= VALUE_MAX


static func _is_value_in_range(p_value: int) -> bool:
	return p_value == VALUE_NONE or is_face_value(p_value)
