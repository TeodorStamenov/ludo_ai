class_name GameState
extends RefCounted
## Единственият source of truth за активния мач (docs/V1_ARCHITECTURE.md, §4.1).
##
## Минимални полета:
##   schema_version, match_id, match_config, board_id, phase,
##   players[], active_player_index, turn, dice, gifts[], ranking[],
##   rng_state, command_sequence
##
## Важно: не съдържа Vector2, NodePath или editor-generated имена.
## Presentation преобразува cell_id към изометрична позиция чрез to_view().
##
## Nested модели: PlayerState, PawnState, TurnState, DiceState, GiftState.
## ranking[] = PlayerId в ред на прибиране (index 0 = 1-во място); частично
## по време на мач, пълно при MatchPhase.FINISHED.
##
## schema_version (docs/V1_ARCHITECTURE.md §4.1 / §9):
##   SCHEMA_VERSION, is_schema_supported(), migrate_dict() N → N+1, from_dict().
##
## command_sequence (docs/V1_ARCHITECTURE.md §4.1 / §11):
##   Брой приети команди от старта на мача (0 = нито една).
##   Следващата команда носи sequence == command_sequence + 1
##   (next_command_sequence()). След приемане record_accepted_command()
##   задава command_sequence = sequence на командата.
##   Част от snapshot / divergence / replay; НЕ влиза в to_view().
##
## По-нататъшно задълбочаване (отделни roadmap задачи):
##   - RNG sync / restore политика (#60)
##   - to_json / from_json (#61)
##   - стабилен state hash (#62)

## Текуща версия на сериализираната схема (docs/V1_ARCHITECTURE.md, §4.1 и §9).
## При промяна на формата: увеличава се и се добавя миграция N → N+1 в `_migrate_one_step`.
const SCHEMA_VERSION := 1

## Позволен брой активни играчи (= MatchConfig seats; §3.3).
const MIN_PLAYERS := MatchConfig.MIN_SEATS
const MAX_PLAYERS := MatchConfig.MAX_SEATS

## active_player_index когато няма активен ход (напр. преди setup / след край).
const ACTIVE_PLAYER_NONE: int = -1

## Начална стойност на command_sequence преди първата приета команда.
const COMMAND_SEQUENCE_START: int = 0


## Поддържана е само текущата SCHEMA_VERSION (след успешна миграция).
static func is_schema_supported(version: int) -> bool:
	return version == SCHEMA_VERSION


## Мигрира dictionary payload от schema_version N към SCHEMA_VERSION (стъпка по стъпка).
## Липсващ/нулев schema_version се третира като pre-versioned (0) и се качва до 1.
## Бъдещи версии (> SCHEMA_VERSION) не се пипат — остават за отхвърляне от is_valid().
static func migrate_dict(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var version: int = int(migrated.get("schema_version", 0))
	if version > SCHEMA_VERSION:
		return migrated
	while version < SCHEMA_VERSION:
		migrated = _migrate_one_step(migrated, version)
		version += 1
		migrated["schema_version"] = version
	return migrated


static func _migrate_one_step(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			# Pre-schema payloads вече ползват v1 имена на полетата.
			return data
		_:
			push_warning("GameState: няма миграция от schema_version %d" % from_version)
			return data


var schema_version: int = SCHEMA_VERSION
var match_id: StringName = &""
## Копие на конфигурацията, с която е стартиран мачът.
var match_config: MatchConfig = null
var board_id: StringName = &""
## MatchPhase: SETUP | IN_PROGRESS | FINISHED.
var phase: int = MatchPhase.SETUP
## Активни PlayerState в ред на seats от MatchConfig.
var players: Array = []
## Индекс в players[] на текущия активен играч; ACTIVE_PLAYER_NONE ако няма.
var active_player_index: int = ACTIVE_PLAYER_NONE
## Изрична turn state machine (§4.2).
var turn: TurnState = null
## Snapshot на зара (§4.1); синхрон с turn.dice_value е отговорност на GameEngine.
var dice: DiceState = null
## Активни подаръци върху дъската (GiftState); уникални по gift_id и cell_id.
var gifts: Array = []
## PlayerId в ред на класиране (0 = 1-во); празен докато никой не е прибрал 4 пионки.
var ranking: Array = []
## JSON-safe RNG snapshot {"seed","state"} от SeededRandomSource.get_state().
var rng_state: Dictionary = {}
## Брой приети команди от старта (COMMAND_SEQUENCE_START = 0). Виж § header.
var command_sequence: int = COMMAND_SEQUENCE_START


## Фабрика за пълно конфигуриран GameState (колекциите се копират плитко по елемент).
static func create(
		p_match_id: StringName,
		p_match_config: MatchConfig,
		p_board_id: StringName,
		p_phase: int = MatchPhase.SETUP,
		p_players: Array = [],
		p_active_player_index: int = ACTIVE_PLAYER_NONE,
		p_turn: TurnState = null,
		p_dice: DiceState = null,
		p_gifts: Array = [],
		p_ranking: Array = [],
		p_rng_state: Dictionary = {},
		p_command_sequence: int = COMMAND_SEQUENCE_START
) -> GameState:
	var state := GameState.new()
	state.match_id = p_match_id
	state.match_config = (
			p_match_config.duplicate_config() if p_match_config != null else null)
	state.board_id = p_board_id
	state.phase = p_phase
	state.players = p_players.duplicate()
	state.active_player_index = p_active_player_index
	state.turn = p_turn if p_turn != null else TurnState.create_match_start()
	state.dice = p_dice if p_dice != null else DiceState.create_none()
	state.gifts = p_gifts.duplicate()
	state.ranking = _normalize_ranking(p_ranking)
	state.rng_state = p_rng_state.duplicate(true)
	state.command_sequence = p_command_sequence
	return state


## Начално GameState от валиден MatchConfig: играчи в база, SETUP, празен ход.
## board_id и rng_state идват от config; match_id се генерира ако не е подаден.
static func create_from_match_config(
		config: MatchConfig,
		p_match_id: StringName = &""
) -> GameState:
	var resolved_id: StringName = p_match_id if p_match_id != &"" else MatchId.generate()
	var players_built: Array = []
	var resolved_board: StringName = &""
	var rng_seed: int = 0
	if config != null:
		resolved_board = config.board_id
		rng_seed = config.rng_seed
		for seat in config.seats:
			if seat is MatchConfig.SeatConfig:
				var seat_cfg := seat as MatchConfig.SeatConfig
				var base_cells: Array = _base_cells_for_board(
						resolved_board, seat_cfg.player_id)
				players_built.append(PlayerState.create_from_seat_config(
						seat_cfg, base_cells))
	var rng := SeededRandomSource.new(rng_seed)
	return create(
			resolved_id,
			config,
			resolved_board,
			MatchPhase.SETUP,
			players_built,
			0 if not players_built.is_empty() else ACTIVE_PLAYER_NONE,
			TurnState.create_match_start(),
			DiceState.create_none(),
			[],
			[],
			rng.get_state(),
			COMMAND_SEQUENCE_START)


func player_count() -> int:
	return players.size()


func is_setup() -> bool:
	return phase == MatchPhase.SETUP


func is_in_progress() -> bool:
	return phase == MatchPhase.IN_PROGRESS


func is_finished() -> bool:
	return phase == MatchPhase.FINISHED


func phase_name() -> StringName:
	return MatchPhase.phase_name(phase)


## PlayerId на активния играч, или &"" ако няма.
func get_active_player_id() -> StringName:
	var player := get_active_player()
	if player == null:
		return &""
	return player.player_id


## PlayerState на активния играч, или null.
func get_active_player() -> PlayerState:
	if active_player_index < 0 or active_player_index >= players.size():
		return null
	var entry = players[active_player_index]
	if entry is PlayerState:
		return entry as PlayerState
	return null


## PlayerState по player_id, или null.
func get_player(player_id: StringName) -> PlayerState:
	for entry in players:
		if entry is PlayerState and (entry as PlayerState).player_id == player_id:
			return entry as PlayerState
	return null


## PlayerState по индекс в players[], или null.
func get_player_by_index(index: int) -> PlayerState:
	if index < 0 or index >= players.size():
		return null
	var entry = players[index]
	if entry is PlayerState:
		return entry as PlayerState
	return null


## Индекс на player_id в players[], или ACTIVE_PLAYER_NONE.
func index_of_player(player_id: StringName) -> int:
	for i in players.size():
		var entry = players[i]
		if entry is PlayerState and (entry as PlayerState).player_id == player_id:
			return i
	return ACTIVE_PLAYER_NONE


## PawnState по pawn_id във всички играчи, или null.
func get_pawn(pawn_id: StringName) -> PawnState:
	for entry in players:
		if entry is PlayerState:
			var pawn := (entry as PlayerState).get_pawn(pawn_id)
			if pawn != null:
				return pawn
	return null


func set_active_player_index(index: int) -> void:
	active_player_index = index


## Задава активния играч по player_id. Връща false ако липсва.
func set_active_player(player_id: StringName) -> bool:
	var idx := index_of_player(player_id)
	if idx == ACTIVE_PLAYER_NONE:
		return false
	active_player_index = idx
	return true


func set_phase(p_phase: int) -> void:
	phase = p_phase


## GiftState на клетката, или null.
func get_gift_at(cell_id: StringName) -> GiftState:
	for entry in gifts:
		if entry is GiftState and (entry as GiftState).is_on_cell(cell_id):
			return entry as GiftState
	return null


func get_gift(gift_id: StringName) -> GiftState:
	for entry in gifts:
		if entry is GiftState and (entry as GiftState).gift_id == gift_id:
			return entry as GiftState
	return null


func add_gift(gift: GiftState) -> void:
	gifts.append(gift)


## Премахва подарък по gift_id. Връща true ако е намерен.
func remove_gift(gift_id: StringName) -> bool:
	for i in gifts.size():
		var entry = gifts[i]
		if entry is GiftState and (entry as GiftState).gift_id == gift_id:
			gifts.remove_at(i)
			return true
	return false


## Добавя player_id в ranking[] (следващо място) и обновява PlayerState.rank.
## Връща присвоеното място (1-based), или 0 ако вече е класиран / липсва.
func rank_player(player_id: StringName) -> int:
	if not has_player(player_id):
		return 0
	if is_ranked(player_id):
		return 0
	ranking.append(player_id)
	var rank_value: int = ranking.size()
	var player := get_player(player_id)
	if player != null:
		player.set_rank(rank_value)
	return rank_value


func is_ranked(player_id: StringName) -> bool:
	var id_str := String(player_id)
	for entry in ranking:
		if str(entry) == id_str:
			return true
	return false


func has_player(player_id: StringName) -> bool:
	return get_player(player_id) != null


## PlayerId в каноничен ред на класиране (копие).
func get_ranked_player_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in ranking:
		ids.append(StringName(str(entry)))
	return ids


## Sequence номер, който следващата приета команда трябва да носи (§11).
func next_command_sequence() -> int:
	return command_sequence + 1


## True ако `sequence` е точно следващият очакван номер (без пропуск/дубликат).
func is_expected_command_sequence(sequence: int) -> bool:
	return sequence == next_command_sequence()


## Записва приета команда. Връща false при out-of-order / дубликат —
## тогава command_sequence не се променя (инвариант: невалидна команда
## не пипа state; §12). При успех command_sequence = sequence.
func record_accepted_command(sequence: int) -> bool:
	if not is_expected_command_sequence(sequence):
		return false
	command_sequence = sequence
	return true


## Инкрементира с 1 (еквивалент на record_accepted_command(next_command_sequence())).
func advance_command_sequence() -> int:
	command_sequence += 1
	return command_sequence


## Задава sequence при restore от snapshot. Отрицателни стойности → START.
func set_command_sequence(value: int) -> void:
	command_sequence = value if value >= COMMAND_SEQUENCE_START else COMMAND_SEQUENCE_START


## Попълва match_id и sequence на команда според текущия GameState.
## Не променя command_sequence — това става едва след приемане.
func stamp_command(command: GameCommand) -> GameCommand:
	if command == null:
		return null
	command.match_id = match_id
	command.sequence = next_command_sequence()
	return command


func set_rng_state(state: Dictionary) -> void:
	rng_state = state.duplicate(true)


## Read-only view model за Presentation / GamePresenter (§6.1).
## Без rng_state / command_sequence / вътрешни engine полета.
func to_view() -> Dictionary:
	var player_views: Array = []
	for entry in players:
		if entry is PlayerState:
			player_views.append((entry as PlayerState).to_dict())
	var gift_views: Array = []
	for entry in gifts:
		if entry is GiftState:
			gift_views.append((entry as GiftState).to_dict())
	var ranked: Array = []
	for entry in ranking:
		ranked.append(str(entry))
	var turn_view: Dictionary = turn.to_dict() if turn != null else {}
	var dice_view: Dictionary = dice.to_dict() if dice != null else {}
	return {
		"match_id": String(match_id),
		"board_id": String(board_id),
		"phase": phase,
		"phase_name": String(phase_name()),
		"active_player_id": String(get_active_player_id()),
		"active_player_index": active_player_index,
		"players": player_views,
		"turn": turn_view,
		"dice": dice_view,
		"gifts": gift_views,
		"ranking": ranked,
		"valid_pawn_ids": (
				turn_view.get("valid_pawn_ids", []) if turn != null else []),
	}


## Валидни команди за текущия активен играч според TurnState.valid_*.
## Не прилага game rules — само snapshot на вече изчислените валидни действия.
func get_legal_actions() -> Array:
	var actions: Array = []
	if turn == null:
		return actions
	var active_id := get_active_player_id()
	if active_id == &"":
		return actions
	if turn.allows_roll_dice():
		actions.append(stamp_command(RollDiceCommand.new(active_id)))
	if turn.allows_move_pawn():
		for pawn_entry in turn.valid_pawn_ids:
			actions.append(stamp_command(
					MovePawnCommand.new(active_id, StringName(str(pawn_entry)))))
	return actions


## True ако полетата и nested инвариантите са в договорните граници (§4.1 / §12).
func is_valid() -> bool:
	if not is_schema_supported(schema_version):
		return false
	if not MatchId.is_valid(match_id):
		return false
	if match_config == null or not match_config.is_valid():
		return false
	if board_id == &"" or board_id != match_config.board_id:
		return false
	if not MatchPhase.is_valid(phase):
		return false
	var count := players.size()
	if count < MIN_PLAYERS or count > MAX_PLAYERS:
		return false
	if count != match_config.get_active_seat_count():
		return false
	var config_ids := match_config.get_active_player_ids()
	var seen_players: Dictionary = {}
	for i in count:
		var entry = players[i]
		if not (entry is PlayerState):
			return false
		var player := entry as PlayerState
		if not player.is_valid():
			return false
		if player.player_id != config_ids[i]:
			return false
		if seen_players.has(player.player_id):
			return false
		seen_players[player.player_id] = true
	if active_player_index != ACTIVE_PLAYER_NONE:
		if active_player_index < 0 or active_player_index >= count:
			return false
	if turn == null or not turn.is_valid():
		return false
	if dice == null or not dice.is_valid():
		return false
	if not _are_gifts_valid(gifts):
		return false
	if not _is_ranking_valid(ranking, seen_players):
		return false
	if command_sequence < 0:
		return false
	if not _is_rng_state_valid(rng_state):
		return false
	return true


## JSON-safe Dictionary: StringName → String, nested модели чрез to_dict().
## Без Vector2 / NodePath — само стабилни идентификатори (§4.1).
func to_dict() -> Dictionary:
	var player_dicts: Array = []
	for entry in players:
		if entry is PlayerState:
			player_dicts.append((entry as PlayerState).to_dict())
	var gift_dicts: Array = []
	for entry in gifts:
		if entry is GiftState:
			gift_dicts.append((entry as GiftState).to_dict())
	var ranked: Array = []
	for entry in ranking:
		ranked.append(str(entry))
	return {
		"schema_version": schema_version,
		"match_id": String(match_id),
		"match_config": match_config.to_dict() if match_config != null else {},
		"board_id": String(board_id),
		"phase": phase,
		"players": player_dicts,
		"active_player_index": active_player_index,
		"turn": turn.to_dict() if turn != null else {},
		"dice": dice.to_dict() if dice != null else {},
		"gifts": gift_dicts,
		"ranking": ranked,
		"rng_state": rng_state.duplicate(true),
		"command_sequence": command_sequence,
	}


## Десериализация от Dictionary. Мигрира schema_version < SCHEMA_VERSION;
## бъдещи версии се запазват (is_valid() ги отхвърля). Липсващи полета → defaults.
static func from_dict(data: Dictionary) -> GameState:
	var raw_version: int = int(data.get("schema_version", 0))
	var working: Dictionary = data
	if raw_version < SCHEMA_VERSION:
		working = migrate_dict(data)
	elif raw_version > SCHEMA_VERSION:
		push_warning("GameState: неподдържан бъдещ schema_version %d (текущ %d)" % [
			raw_version, SCHEMA_VERSION])

	var state := GameState.new()
	state.schema_version = int(working.get("schema_version", SCHEMA_VERSION))
	state.match_id = StringName(str(working.get("match_id", "")))
	var cfg_data = working.get("match_config", {})
	if cfg_data is Dictionary and not (cfg_data as Dictionary).is_empty():
		state.match_config = MatchConfig.from_dict(cfg_data)
	else:
		state.match_config = null
	state.board_id = StringName(str(working.get("board_id", "")))
	state.phase = int(working.get("phase", MatchPhase.SETUP))
	state.active_player_index = int(working.get("active_player_index", ACTIVE_PLAYER_NONE))
	state.command_sequence = int(working.get("command_sequence", COMMAND_SEQUENCE_START))
	var rng = working.get("rng_state", {})
	if rng is Dictionary:
		state.rng_state = (rng as Dictionary).duplicate(true)
	else:
		state.rng_state = {}
	state.players.clear()
	for pd in working.get("players", []):
		if pd is Dictionary:
			state.players.append(PlayerState.from_dict(pd))
	var turn_data = working.get("turn", {})
	if turn_data is Dictionary and not (turn_data as Dictionary).is_empty():
		state.turn = TurnState.from_dict(turn_data)
	else:
		state.turn = TurnState.create_match_start()
	var dice_data = working.get("dice", {})
	if dice_data is Dictionary and not (dice_data as Dictionary).is_empty():
		state.dice = DiceState.from_dict(dice_data)
	else:
		state.dice = DiceState.create_none()
	state.gifts.clear()
	for gd in working.get("gifts", []):
		if gd is Dictionary:
			state.gifts.append(GiftState.from_dict(gd))
	var ranking_data = working.get("ranking", [])
	if ranking_data is Array:
		state.ranking = _normalize_ranking(ranking_data)
	else:
		state.ranking = []
	return state


## Дълбоко копие през сериализация — без споделени референции.
func duplicate_state() -> GameState:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат (вкл. nested модели).
func equals(other: GameState) -> bool:
	if other == null:
		return false
	if (schema_version != other.schema_version
			or match_id != other.match_id
			or board_id != other.board_id
			or phase != other.phase
			or active_player_index != other.active_player_index
			or command_sequence != other.command_sequence):
		return false
	if match_config == null:
		if other.match_config != null:
			return false
	elif other.match_config == null or not match_config.equals(other.match_config):
		return false
	if turn == null:
		if other.turn != null:
			return false
	elif other.turn == null or not turn.equals(other.turn):
		return false
	if dice == null:
		if other.dice != null:
			return false
	elif other.dice == null or not dice.equals(other.dice):
		return false
	if players.size() != other.players.size():
		return false
	for i in players.size():
		var a = players[i]
		var b = other.players[i]
		if not (a is PlayerState) or not (b is PlayerState):
			return false
		if not (a as PlayerState).equals(b as PlayerState):
			return false
	if gifts.size() != other.gifts.size():
		return false
	for i in gifts.size():
		var ga = gifts[i]
		var gb = other.gifts[i]
		if not (ga is GiftState) or not (gb is GiftState):
			return false
		if not (ga as GiftState).equals(gb as GiftState):
			return false
	if ranking.size() != other.ranking.size():
		return false
	for i in ranking.size():
		if str(ranking[i]) != str(other.ranking[i]):
			return false
	return _rng_state_equal(rng_state, other.rng_state)


static func _base_cells_for_board(p_board_id: StringName, player_id: StringName) -> Array:
	if p_board_id == Classic15x15Board.BOARD_ID or p_board_id == BoardDefinition.DEFAULT_BOARD_ID:
		return Classic15x15Board.base_cells_for(player_id)
	return []


static func _normalize_ranking(entries: Array) -> Array:
	var copy: Array = []
	for entry in entries:
		copy.append(StringName(str(entry)))
	return copy


static func _are_gifts_valid(gift_list: Array) -> bool:
	var seen_ids: Dictionary = {}
	var seen_cells: Dictionary = {}
	for entry in gift_list:
		if not (entry is GiftState):
			return false
		var gift := entry as GiftState
		if not gift.is_valid():
			return false
		var gid := String(gift.gift_id)
		var cid := String(gift.cell_id)
		if seen_ids.has(gid) or seen_cells.has(cid):
			return false
		seen_ids[gid] = true
		seen_cells[cid] = true
	return true


static func _is_ranking_valid(ranked: Array, known_players: Dictionary) -> bool:
	var seen: Dictionary = {}
	for entry in ranked:
		var pid := StringName(str(entry))
		if not known_players.has(pid):
			return false
		if seen.has(String(pid)):
			return false
		seen[String(pid)] = true
	return true


static func _is_rng_state_valid(state: Dictionary) -> bool:
	if state.is_empty():
		return true
	if not state.has("seed") or not state.has("state"):
		return false
	# JSON-safe: seed/state са String (SeededRandomSource) или int.
	var seed_v: Variant = state["seed"]
	var state_v: Variant = state["state"]
	var seed_ok := typeof(seed_v) == TYPE_STRING or typeof(seed_v) == TYPE_INT
	var state_ok := typeof(state_v) == TYPE_STRING or typeof(state_v) == TYPE_INT
	return seed_ok and state_ok


static func _rng_state_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	if a.is_empty() and b.is_empty():
		return true
	return str(a.get("seed", "")) == str(b.get("seed", "")) \
			and str(a.get("state", "")) == str(b.get("state", ""))
