class_name GameplayJournal
extends RefCounted
## Append-only journal на активния мач за replay, divergence и bug reports
## (docs/V1_ARCHITECTURE.md §11 / §12 / §16.3; roadmap #132–#138).
##
## MatchSession притежава един journal за активния мач. Journal-ът не прилага
## правила — само записва факти (header, приети/отхвърлени команди, state hash).
## Deterministic replay (#137) чете seed + accepted commands и възпроизвежда мача.
##
## Сериализация: to_dict() / from_dict() / to_json() / from_json().
## command_from_dict() диспечира към конкретния GameCommand subclass по command_type
## (GameCommand.from_dict нарочно не го прави — виж domain/commands/game_command.gd).

const SCHEMA_VERSION := 1
## Стабилна версия на content/правила за replay / bug report (§16.3 / #133).
const CONTENT_VERSION: StringName = &"1"

const KEY_SCHEMA_VERSION := "schema_version"
const KEY_MATCH_ID := "match_id"
const KEY_MATCH_CONFIG := "match_config"
const KEY_RNG_SEED := "rng_seed"
const KEY_CONTENT_VERSION := "content_version"
const KEY_ENTRIES := "entries"

const ENTRY_KIND := "kind"
const ENTRY_COMMAND := "command"
const ENTRY_REASON := "reason"
const ENTRY_SEQUENCE := "sequence"
const ENTRY_HASH := "hash"

const KIND_ACCEPTED_COMMAND: StringName = &"accepted_command"
const KIND_REJECTED_COMMAND: StringName = &"rejected_command"
const KIND_STATE_HASH: StringName = &"state_hash"

const ALL_KINDS: Array[StringName] = [
	KIND_ACCEPTED_COMMAND,
	KIND_REJECTED_COMMAND,
	KIND_STATE_HASH,
]


var schema_version: int = SCHEMA_VERSION
var match_id: StringName = &""
var match_config: Dictionary = {}
var rng_seed: int = 0
var content_version: StringName = &""
var _entries: Array[Dictionary] = []


## Стартира / нулира journal за нов мач. Изчиства header и entries.
func begin(p_match_id: StringName) -> void:
	schema_version = SCHEMA_VERSION
	match_id = p_match_id
	match_config = {}
	rng_seed = 0
	content_version = &""
	_entries.clear()


## Записва MatchConfig, seed и content version в header-а (#133).
## config == null → празен match_config dict.
func record_header(
		config: MatchConfig,
		p_rng_seed: int,
		p_content_version: StringName = CONTENT_VERSION
) -> void:
	if config != null:
		match_config = config.to_dict()
	else:
		match_config = {}
	rng_seed = p_rng_seed
	content_version = p_content_version


## Записва приета команда (#134). Null → no-op.
func record_accepted_command(command: GameCommand) -> void:
	if command == null:
		return
	_entries.append({
		ENTRY_KIND: String(KIND_ACCEPTED_COMMAND),
		ENTRY_COMMAND: command.to_dict(),
	})


## Записва отхвърлена команда и причина (#135). Null command → no-op.
func record_rejected_command(command: GameCommand, reason: String) -> void:
	if command == null:
		return
	_entries.append({
		ENTRY_KIND: String(KIND_REJECTED_COMMAND),
		ENTRY_COMMAND: command.to_dict(),
		ENTRY_REASON: reason,
	})


## Записва state hash след приета команда (#136).
## hash като String — JSON number губи int64 precision (както MatchSession snapshot).
func record_state_hash(sequence: int, hash_value: int) -> void:
	_entries.append({
		ENTRY_KIND: String(KIND_STATE_HASH),
		ENTRY_SEQUENCE: sequence,
		ENTRY_HASH: str(hash_value),
	})


## Приети команди в хронологичен ред (Dictionary payload) — вход за replay.
func get_accepted_command_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if StringName(str(entry.get(ENTRY_KIND, ""))) != KIND_ACCEPTED_COMMAND:
			continue
		var cmd_data: Variant = entry.get(ENTRY_COMMAND, {})
		if cmd_data is Dictionary:
			out.append((cmd_data as Dictionary).duplicate(true))
	return out


## Приети команди като GameCommand обекти (диспеч по command_type).
func get_accepted_commands() -> Array[GameCommand]:
	var out: Array[GameCommand] = []
	for data: Dictionary in get_accepted_command_dicts():
		var cmd: GameCommand = command_from_dict(data)
		if cmd != null:
			out.append(cmd)
	return out


func get_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		out.append(entry.duplicate(true))
	return out


func entry_count() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty() and match_config.is_empty()


func has_header() -> bool:
	return not match_config.is_empty() or content_version != &""


func clear() -> void:
	begin(&"")


## True ако schema, match_id и entries са в договорните граници.
func is_valid() -> bool:
	if schema_version != SCHEMA_VERSION:
		return false
	if match_id != &"" and not MatchId.is_valid(match_id):
		return false
	for entry: Dictionary in _entries:
		if not _is_entry_valid(entry):
			return false
	return true


## JSON-safe Dictionary за bug report / persistence / replay payload.
func to_dict() -> Dictionary:
	var entries_out: Array = []
	for entry: Dictionary in _entries:
		entries_out.append(entry.duplicate(true))
	return {
		KEY_SCHEMA_VERSION: schema_version,
		KEY_MATCH_ID: String(match_id),
		KEY_MATCH_CONFIG: match_config.duplicate(true),
		KEY_RNG_SEED: rng_seed,
		KEY_CONTENT_VERSION: String(content_version),
		KEY_ENTRIES: entries_out,
	}


## Компактен JSON низ на to_dict().
func to_json() -> String:
	return JSON.stringify(to_dict())


## Десериализация. Невалиден / чужд schema → null.
static func from_dict(data: Dictionary) -> GameplayJournal:
	if data.is_empty():
		return null
	if int(data.get(KEY_SCHEMA_VERSION, 0)) != SCHEMA_VERSION:
		return null
	var journal := GameplayJournal.new()
	journal.schema_version = SCHEMA_VERSION
	journal.match_id = StringName(str(data.get(KEY_MATCH_ID, "")))
	var cfg: Variant = data.get(KEY_MATCH_CONFIG, {})
	journal.match_config = (cfg as Dictionary).duplicate(true) if cfg is Dictionary else {}
	journal.rng_seed = int(data.get(KEY_RNG_SEED, 0))
	journal.content_version = StringName(str(data.get(KEY_CONTENT_VERSION, "")))
	var raw_entries: Variant = data.get(KEY_ENTRIES, [])
	if raw_entries is Array:
		for item in raw_entries as Array:
			if item is Dictionary:
				journal._entries.append((item as Dictionary).duplicate(true))
	if not journal.is_valid():
		return null
	return journal


## JSON текст → from_dict. Невалиден JSON / payload → null.
static func from_json(text: String) -> GameplayJournal:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null
	return from_dict(parsed as Dictionary)


## Диспечира Dictionary към конкретния GameCommand subclass по command_type.
## Неизвестен / липсващ тип → базов GameCommand.from_dict (envelope only).
static func command_from_dict(data: Dictionary) -> GameCommand:
	if data.is_empty():
		return null
	var type := StringName(str(data.get("command_type", "")))
	match type:
		GameCommand.TYPE_START_MATCH:
			return StartMatchCommand.from_config_dict(data)
		GameCommand.TYPE_ROLL_DICE:
			return RollDiceCommand.from_roll_dict(data)
		GameCommand.TYPE_MOVE_PAWN:
			return MovePawnCommand.from_move_dict(data)
		_:
			return GameCommand.from_dict(data)


static func is_known_kind(kind: StringName) -> bool:
	return ALL_KINDS.has(kind)


static func _is_entry_valid(entry: Dictionary) -> bool:
	var kind := StringName(str(entry.get(ENTRY_KIND, "")))
	if not is_known_kind(kind):
		return false
	match kind:
		KIND_ACCEPTED_COMMAND, KIND_REJECTED_COMMAND:
			var cmd: Variant = entry.get(ENTRY_COMMAND, null)
			if not (cmd is Dictionary) or (cmd as Dictionary).is_empty():
				return false
			if kind == KIND_REJECTED_COMMAND and not entry.has(ENTRY_REASON):
				return false
			return true
		KIND_STATE_HASH:
			if not entry.has(ENTRY_SEQUENCE) or not entry.has(ENTRY_HASH):
				return false
			if int(entry[ENTRY_SEQUENCE]) < 0:
				return false
			return true
	return false
