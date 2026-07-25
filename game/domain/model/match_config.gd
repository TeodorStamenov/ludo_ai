class_name MatchConfig
extends RefCounted
## Сериализируем модел на конфигурацията за мач (docs/V1_ARCHITECTURE.md, раздел 5.1).
##
## И свободната игра, и кампанията произвеждат MatchConfig;
## GameScreen зависи само от него и не знае нищо за менютата.
##
## Живее в domain/model/, защото е чист value object без странични ефекти
## и домейнът го нужда директно (GameState.match_config, StartMatchCommand.config).
##
## Схема:
##   schema_version, mode, board_id, theme_id,
##   seats[], campaign_level_id?, level_modifiers[], pre_match_bonus?, rng_seed

const SCHEMA_VERSION := 1

enum Mode { FREE_PLAY = 0, CAMPAIGN = 1 }
enum ControllerType { HUMAN = 0, AI = 1, REMOTE = 2 }
enum AIDifficulty { EASY = 0, MEDIUM = 1, HARD = 2 }


class SeatConfig extends RefCounted:
	var player_id: StringName = &""
	var controller_type: int = ControllerType.HUMAN
	var ai_difficulty: int = AIDifficulty.EASY
	var animal_id: StringName = &"pig"

	func to_dict() -> Dictionary:
		return {
			"player_id": player_id,
			"controller_type": controller_type,
			"ai_difficulty": ai_difficulty,
			"animal_id": animal_id,
		}

	static func from_dict(data: Dictionary) -> SeatConfig:
		var seat := SeatConfig.new()
		seat.player_id = StringName(data.get("player_id", ""))
		seat.controller_type = int(data.get("controller_type", ControllerType.HUMAN))
		seat.ai_difficulty = int(data.get("ai_difficulty", AIDifficulty.EASY))
		seat.animal_id = StringName(data.get("animal_id", "pig"))
		return seat


var schema_version: int = SCHEMA_VERSION
var mode: int = Mode.FREE_PLAY
var board_id: StringName = &"classic_15x15"
var theme_id: StringName = &"jungle"
var seats: Array = []
var campaign_level_id: StringName = &""
var level_modifiers: Array = []
var pre_match_bonus: Dictionary = {}
var rng_seed: int = 0


func _init() -> void:
	rng_seed = randi()


func add_seat(p_player_id: StringName, p_controller_type: int, p_animal_id: StringName,
		p_ai_difficulty: int = AIDifficulty.EASY) -> void:
	var seat := SeatConfig.new()
	seat.player_id = p_player_id
	seat.controller_type = p_controller_type
	seat.animal_id = p_animal_id
	seat.ai_difficulty = p_ai_difficulty
	seats.append(seat)


func is_valid() -> bool:
	if mode != Mode.FREE_PLAY and mode != Mode.CAMPAIGN:
		return false
	if seats.size() < 2 or seats.size() > 4:
		return false
	var ids_seen: Dictionary = {}
	for seat: SeatConfig in seats:
		if seat.player_id.is_empty():
			return false
		if seat.animal_id.is_empty():
			return false
		if seat.player_id in ids_seen:
			return false
		ids_seen[seat.player_id] = true
		if seat.controller_type < ControllerType.HUMAN or seat.controller_type > ControllerType.REMOTE:
			return false
		if seat.controller_type == ControllerType.AI:
			if seat.ai_difficulty < AIDifficulty.EASY or seat.ai_difficulty > AIDifficulty.HARD:
				return false
	return true


func to_dict() -> Dictionary:
	var seat_dicts: Array = []
	for seat: SeatConfig in seats:
		seat_dicts.append(seat.to_dict())
	return {
		"schema_version": schema_version,
		"mode": mode,
		"board_id": board_id,
		"theme_id": theme_id,
		"seats": seat_dicts,
		"campaign_level_id": campaign_level_id,
		"level_modifiers": level_modifiers.duplicate(),
		"pre_match_bonus": pre_match_bonus.duplicate(),
		"rng_seed": rng_seed,
	}


static func from_dict(data: Dictionary) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	cfg.mode = int(data.get("mode", Mode.FREE_PLAY))
	cfg.board_id = StringName(data.get("board_id", "classic_15x15"))
	cfg.theme_id = StringName(data.get("theme_id", "jungle"))
	cfg.campaign_level_id = StringName(data.get("campaign_level_id", ""))
	cfg.level_modifiers = data.get("level_modifiers", []).duplicate()
	cfg.pre_match_bonus = data.get("pre_match_bonus", {}).duplicate()
	# Липсващ rng_seed запазва авто-генерирания от _init (не форсира 0).
	if data.has("rng_seed"):
		cfg.rng_seed = int(data["rng_seed"])
	cfg.seats.clear()
	for sd in data.get("seats", []):
		if sd is Dictionary:
			cfg.seats.append(SeatConfig.from_dict(sd))
	return cfg
