class_name MatchConfig
extends RefCounted
## Сериализируем модел на конфигурацията за мач (docs/V1_ARCHITECTURE.md, раздел 5.1).
##
## И свободната игра, и кампанията произвеждат MatchConfig;
## GameScreen зависи само от него и не знае нищо за менютата.
##
## Живее в domain/model/, защото е чист value object без странични ефекти
## и домейнът го нужда директно (GameState.match_config, StartMatchCommand.config).
## Валидацията е в MatchConfigValidator — is_valid() делегира към него.
##
## Сериализация (issue #27 / docs/V1_ARCHITECTURE.md §9 и §16.2):
##   to_dict() / from_dict() — Dictionary с JSON-примитиви (String, int, Array, Dictionary);
##   to_json() / from_json() — текстов за persistence / journal / snapshot payload;
##   equals() / duplicate_config() — беззагубен round-trip и копие без споделени референции.
##   StringName полета се записват като String; from_dict ги възстановява към StringName.
##   Миграция на schema_version N → SCHEMA_VERSION е в migrate_dict() / from_dict().
##
## Схема:
##   schema_version, mode, board_id, theme_id,
##   seats[], campaign_level_id?, level_modifiers[], pre_match_bonus?, rng_seed
##
## Активни места (docs/V1_GAME_DESIGN.md §3.3 / §8.2):
##   дъската има винаги 4 seats (PlayerId); мачът активира 2, 3 или 4 от тях.
##   При 2 играчи — само срещуположни бази; при 3 — кои да е три от четирите;
##   при 4 — всички.
##
## Всяко място носи (docs/V1_ARCHITECTURE.md §5.1 / docs/V1_GAME_DESIGN.md §8.2):
##   player_id, controller_type (HUMAN|AI|REMOTE), ai_difficulty? (само при AI), animal_id.
##
## Тема / кампания (docs/V1_ARCHITECTURE.md §5.1 / docs/V1_GAME_DESIGN.md §5.1 / §8.2):
##   theme_id (ThemeId), campaign_level_id? (задължителен при Mode.CAMPAIGN),
##   level_modifiers[] (LevelModifierId; типично от CampaignLevelDefinition).

## Текуща версия на сериализираната схема (docs/V1_ARCHITECTURE.md, §5.1 и §9).
## При промяна на формата: увеличава се и се добавя миграция N → N+1 в `_migrate_one_step`.
const SCHEMA_VERSION := 1

## Позволен брой активни места в мач (docs/V1_GAME_DESIGN.md §3.3).
const MIN_SEATS := 2
const MAX_SEATS := 4

## Подразбиращи се активни seats по брой играчи.
## 2P: срещуположни бази GREEN ↔ YELLOW (NW–SE) — PlayerId.OPPOSITE_PAIR_GREEN_YELLOW.
## Алтернативната 2P двойка: ORANGE ↔ CYAN (NE–SW) — ALTERNATE_SEATS_2P / Task #44.
## 3P: три от четирите — GREEN, ORANGE, YELLOW (без CYAN) — PlayerId.TRIO_WITHOUT_CYAN / Task #45.
## 4P: всички места — PlayerId.ALL / Task #46.
const DEFAULT_SEATS_2P: Array[StringName] = [PlayerId.GREEN, PlayerId.YELLOW]
const ALTERNATE_SEATS_2P: Array[StringName] = [PlayerId.ORANGE, PlayerId.CYAN]
const DEFAULT_SEATS_3P: Array[StringName] = [
	PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW,
]
const DEFAULT_SEATS_4P: Array[StringName] = [
	PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, PlayerId.CYAN,
]

enum Mode { FREE_PLAY = 0, CAMPAIGN = 1 }
## Controller типове за seats[] (docs/V1_ARCHITECTURE.md §5.1: HUMAN | AI | REMOTE).
## REMOTE е placeholder за v2; AI difficulty живее в domain AIDifficulty.
enum ControllerType { HUMAN = 0, AI = 1, REMOTE = 2 }


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
			push_warning("MatchConfig: няма миграция от schema_version %d" % from_version)
			return data


## Конфигурация на едно активно място в мача.
## Задължителни полета: player_id, controller_type, animal_id.
## ai_difficulty е значимо само при controller_type == AI.
class SeatConfig extends RefCounted:
	var player_id: StringName = &""
	var controller_type: int = ControllerType.HUMAN
	var ai_difficulty: int = AIDifficulty.EASY
	var animal_id: StringName = AnimalId.DEFAULT

	func is_human() -> bool:
		return controller_type == ControllerType.HUMAN

	func is_ai() -> bool:
		return controller_type == ControllerType.AI

	func is_remote() -> bool:
		return controller_type == ControllerType.REMOTE

	## ai_difficulty е задължителен само за AI (docs/V1_ARCHITECTURE.md §5.1: ai_difficulty?).
	func requires_ai_difficulty() -> bool:
		return controller_type == ControllerType.AI

	## Задава controller_type, animal_id и (при AI) ai_difficulty на мястото.
	func configure(p_controller_type: int, p_animal_id: StringName,
			p_ai_difficulty: int = AIDifficulty.EASY) -> void:
		controller_type = p_controller_type
		animal_id = p_animal_id
		ai_difficulty = p_ai_difficulty

	## Seat-ниво валидация на controller_type, animal_id и ai_difficulty.
	func is_seat_valid() -> bool:
		if not PlayerId.is_valid(player_id):
			return false
		if not AnimalId.is_valid(animal_id):
			return false
		if controller_type < ControllerType.HUMAN or controller_type > ControllerType.REMOTE:
			return false
		if requires_ai_difficulty() and not AIDifficulty.is_valid(ai_difficulty):
			return false
		return true

	## JSON-safe Dictionary: StringName → String, числови enum-и като int.
	func to_dict() -> Dictionary:
		return {
			"player_id": String(player_id),
			"controller_type": controller_type,
			"ai_difficulty": ai_difficulty,
			"animal_id": String(animal_id),
		}

	static func from_dict(data: Dictionary) -> SeatConfig:
		var seat := SeatConfig.new()
		seat.player_id = StringName(str(data.get("player_id", "")))
		seat.controller_type = int(data.get("controller_type", ControllerType.HUMAN))
		seat.ai_difficulty = int(data.get("ai_difficulty", AIDifficulty.EASY))
		seat.animal_id = StringName(str(data.get("animal_id", AnimalId.DEFAULT)))
		return seat

	## True ако всички сериализируеми полета съвпадат (JSON-семантика: 2 == 2.0).
	func equals(other: SeatConfig) -> bool:
		if other == null:
			return false
		return MatchConfig._json_equal(to_dict(), other.to_dict())

	## Фабрика за пълно конфигурирано място.
	static func create(p_player_id: StringName, p_controller_type: int,
			p_animal_id: StringName, p_ai_difficulty: int = AIDifficulty.EASY) -> SeatConfig:
		var seat := SeatConfig.new()
		seat.player_id = p_player_id
		seat.configure(p_controller_type, p_animal_id, p_ai_difficulty)
		return seat


var schema_version: int = SCHEMA_VERSION
var mode: int = Mode.FREE_PLAY
var board_id: StringName = &"classic_15x15"
var theme_id: StringName = ThemeId.DEFAULT
var seats: Array = []
## Задължителен при Mode.CAMPAIGN; празен при Mode.FREE_PLAY (§5.1: campaign_level_id?).
var campaign_level_id: StringName = &""
## Кампанийни модификатори (LevelModifierId); празен списък е валиден.
var level_modifiers: Array = []
var pre_match_bonus: Dictionary = {}
## Един seed за целия мач (зар, подаръци, power-up параметри) — §4.5 / §5.1.
## 0 е валидна изрична стойност (напр. тестове); липсващ seed при from_dict не го форсира.
var rng_seed: int = 0


func _init() -> void:
	rng_seed = generate_rng_seed()


## Автоматичен seed за нов мач. Избягва 0, за да се различава от „изрично нула“ в логове.
static func generate_rng_seed() -> int:
	var generated: int = randi()
	if generated == 0:
		return 1
	return generated


## Създава детерминиран RNG от rng_seed (docs/V1_ARCHITECTURE.md, §4.5).
## Еднакъв seed → еднакви next_int/pick последователности.
func create_random_source() -> SeededRandomSource:
	return SeededRandomSource.new(rng_seed)


func add_seat(p_player_id: StringName, p_controller_type: int, p_animal_id: StringName,
		p_ai_difficulty: int = AIDifficulty.EASY) -> void:
	seats.append(SeatConfig.create(p_player_id, p_controller_type, p_animal_id, p_ai_difficulty))


## Връща SeatConfig за даден player_id, или null ако мястото не е активно.
func get_seat(player_id: StringName) -> SeatConfig:
	for seat: SeatConfig in seats:
		if seat.player_id == player_id:
			return seat
	return null


## Задава controller_type, animal_id и ai_difficulty на вече активно място.
## Връща false ако player_id не е сред активните seats.
func configure_seat(player_id: StringName, p_controller_type: int, p_animal_id: StringName,
		p_ai_difficulty: int = AIDifficulty.EASY) -> bool:
	var seat := get_seat(player_id)
	if seat == null:
		return false
	seat.configure(p_controller_type, p_animal_id, p_ai_difficulty)
	return true


## True ако count е 2, 3 или 4.
static func is_supported_seat_count(count: int) -> bool:
	return count >= MIN_SEATS and count <= MAX_SEATS


## Подразбиращи се PlayerId за даден брой активни места.
## При неподдържан count връща празен масив.
static func default_seats_for_count(count: int) -> Array[StringName]:
	match count:
		2:
			return DEFAULT_SEATS_2P.duplicate()
		3:
			return DEFAULT_SEATS_3P.duplicate()
		4:
			return DEFAULT_SEATS_4P.duplicate()
		_:
			return []


## True ако a и b са срещуположни бази (GREEN↔YELLOW или ORANGE↔CYAN).
## Делегира към PlayerId — геометричният source of truth за seats.
static func are_opposite_seats(a: StringName, b: StringName) -> bool:
	return PlayerId.are_opposite(a, b)


## Двете валидни срещуположни двойки за 2P (копия; Task #44 / §3.3).
static func opposite_seat_pairs() -> Array:
	return [
		DEFAULT_SEATS_2P.duplicate(),
		ALTERNATE_SEATS_2P.duplicate(),
	]


## True ако player_ids е точно една валидна срещуположна двойка (редът няма значение).
static func is_valid_two_player_seats(player_ids: Array) -> bool:
	if player_ids.size() != 2:
		return false
	var a := StringName(player_ids[0])
	var b := StringName(player_ids[1])
	if not PlayerId.is_valid(a) or not PlayerId.is_valid(b):
		return false
	return are_opposite_seats(a, b)


## Създава 2P MatchConfig със срещуположни бази (Task #44).
## Празна/липсваща двойка → DEFAULT_SEATS_2P (GREEN↔YELLOW).
## Невалидна двойка все пак се записва — is_valid() я отхвърля.
static func create_two_player_opposite(p_seats: Array = []) -> MatchConfig:
	var cfg := MatchConfig.new()
	if p_seats.is_empty():
		cfg.set_active_seats(DEFAULT_SEATS_2P)
	else:
		cfg.set_active_seats(p_seats)
	return cfg


## Четирите валидни 3P тройки (копия; Task #45 / §3.3).
## Първата е DEFAULT_SEATS_3P (без CYAN).
static func three_player_seat_trios() -> Array:
	return PlayerId.three_player_trios()


## True ако player_ids е точно три различни валидни PlayerId (редът няма значение).
## Делегира към PlayerId — source of truth за seats (§3.3: кои да е три от четирите).
static func is_valid_three_player_seats(player_ids: Array) -> bool:
	return PlayerId.is_valid_three_player_trio(player_ids)


## Създава 3P MatchConfig с три от четирите seats (Task #45).
## Празна/липсваща тройка → DEFAULT_SEATS_3P (GREEN, ORANGE, YELLOW).
## Невалидна тройка все пак се записва — is_valid() я отхвърля.
static func create_three_player(p_seats: Array = []) -> MatchConfig:
	var cfg := MatchConfig.new()
	if p_seats.is_empty():
		cfg.set_active_seats(DEFAULT_SEATS_3P)
	else:
		cfg.set_active_seats(p_seats)
	return cfg


## Единственият валиден 4P набор — всички seats (копие; Task #46 / §3.3).
## Съвпада с DEFAULT_SEATS_4P / PlayerId.ALL.
static func four_player_seat_set() -> Array[StringName]:
	return PlayerId.all_seats()


## True ако player_ids е точно четирите различни валидни PlayerId (редът няма значение).
## Делегира към PlayerId — source of truth за seats (§3.3: при 4 — всички).
static func is_valid_four_player_seats(player_ids: Array) -> bool:
	return PlayerId.is_valid_four_player_set(player_ids)


## Създава 4P MatchConfig с всички seats (Task #46).
## Празна/липсващ набор → DEFAULT_SEATS_4P (GREEN, ORANGE, YELLOW, CYAN).
## Невалиден набор все пак се записва — is_valid() го отхвърля.
static func create_four_player(p_seats: Array = []) -> MatchConfig:
	var cfg := MatchConfig.new()
	if p_seats.is_empty():
		cfg.set_active_seats(DEFAULT_SEATS_4P)
	else:
		cfg.set_active_seats(p_seats)
	return cfg


## Създава MatchConfig с подразбиращите се активни места за 2/3/4 играчи.
## При неподдържан count връща config без seats (is_valid() == false).
static func create_with_seat_count(count: int) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.set_active_seats(default_seats_for_count(count))
	return cfg


func get_active_seat_count() -> int:
	return seats.size()


## PlayerId на активните места в реда, в който са конфигурирани.
func get_active_player_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for seat: SeatConfig in seats:
		ids.append(seat.player_id)
	return ids


func has_active_seat(player_id: StringName) -> bool:
	return get_seat(player_id) != null


func clear_seats() -> void:
	seats.clear()


## Замества seats[] с нови активни места (controller HUMAN, animal DEFAULT).
## Match Setup / Campaign попълват controller/difficulty/animal чрез configure_seat().
func set_active_seats(player_ids: Array) -> void:
	seats.clear()
	for pid in player_ids:
		add_seat(StringName(pid), ControllerType.HUMAN, AnimalId.DEFAULT)


func is_free_play() -> bool:
	return mode == Mode.FREE_PLAY


func is_campaign() -> bool:
	return mode == Mode.CAMPAIGN


## Задава визуалната тема на мача (ThemeId). Не влияе на правилата.
func set_theme(p_theme_id: StringName) -> void:
	theme_id = p_theme_id


## Конфигурира кампанийен мач: mode=CAMPAIGN, level, theme и modifiers.
## Match Setup ползва FREE_PLAY; Campaign екранът вика този метод.
func configure_campaign(p_level_id: StringName, p_theme_id: StringName,
		p_modifiers: Array = []) -> void:
	mode = Mode.CAMPAIGN
	campaign_level_id = p_level_id
	theme_id = p_theme_id
	set_level_modifiers(p_modifiers)


## Връща към свободна игра: mode=FREE_PLAY, празен level и modifiers.
## Запазва текущия theme_id (играчът може да е избрал тема в Match Setup).
func clear_campaign() -> void:
	mode = Mode.FREE_PLAY
	campaign_level_id = &""
	level_modifiers.clear()


## Замества level_modifiers[] с нормализирани LevelModifierId стойности.
func set_level_modifiers(modifiers: Array) -> void:
	level_modifiers.clear()
	for mod in modifiers:
		level_modifiers.append(StringName(mod))


## Добавя level modifier, ако още го няма. Връща false при дубликат.
func add_level_modifier(modifier_id: StringName) -> bool:
	if has_level_modifier(modifier_id):
		return false
	level_modifiers.append(modifier_id)
	return true


func clear_level_modifiers() -> void:
	level_modifiers.clear()


func has_level_modifier(modifier_id: StringName) -> bool:
	for mod in level_modifiers:
		if StringName(mod) == modifier_id:
			return true
	return false


func get_level_modifier_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for mod in level_modifiers:
		ids.append(StringName(mod))
	return ids


## True ако theme_id, campaign_level_id? и level_modifiers[] са в договорните граници.
## Делегира към MatchConfigValidator (issue #26).
func are_theme_and_campaign_fields_valid() -> bool:
	return MatchConfigValidator.are_theme_and_campaign_fields_valid(self)


## True ако целият MatchConfig е в договорните граници (§5.1 / §3.3 / §8.2).
## Делегира към MatchConfigValidator — за подробности ползвай
## MatchConfigValidator.validate(self).
func is_valid() -> bool:
	return MatchConfigValidator.is_valid(self)


## JSON-safe Dictionary payload (docs/V1_ARCHITECTURE.md §5.1 / §9).
## StringName ID-та се записват като String; вложените seats/bonus са независими копия.
func to_dict() -> Dictionary:
	var seat_dicts: Array = []
	for seat: SeatConfig in seats:
		seat_dicts.append(seat.to_dict())
	var modifier_ids: Array = []
	for mod in level_modifiers:
		modifier_ids.append(String(mod))
	return {
		"schema_version": schema_version,
		"mode": mode,
		"board_id": String(board_id),
		"theme_id": String(theme_id),
		"seats": seat_dicts,
		"campaign_level_id": String(campaign_level_id),
		"level_modifiers": modifier_ids,
		"pre_match_bonus": pre_match_bonus.duplicate(true),
		"rng_seed": rng_seed,
	}


## Десериализация от Dictionary. Мигрира schema_version < SCHEMA_VERSION;
## бъдещи версии се запазват (is_valid() ги отхвърля).
static func from_dict(data: Dictionary) -> MatchConfig:
	var raw_version: int = int(data.get("schema_version", 0))
	var working: Dictionary = data
	if raw_version < SCHEMA_VERSION:
		working = migrate_dict(data)
	elif raw_version > SCHEMA_VERSION:
		push_warning("MatchConfig: неподдържан бъдещ schema_version %d (текущ %d)" % [
			raw_version, SCHEMA_VERSION])

	var cfg := MatchConfig.new()
	cfg.schema_version = int(working.get("schema_version", SCHEMA_VERSION))
	cfg.mode = int(working.get("mode", Mode.FREE_PLAY))
	cfg.board_id = StringName(str(working.get("board_id", "classic_15x15")))
	cfg.theme_id = StringName(str(working.get("theme_id", ThemeId.DEFAULT)))
	cfg.campaign_level_id = StringName(str(working.get("campaign_level_id", "")))
	cfg.set_level_modifiers(working.get("level_modifiers", []))
	var bonus = working.get("pre_match_bonus", {})
	if bonus is Dictionary:
		cfg.pre_match_bonus = (bonus as Dictionary).duplicate(true)
	else:
		cfg.pre_match_bonus = {}
	# Липсващ rng_seed запазва авто-генерирания от _init (не форсира 0).
	if working.has("rng_seed"):
		cfg.rng_seed = int(working["rng_seed"])
	cfg.seats.clear()
	for sd in working.get("seats", []):
		if sd is Dictionary:
			cfg.seats.append(SeatConfig.from_dict(sd))
	return cfg


## Компактен JSON низ за journal / snapshot payload / file persistence (§9).
func to_json() -> String:
	return JSON.stringify(to_dict())


## Десериализация от JSON текст. Връща null при невалиден JSON или не-Dictionary корен.
static func from_json(text: String) -> MatchConfig:
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return null
	return from_dict(parsed)


## Дълбоко копие през сериализация — без споделени референции към seats/bonus.
func duplicate_config() -> MatchConfig:
	return from_dict(to_dict())


## True ако сериализируемите полета съвпадат (беззагубен round-trip критерий, §16.2).
## Нормализира през JSON parse/stringify, за да третира 2 и 2.0 еднакво.
func equals(other: MatchConfig) -> bool:
	if other == null:
		return false
	return _json_equal(to_dict(), other.to_dict())


## Сравнява два JSON-съвместими Variant-а след обща нормализация на числовите типове.
static func _json_equal(a: Variant, b: Variant) -> bool:
	var na = JSON.parse_string(JSON.stringify(a))
	var nb = JSON.parse_string(JSON.stringify(b))
	if na == null or nb == null:
		return false
	return JSON.stringify(na) == JSON.stringify(nb)
