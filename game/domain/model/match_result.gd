class_name MatchResult
extends RefCounted
## Финален резултат от завършен мач (docs/V1_ARCHITECTURE.md, §4 / §5.2;
## docs/V1_GAME_DESIGN.md §3.1 / §5.2–5.3 / §8.1).
##
## Съдържа класирането на играчите и агрегирана статистика за мача.
## Произвежда се от MatchSession при MatchFinished и се подава към
## Application слоя за XP изчисление, Results екран и SaveRepository.record_match_result.
##
## Application „MatchSummary“ (#145) е Dictionary payload-ът от to_dict() /
## to_player_summary() плюс session метаданни (command_sequence) —
## typed моделът живее тук в domain; builder-ът е game/application/match_summary.gd.
##
## Схема:
##   schema_version, match_id, mode, campaign_level_id?,
##   ranking[]: PlayerStanding {
##     player_id, rank, animal_id, controller_type,
##     gifts_collected, pawns_captured, pawns_finished
##   }
##
## XP стойностите (победа/второ/загуба + бонуси) НЕ се пазят тук —
## Application/Progress ги изчислява от rank + статистиките (§5.2).

## Текуща версия на сериализираната схема.
const SCHEMA_VERSION := 1

## Позволен брой класирани играчи (= активни seats; §3.3).
const MIN_PLAYERS := MatchConfig.MIN_SEATS
const MAX_PLAYERS := MatchConfig.MAX_SEATS


## Класиране + статистики за един играч в края на мача.
## rank: 1 = победител; gifts/captures/finished — за XP бонуси (§5.2).
class PlayerStanding extends RefCounted:
	var player_id: StringName = &""
	## Място в класирането: 1..player_count (1 = победител).
	var rank: int = 0
	var animal_id: StringName = AnimalId.DEFAULT
	## MatchConfig.ControllerType: HUMAN | AI | REMOTE.
	var controller_type: int = MatchConfig.ControllerType.HUMAN
	var gifts_collected: int = 0
	var pawns_captured: int = 0
	var pawns_finished: int = 0


	## Фабрика за пълно конфигуриран PlayerStanding.
	static func create(
			p_player_id: StringName,
			p_rank: int,
			p_animal_id: StringName = AnimalId.DEFAULT,
			p_controller_type: int = MatchConfig.ControllerType.HUMAN,
			p_gifts_collected: int = 0,
			p_pawns_captured: int = 0,
			p_pawns_finished: int = 0
	) -> PlayerStanding:
		var standing := PlayerStanding.new()
		standing.player_id = p_player_id
		standing.rank = p_rank
		standing.animal_id = p_animal_id
		standing.controller_type = p_controller_type
		standing.gifts_collected = p_gifts_collected
		standing.pawns_captured = p_pawns_captured
		standing.pawns_finished = p_pawns_finished
		return standing


	func is_winner() -> bool:
		return rank == PlayerState.RANK_FIRST


	func is_human() -> bool:
		return controller_type == MatchConfig.ControllerType.HUMAN


	func is_ai() -> bool:
		return controller_type == MatchConfig.ControllerType.AI


	## Flat Dictionary за SaveRepository.record_match_result (платформен договор).
	func to_progress_summary() -> Dictionary:
		return {
			"rank": rank,
			"gifts_collected": gifts_collected,
			"pawns_captured": pawns_captured,
			"pawns_finished": pawns_finished,
		}


	## True ако полетата са в договорните self-contained граници.
	## Не проверява уникалност спрямо други standings — това е за MatchResult.is_valid().
	func is_valid() -> bool:
		if not PlayerId.is_valid(player_id):
			return false
		if rank < PlayerState.RANK_FIRST or rank > PlayerState.RANK_MAX:
			return false
		if not AnimalId.is_valid(animal_id):
			return false
		if (controller_type < MatchConfig.ControllerType.HUMAN
				or controller_type > MatchConfig.ControllerType.REMOTE):
			return false
		if gifts_collected < 0 or pawns_captured < 0 or pawns_finished < 0:
			return false
		if pawns_finished > PlayerState.PAWNS_PER_PLAYER:
			return false
		return true


	## JSON-safe Dictionary: StringName → String, enum като int.
	func to_dict() -> Dictionary:
		return {
			"player_id": String(player_id),
			"rank": rank,
			"animal_id": String(animal_id),
			"controller_type": controller_type,
			"gifts_collected": gifts_collected,
			"pawns_captured": pawns_captured,
			"pawns_finished": pawns_finished,
		}


	static func from_dict(data: Dictionary) -> PlayerStanding:
		return create(
				StringName(str(data.get("player_id", ""))),
				int(data.get("rank", 0)),
				StringName(str(data.get("animal_id", AnimalId.DEFAULT))),
				int(data.get("controller_type", MatchConfig.ControllerType.HUMAN)),
				int(data.get("gifts_collected", 0)),
				int(data.get("pawns_captured", 0)),
				int(data.get("pawns_finished", 0)))


	func equals(other: PlayerStanding) -> bool:
		if other == null:
			return false
		return (player_id == other.player_id
				and rank == other.rank
				and animal_id == other.animal_id
				and controller_type == other.controller_type
				and gifts_collected == other.gifts_collected
				and pawns_captured == other.pawns_captured
				and pawns_finished == other.pawns_finished)


	func duplicate_standing() -> PlayerStanding:
		return from_dict(to_dict())


## Поддържана е само текущата SCHEMA_VERSION.
static func is_schema_supported(version: int) -> bool:
	return version == SCHEMA_VERSION


var schema_version: int = SCHEMA_VERSION
var match_id: StringName = &""
## MatchConfig.Mode: FREE_PLAY | CAMPAIGN.
var mode: int = MatchConfig.Mode.FREE_PLAY
## Задължителен при CAMPAIGN; празен при FREE_PLAY.
var campaign_level_id: StringName = &""
## PlayerStanding записи; каноничният ред е по rank възходящо (1-во, 2-ро, …).
var ranking: Array = []


## Фабрика за пълно конфигуриран MatchResult (ranking се копира по референция на елементите).
static func create(
		p_match_id: StringName,
		p_ranking: Array = [],
		p_mode: int = MatchConfig.Mode.FREE_PLAY,
		p_campaign_level_id: StringName = &""
) -> MatchResult:
	var result := MatchResult.new()
	result.match_id = p_match_id
	result.mode = p_mode
	result.campaign_level_id = p_campaign_level_id
	result.ranking = p_ranking.duplicate()
	return result


## Фабрика от подреден списък player_id (index 0 = 1-во място).
## Статистиките остават 0; animal/controller са default HUMAN + DEFAULT animal.
static func create_with_rank_order(
		p_match_id: StringName,
		player_ids_in_rank_order: Array,
		p_mode: int = MatchConfig.Mode.FREE_PLAY,
		p_campaign_level_id: StringName = &""
) -> MatchResult:
	var standings: Array = []
	for i in player_ids_in_rank_order.size():
		standings.append(PlayerStanding.create(
				StringName(player_ids_in_rank_order[i]),
				i + PlayerState.RANK_FIRST))
	return create(p_match_id, standings, p_mode, p_campaign_level_id)


## Фабрика от завършен/класиран GameState за MatchSession MatchSummary (§5.2).
## mode/campaign_level_id идват от match_config; standings — от ranking[] + PlayerState.
## gifts_collected / pawns_captured остават 0 докато domain не ги агрегира на играч.
static func create_from_game_state(state: GameState) -> MatchResult:
	if state == null:
		return MatchResult.new()
	var mode: int = MatchConfig.Mode.FREE_PLAY
	var campaign_level_id: StringName = &""
	if state.match_config != null:
		mode = state.match_config.mode
		campaign_level_id = state.match_config.campaign_level_id
	var standings: Array = []
	var ranked_ids: Array[StringName] = state.get_ranked_player_ids()
	for i in ranked_ids.size():
		var player_id: StringName = ranked_ids[i]
		var rank: int = i + PlayerState.RANK_FIRST
		var player: PlayerState = state.get_player(player_id)
		if player != null:
			standings.append(PlayerStanding.create(
					player_id,
					rank,
					player.animal_id,
					player.controller_type,
					0,
					0,
					player.count_finished_pawns()))
		else:
			standings.append(PlayerStanding.create(player_id, rank))
	return create(state.match_id, standings, mode, campaign_level_id)


func is_free_play() -> bool:
	return mode == MatchConfig.Mode.FREE_PLAY


func is_campaign() -> bool:
	return mode == MatchConfig.Mode.CAMPAIGN


func player_count() -> int:
	return ranking.size()


## PlayerStanding с rank == 1, или null.
func get_winner() -> PlayerStanding:
	for entry in ranking:
		if entry is PlayerStanding and (entry as PlayerStanding).is_winner():
			return entry as PlayerStanding
	return null


func get_winner_id() -> StringName:
	var winner := get_winner()
	if winner == null:
		return &""
	return winner.player_id


func is_winner(player_id: StringName) -> bool:
	return get_winner_id() == player_id


## Връща PlayerStanding за player_id, или null.
func get_standing(player_id: StringName) -> PlayerStanding:
	for entry in ranking:
		if entry is PlayerStanding and (entry as PlayerStanding).player_id == player_id:
			return entry as PlayerStanding
	return null


## PlayerId в каноничен ред по rank (1-во → последно).
func get_ranked_player_ids() -> Array[StringName]:
	var ordered := _ranking_sorted_by_rank()
	var ids: Array[StringName] = []
	for entry in ordered:
		ids.append((entry as PlayerStanding).player_id)
	return ids


func add_standing(standing: PlayerStanding) -> void:
	ranking.append(standing)


## Замества ranking[] и нормализира реда по rank възходящо.
func set_ranking(standings: Array) -> void:
	ranking.clear()
	for entry in standings:
		if entry is PlayerStanding:
			ranking.append(entry)
	_sort_ranking_in_place()


func sort_ranking() -> void:
	_sort_ranking_in_place()


func total_gifts_collected() -> int:
	var total := 0
	for entry in ranking:
		if entry is PlayerStanding:
			total += (entry as PlayerStanding).gifts_collected
	return total


func total_pawns_captured() -> int:
	var total := 0
	for entry in ranking:
		if entry is PlayerStanding:
			total += (entry as PlayerStanding).pawns_captured
	return total


func total_pawns_finished() -> int:
	var total := 0
	for entry in ranking:
		if entry is PlayerStanding:
			total += (entry as PlayerStanding).pawns_finished
	return total


## Flat summary за SaveRepository.record_match_result за даден играч; {} ако липсва.
func to_player_summary(player_id: StringName) -> Dictionary:
	var standing := get_standing(player_id)
	if standing == null:
		return {}
	return standing.to_progress_summary()


## True ако полетата и ranking инвариантите са в договорните граници
## (§3.1 / §3.3 / §12: стабилно класиране 2–4 играчи, уникални места).
func is_valid() -> bool:
	if not is_schema_supported(schema_version):
		return false
	if not MatchId.is_valid(match_id):
		return false
	if mode < MatchConfig.Mode.FREE_PLAY or mode > MatchConfig.Mode.CAMPAIGN:
		return false
	if mode == MatchConfig.Mode.FREE_PLAY and campaign_level_id != &"":
		return false
	if mode == MatchConfig.Mode.CAMPAIGN and campaign_level_id == &"":
		return false
	var count := ranking.size()
	if count < MIN_PLAYERS or count > MAX_PLAYERS:
		return false
	var seen_players: Dictionary = {}
	var seen_ranks: Dictionary = {}
	for entry in ranking:
		if not (entry is PlayerStanding):
			return false
		var standing := entry as PlayerStanding
		if not standing.is_valid():
			return false
		if standing.rank > count:
			return false
		if seen_players.has(standing.player_id):
			return false
		if seen_ranks.has(standing.rank):
			return false
		seen_players[standing.player_id] = true
		seen_ranks[standing.rank] = true
	for expected_rank in range(PlayerState.RANK_FIRST, count + 1):
		if not seen_ranks.has(expected_rank):
			return false
	return true


## JSON-safe Dictionary (MatchSummary payload за Application / Results / save).
func to_dict() -> Dictionary:
	var ranking_dicts: Array = []
	for entry in _ranking_sorted_by_rank():
		ranking_dicts.append((entry as PlayerStanding).to_dict())
	return {
		"schema_version": schema_version,
		"match_id": String(match_id),
		"mode": mode,
		"campaign_level_id": String(campaign_level_id),
		"ranking": ranking_dicts,
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> MatchResult:
	var result := MatchResult.new()
	result.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	result.match_id = StringName(str(data.get("match_id", "")))
	result.mode = int(data.get("mode", MatchConfig.Mode.FREE_PLAY))
	result.campaign_level_id = StringName(str(data.get("campaign_level_id", "")))
	result.ranking.clear()
	for entry in data.get("ranking", []):
		if entry is Dictionary:
			result.ranking.append(PlayerStanding.from_dict(entry))
	result._sort_ranking_in_place()
	return result


## Компактен JSON низ за journal / Results payload / persistence.
func to_json() -> String:
	return JSON.stringify(to_dict())


## Десериализация от JSON. Връща null при невалиден JSON или не-Dictionary корен.
static func from_json(text: String) -> MatchResult:
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return null
	return from_dict(parsed)


## Дълбоко копие през сериализация — без споделени референции към ranking.
func duplicate_result() -> MatchResult:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат (вкл. вложени standings).
func equals(other: MatchResult) -> bool:
	if other == null:
		return false
	if (schema_version != other.schema_version
			or match_id != other.match_id
			or mode != other.mode
			or campaign_level_id != other.campaign_level_id):
		return false
	if ranking.size() != other.ranking.size():
		return false
	var a := _ranking_sorted_by_rank()
	var b := other._ranking_sorted_by_rank()
	for i in a.size():
		if not (a[i] as PlayerStanding).equals(b[i] as PlayerStanding):
			return false
	return true


func _sort_ranking_in_place() -> void:
	ranking.sort_custom(func(a, b) -> bool:
		if not (a is PlayerStanding):
			return false
		if not (b is PlayerStanding):
			return true
		return (a as PlayerStanding).rank < (b as PlayerStanding).rank
	)


func _ranking_sorted_by_rank() -> Array:
	var copy: Array = []
	for entry in ranking:
		if entry is PlayerStanding:
			copy.append(entry)
	copy.sort_custom(func(a, b) -> bool:
		return (a as PlayerStanding).rank < (b as PlayerStanding).rank
	)
	return copy
