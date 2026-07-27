class_name BugReportBundle
extends RefCounted
## Локален diagnostic payload при нарушен game state invariant
## (docs/V1_ARCHITECTURE.md §12; roadmap #143).
##
## Само данни — без FileAccess / Node. LocalTelemetrySink (platform)
## записва to_dict() атомично в user://logs/ при record_invariant_violation.
##
## Follow-up задачидачи добавят journal, версии и PII филтриране към същия schema.

const SCHEMA_VERSION := 1
const TRIGGER_INVARIANT_VIOLATION := &"invariant_violation"

const KEY_SCHEMA_VERSION := "schema_version"
const KEY_CREATED_AT := "created_at"
const KEY_TRIGGER := "trigger"
const KEY_MATCH_ID := "match_id"
const KEY_DESCRIPTION := "description"
const KEY_SNAPSHOT := "snapshot"


## JSON-safe Dictionary за локален bug report файл.
static func build_for_invariant_violation(
		match_id: StringName,
		description: String,
		snapshot: Dictionary = {},
		created_at: String = ""
) -> Dictionary:
	var at := created_at
	if at.is_empty():
		at = Time.get_datetime_string_from_system()
	return {
		KEY_SCHEMA_VERSION: SCHEMA_VERSION,
		KEY_CREATED_AT: at,
		KEY_TRIGGER: String(TRIGGER_INVARIANT_VIOLATION),
		KEY_MATCH_ID: String(match_id),
		KEY_DESCRIPTION: description,
		KEY_SNAPSHOT: snapshot.duplicate(true),
	}


## True ако payload следва #143 договора (schema + trigger + задължителни полета).
static func is_valid_payload(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if int(data.get(KEY_SCHEMA_VERSION, 0)) != SCHEMA_VERSION:
		return false
	if StringName(str(data.get(KEY_TRIGGER, ""))) != TRIGGER_INVARIANT_VIOLATION:
		return false
	if not data.has(KEY_MATCH_ID):
		return false
	if not data.has(KEY_DESCRIPTION):
		return false
	if not data.has(KEY_CREATED_AT):
		return false
	var snap: Variant = data.get(KEY_SNAPSHOT, null)
	if snap != null and not (snap is Dictionary):
		return false
	return true
