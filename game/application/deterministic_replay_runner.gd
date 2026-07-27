class_name DeterministicReplayRunner
extends RefCounted
## Headless deterministic replay от GameplayJournal
## (docs/V1_ARCHITECTURE.md §12 / §16.3; roadmap #137).
##
## Вход: journal header (MatchConfig + rng_seed) + приети команди.
## Прилага командите през GameEngine със SeededRandomSource(seed) —
## без Presentation gate, controllers или reject entries.
## След всяка приета команда синхронизира rng_state (като MatchSession)
## и изчислява state hash. Опционално сравнява с journal state_hash (#136).


const KEY_OK := "ok"
const KEY_STATE := "state"
const KEY_FINAL_HASH := "final_hash"
const KEY_HASHES := "hashes"
const KEY_COMMANDS_APPLIED := "commands_applied"
const KEY_DIVERGED_AT := "diverged_at"
const KEY_ERROR := "error"

const DIVERGED_NONE := -1


var _engine: GameEngine = null


func _init(engine: GameEngine = null) -> void:
	_engine = engine


## Replay на journal. verify_recorded_hashes=true → сравнява с #136 записи.
## Невалиден journal / reject mid-replay / hash divergence → ok=false.
func run(journal: GameplayJournal, verify_recorded_hashes: bool = true) -> Dictionary:
	var fail := _validate_journal(journal)
	if not fail.is_empty():
		return _failure(fail)

	var commands: Array[GameCommand] = journal.get_accepted_commands()
	if commands.is_empty():
		return _failure("journal has no accepted commands")
	if not (commands[0] is StartMatchCommand):
		return _failure("replay requires StartMatchCommand as first accepted command")

	var engine: GameEngine = _engine if _engine != null else GameEngine.new()
	var rng: SeededRandomSource = SeededRandomSource.new(journal.rng_seed)
	# Празен match_id: envelope sequence/match checks за StartMatch са изключени;
	# StartMatch задава match_id от journal-ната команда.
	var state := GameState.new()
	var hashes: Array[int] = []
	var expected_hashes: Array[Dictionary] = []
	if verify_recorded_hashes:
		expected_hashes = journal.get_recorded_state_hashes()

	for i in commands.size():
		var command: GameCommand = commands[i]
		if command == null:
			return _failure_at("null accepted command", state, hashes, i)
		var result: Dictionary = engine.apply_command(state, command, rng)
		if not result.get("accepted", false):
			return _failure_at(
					"command rejected during replay: %s" % str(result.get("error", "")),
					state,
					hashes,
					command.sequence if command.sequence > 0 else i + 1)

		state = result.get("state", state) as GameState
		if state == null:
			return _failure_at("engine returned null state", null, hashes, command.sequence)

		# MatchSession.receive_command: capture_rng преди compute_hash (#136).
		state.capture_rng(rng)
		var live_hash: int = state.compute_hash()
		hashes.append(live_hash)

		if verify_recorded_hashes:
			var divergence := _compare_recorded_hash(
					expected_hashes, hashes.size() - 1, command.sequence, live_hash)
			if not divergence.is_empty():
				return {
					KEY_OK: false,
					KEY_STATE: state,
					KEY_FINAL_HASH: live_hash,
					KEY_HASHES: hashes,
					KEY_COMMANDS_APPLIED: hashes.size(),
					KEY_DIVERGED_AT: command.sequence,
					KEY_ERROR: divergence,
				}

	return {
		KEY_OK: true,
		KEY_STATE: state,
		KEY_FINAL_HASH: state.compute_hash() if state != null else 0,
		KEY_HASHES: hashes,
		KEY_COMMANDS_APPLIED: hashes.size(),
		KEY_DIVERGED_AT: DIVERGED_NONE,
		KEY_ERROR: "",
	}


## Удобен вход от JSON journal payload.
func run_json(text: String, verify_recorded_hashes: bool = true) -> Dictionary:
	var journal := GameplayJournal.from_json(text)
	if journal == null:
		return _failure("invalid journal JSON")
	return run(journal, verify_recorded_hashes)


func _validate_journal(journal: GameplayJournal) -> String:
	if journal == null:
		return "journal is null"
	if not journal.is_valid():
		return "journal failed is_valid()"
	if not journal.has_header():
		return "journal missing header (MatchConfig / content version)"
	if journal.match_config.is_empty():
		return "journal match_config is empty"
	var config := MatchConfig.from_dict(journal.match_config)
	if config == null or not config.is_valid():
		return "journal match_config is not a valid MatchConfig"
	return ""


func _compare_recorded_hash(
		expected_hashes: Array[Dictionary],
		index: int,
		sequence: int,
		live_hash: int
) -> String:
	if index >= expected_hashes.size():
		return "missing recorded state_hash for sequence %d" % sequence
	var recorded: Dictionary = expected_hashes[index]
	if int(recorded.get(GameplayJournal.ENTRY_SEQUENCE, -1)) != sequence:
		return "state_hash sequence mismatch at index %d (live=%d, recorded=%d)" % [
			index,
			sequence,
			int(recorded.get(GameplayJournal.ENTRY_SEQUENCE, -1)),
		]
	var recorded_hash := str(recorded.get(GameplayJournal.ENTRY_HASH, ""))
	if recorded_hash != str(live_hash):
		return "state hash divergence at sequence %d" % sequence
	return ""


func _failure(message: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_STATE: null,
		KEY_FINAL_HASH: 0,
		KEY_HASHES: [],
		KEY_COMMANDS_APPLIED: 0,
		KEY_DIVERGED_AT: DIVERGED_NONE,
		KEY_ERROR: message,
	}


func _failure_at(
		message: String,
		state: GameState,
		hashes: Array[int],
		diverged_at: int
) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_STATE: state,
		KEY_FINAL_HASH: state.compute_hash() if state != null else 0,
		KEY_HASHES: hashes,
		KEY_COMMANDS_APPLIED: hashes.size(),
		KEY_DIVERGED_AT: diverged_at,
		KEY_ERROR: message,
	}
