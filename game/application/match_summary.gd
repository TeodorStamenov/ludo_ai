class_name MatchSummary
extends RefCounted
## Кратко резюме при нормално приключил мач
## (docs/V1_ARCHITECTURE.md §5.2; roadmap logging policy / #145).
##
## При MatchFinished MatchSession произвежда този Dictionary payload
## (не пълен journal — той е за DebugMatchBuffer #144 / BugReportBundle #143).
## Typed моделът на класирането е MatchResult; тук е Application договорът
## към Results / Progress / локални логове в user://logs/.
##
## Схема = MatchResult.to_dict() + session метаданни:
##   schema_version, match_id, mode, campaign_level_id?, ranking[],
##   command_sequence, recorded_at?

const KEY_SCHEMA_VERSION := "schema_version"
const KEY_MATCH_ID := "match_id"
const KEY_MODE := "mode"
const KEY_CAMPAIGN_LEVEL_ID := "campaign_level_id"
const KEY_RANKING := "ranking"
const KEY_COMMAND_SEQUENCE := "command_sequence"
const KEY_RECORDED_AT := "recorded_at"

## Колко нормални MatchSummary файла пази LocalTelemetrySink (circular eviction).
const DEFAULT_LOG_CAPACITY := 20


## Строи кратко резюме от завършен GameState (+ session command_sequence).
static func build_from_game_state(
		state: GameState,
		command_sequence: int = GameState.COMMAND_SEQUENCE_START,
		recorded_at: String = ""
) -> Dictionary:
	var result := MatchResult.create_from_game_state(state)
	var seq := command_sequence
	if state != null:
		seq = state.command_sequence
	return build_from_match_result(result, seq, recorded_at)


## MatchResult.to_dict() + command_sequence (+ опционален recorded_at за логове).
static func build_from_match_result(
		result: MatchResult,
		command_sequence: int = GameState.COMMAND_SEQUENCE_START,
		recorded_at: String = ""
) -> Dictionary:
	var summary: Dictionary = {}
	if result != null:
		summary = result.to_dict()
	else:
		summary = {
			KEY_SCHEMA_VERSION: MatchResult.SCHEMA_VERSION,
			KEY_MATCH_ID: "",
			KEY_MODE: MatchConfig.Mode.FREE_PLAY,
			KEY_CAMPAIGN_LEVEL_ID: "",
			KEY_RANKING: [],
		}
	summary[KEY_COMMAND_SEQUENCE] = command_sequence
	if not recorded_at.is_empty():
		summary[KEY_RECORDED_AT] = recorded_at
	return summary


## True ако payload покрива договора за нормално приключил мач
## (валиден MatchResult + command_sequence ≥ 0).
static func is_valid_payload(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if not data.has(KEY_COMMAND_SEQUENCE):
		return false
	if int(data.get(KEY_COMMAND_SEQUENCE, -1)) < 0:
		return false
	if not data.has(KEY_RANKING):
		return false
	var result := MatchResult.from_dict(data)
	return result.is_valid()
