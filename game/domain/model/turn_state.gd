class_name TurnState
extends RefCounted
## Изрична state machine на хода (docs/V1_ARCHITECTURE.md, §4.2;
## docs/CURRENT_YELLOW_BEHAVIOR.md YEL-003/004/010–015).
##
## Фази (TurnPhase):
##   MATCH_START → AWAITING_ROLL → AWAITING_MOVE → RESOLVING_MOVE
##   → RESOLVING_POWER_UP → TURN_END → AWAITING_ROLL → … → MATCH_FINISHED
##
## Полета:
##   phase, dice_value, base_attempts_remaining, extra_roll_pending,
##   valid_command_kinds[], valid_pawn_ids[], turn_number
##
## Не държи разпръснати boolean флагове като прототипа (_awaiting_pawn_choice,
## _roll_allowed, …) — фазата и valid_* масивите са единственият договор за
## input / AI / remote player.
##
## Преходите с пълна game-rule логика са в TurnRules / GameEngine (issue #85);
## тук са data model, фабрики, mutators и сериализация.

## Максимум опити при всички пионки в база (YEL-003 / прототип BASE_ROLL_ATTEMPTS).
const BASE_ROLL_ATTEMPTS: int = 3
## Опити когато поне една пионка е на дъската (YEL-004).
const SINGLE_ROLL_ATTEMPTS: int = 1
## Няма хвърлен резултат (преди зар / след изчистване).
const DICE_NONE: int = 0
const DICE_MIN: int = 1
const DICE_MAX: int = 6

## Стабилни идентификатори на валидни командни видове (сериализируем snapshot).
const COMMAND_ROLL_DICE: StringName = &"roll_dice"
const COMMAND_MOVE_PAWN: StringName = &"move_pawn"

const ALL_COMMAND_KINDS: Array[StringName] = [
	COMMAND_ROLL_DICE,
	COMMAND_MOVE_PAWN,
]


## Текуща фаза на хода (TurnPhase).
var phase: int = TurnPhase.MATCH_START
## Хвърлен резултат 1–6; DICE_NONE ако още няма / е изчистен.
var dice_value: int = DICE_NONE
## Оставащи опити при всички пионки в база (и при нормален ход = 1 или 0).
var base_attempts_remaining: int = 0
## Право на допълнително хвърляне (зар 6 или Extra Turn power-up).
var extra_roll_pending: bool = false
## Валидни командни видове за текущата фаза (StringName: roll_dice / move_pawn).
var valid_command_kinds: Array = []
## Пионки, за които MovePawnCommand е валидна (StringName pawn_id).
var valid_pawn_ids: Array = []
## Пореден номер на хода (0 в MATCH_START; >= 1 след begin_player_turn).
var turn_number: int = 0


## Фабрика за пълно конфигуриран TurnState (масивите се копират).
static func create(
		p_phase: int,
		p_dice_value: int = DICE_NONE,
		p_base_attempts_remaining: int = 0,
		p_extra_roll_pending: bool = false,
		p_valid_command_kinds: Array = [],
		p_valid_pawn_ids: Array = [],
		p_turn_number: int = 0
) -> TurnState:
	var turn := TurnState.new()
	turn.phase = p_phase
	turn.dice_value = p_dice_value
	turn.base_attempts_remaining = p_base_attempts_remaining
	turn.extra_roll_pending = p_extra_roll_pending
	turn.valid_command_kinds = _normalize_command_kinds(p_valid_command_kinds)
	turn.valid_pawn_ids = _normalize_pawn_ids(p_valid_pawn_ids)
	turn.turn_number = p_turn_number
	return turn


## Начално състояние преди първия ход (след StartMatch, преди AWAITING_ROLL).
static func create_match_start() -> TurnState:
	return create(
			TurnPhase.MATCH_START,
			DICE_NONE,
			0,
			false,
			[],
			[],
			0)


## Ход на играч в AWAITING_ROLL с правилен брой опити (YEL-003 / YEL-004).
static func create_for_player_turn(
		p_turn_number: int,
		all_pawns_in_base: bool
) -> TurnState:
	var turn := create_match_start()
	turn.begin_player_turn(p_turn_number, all_pawns_in_base)
	return turn


func is_match_start() -> bool:
	return phase == TurnPhase.MATCH_START


func is_awaiting_roll() -> bool:
	return phase == TurnPhase.AWAITING_ROLL


func is_awaiting_move() -> bool:
	return phase == TurnPhase.AWAITING_MOVE


func is_resolving_move() -> bool:
	return phase == TurnPhase.RESOLVING_MOVE


func is_resolving_power_up() -> bool:
	return phase == TurnPhase.RESOLVING_POWER_UP


func is_turn_end() -> bool:
	return phase == TurnPhase.TURN_END


func is_match_finished() -> bool:
	return phase == TurnPhase.MATCH_FINISHED


## True ако фазата приема команда от играча (AWAITING_ROLL / AWAITING_MOVE).
func accepts_command() -> bool:
	return TurnPhase.accepts_command(phase)


func has_dice_result() -> bool:
	return dice_value >= DICE_MIN and dice_value <= DICE_MAX


func has_extra_roll_pending() -> bool:
	return extra_roll_pending


func has_base_attempts_remaining() -> bool:
	return base_attempts_remaining > 0


func allows_roll_dice() -> bool:
	return is_awaiting_roll() and has_command_kind(COMMAND_ROLL_DICE)


func allows_move_pawn() -> bool:
	return is_awaiting_move() and has_command_kind(COMMAND_MOVE_PAWN)


func has_command_kind(kind: StringName) -> bool:
	var kind_str := String(kind)
	for entry in valid_command_kinds:
		if str(entry) == kind_str:
			return true
	return false


func has_valid_pawn(pawn_id: StringName) -> bool:
	var id_str := String(pawn_id)
	for entry in valid_pawn_ids:
		if str(entry) == id_str:
			return true
	return false


func phase_name() -> StringName:
	return TurnPhase.phase_name(phase)


## Стартира ход на играч: AWAITING_ROLL + опити + roll_dice команда.
func begin_player_turn(p_turn_number: int, all_pawns_in_base: bool) -> void:
	phase = TurnPhase.AWAITING_ROLL
	turn_number = p_turn_number
	dice_value = DICE_NONE
	extra_roll_pending = false
	valid_pawn_ids.clear()
	base_attempts_remaining = (
			BASE_ROLL_ATTEMPTS if all_pawns_in_base else SINGLE_ROLL_ATTEMPTS)
	valid_command_kinds = [COMMAND_ROLL_DICE]


## Записва хвърляне; не сменя фазата (engine решава следващата стъпка).
func set_dice_value(value: int) -> void:
	dice_value = value


func clear_dice() -> void:
	dice_value = DICE_NONE


func grant_extra_roll() -> void:
	extra_roll_pending = true


func clear_extra_roll() -> void:
	extra_roll_pending = false


## Изразходва правото на допълнително хвърляне. Връща true ако е имало такова.
func consume_extra_roll() -> bool:
	if not extra_roll_pending:
		return false
	extra_roll_pending = false
	return true


## Намалява оставащите опити с 1 (не пада под 0). Връща остатъка.
func consume_base_attempt() -> int:
	if base_attempts_remaining > 0:
		base_attempts_remaining -= 1
	return base_attempts_remaining


func set_valid_command_kinds(kinds: Array) -> void:
	valid_command_kinds = _normalize_command_kinds(kinds)


func set_valid_pawn_ids(pawn_ids: Array) -> void:
	valid_pawn_ids = _normalize_pawn_ids(pawn_ids)


func clear_valid_actions() -> void:
	valid_command_kinds.clear()
	valid_pawn_ids.clear()


## Преход към AWAITING_MOVE с хвърлен зар и валидни пионки.
func enter_awaiting_move(p_dice_value: int, pawn_ids: Array) -> void:
	phase = TurnPhase.AWAITING_MOVE
	dice_value = p_dice_value
	valid_command_kinds = [COMMAND_MOVE_PAWN]
	valid_pawn_ids = _normalize_pawn_ids(pawn_ids)


## Преход към AWAITING_ROLL за допълнително хвърляне (същият turn_number).
func enter_extra_roll() -> void:
	phase = TurnPhase.AWAITING_ROLL
	dice_value = DICE_NONE
	extra_roll_pending = false
	valid_pawn_ids.clear()
	base_attempts_remaining = SINGLE_ROLL_ATTEMPTS
	valid_command_kinds = [COMMAND_ROLL_DICE]


func enter_resolving_move() -> void:
	phase = TurnPhase.RESOLVING_MOVE
	clear_valid_actions()


func enter_resolving_power_up() -> void:
	phase = TurnPhase.RESOLVING_POWER_UP
	clear_valid_actions()


func enter_turn_end() -> void:
	phase = TurnPhase.TURN_END
	clear_valid_actions()


func enter_match_finished() -> void:
	phase = TurnPhase.MATCH_FINISHED
	dice_value = DICE_NONE
	extra_roll_pending = false
	base_attempts_remaining = 0
	clear_valid_actions()


## True ако полетата са в договорните self-contained граници (§4.2 / §12).
func is_valid() -> bool:
	if not TurnPhase.is_valid(phase):
		return false
	if not _is_dice_value_valid(dice_value):
		return false
	if base_attempts_remaining < 0 or base_attempts_remaining > BASE_ROLL_ATTEMPTS:
		return false
	if turn_number < 0:
		return false
	if not _are_command_kinds_valid(valid_command_kinds):
		return false
	if not _are_pawn_ids_valid(valid_pawn_ids):
		return false
	return true


## JSON-safe Dictionary: StringName → String, enum като int.
## Без Vector2 / NodePath — само стабилни идентификатори (§4.1).
func to_dict() -> Dictionary:
	var kinds: Array = []
	for kind in valid_command_kinds:
		kinds.append(str(kind))
	var pawns: Array = []
	for pawn_id in valid_pawn_ids:
		pawns.append(str(pawn_id))
	return {
		"phase": phase,
		"dice_value": dice_value,
		"base_attempts_remaining": base_attempts_remaining,
		"extra_roll_pending": extra_roll_pending,
		"valid_command_kinds": kinds,
		"valid_pawn_ids": pawns,
		"turn_number": turn_number,
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> TurnState:
	var turn := TurnState.new()
	turn.phase = int(data.get("phase", TurnPhase.MATCH_START))
	turn.dice_value = int(data.get("dice_value", DICE_NONE))
	turn.base_attempts_remaining = int(data.get("base_attempts_remaining", 0))
	turn.extra_roll_pending = bool(data.get("extra_roll_pending", false))
	turn.turn_number = int(data.get("turn_number", 0))
	var kinds = data.get("valid_command_kinds", [])
	if kinds is Array:
		turn.valid_command_kinds = _normalize_command_kinds(kinds)
	else:
		turn.valid_command_kinds = []
	var pawns = data.get("valid_pawn_ids", [])
	if pawns is Array:
		turn.valid_pawn_ids = _normalize_pawn_ids(pawns)
	else:
		turn.valid_pawn_ids = []
	return turn


## Дълбоко копие през сериализация — без споделени референции към масивите.
func duplicate_state() -> TurnState:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: TurnState) -> bool:
	if other == null:
		return false
	if (phase != other.phase
			or dice_value != other.dice_value
			or base_attempts_remaining != other.base_attempts_remaining
			or extra_roll_pending != other.extra_roll_pending
			or turn_number != other.turn_number):
		return false
	if valid_command_kinds.size() != other.valid_command_kinds.size():
		return false
	for i in valid_command_kinds.size():
		if str(valid_command_kinds[i]) != str(other.valid_command_kinds[i]):
			return false
	if valid_pawn_ids.size() != other.valid_pawn_ids.size():
		return false
	for i in valid_pawn_ids.size():
		if str(valid_pawn_ids[i]) != str(other.valid_pawn_ids[i]):
			return false
	return true


static func is_known_command_kind(kind: StringName) -> bool:
	return kind in ALL_COMMAND_KINDS


static func _is_dice_value_valid(value: int) -> bool:
	return value == DICE_NONE or (value >= DICE_MIN and value <= DICE_MAX)


static func _are_command_kinds_valid(kinds: Array) -> bool:
	var seen: Dictionary = {}
	for entry in kinds:
		var kind := StringName(str(entry))
		if not is_known_command_kind(kind):
			return false
		if seen.has(String(kind)):
			return false
		seen[String(kind)] = true
	return true


static func _are_pawn_ids_valid(pawn_ids: Array) -> bool:
	var seen: Dictionary = {}
	for entry in pawn_ids:
		var pawn_id := StringName(str(entry))
		if not PawnId.is_valid(pawn_id):
			return false
		if seen.has(String(pawn_id)):
			return false
		seen[String(pawn_id)] = true
	return true


static func _normalize_command_kinds(kinds: Array) -> Array:
	var copy: Array = []
	for entry in kinds:
		copy.append(StringName(str(entry)))
	return copy


static func _normalize_pawn_ids(pawn_ids: Array) -> Array:
	var copy: Array = []
	for entry in pawn_ids:
		copy.append(StringName(str(entry)))
	return copy
