class_name ActiveMatchSave
extends RefCounted
## Типизиран wrapper около MatchSession.to_snapshot() payload-а
## (docs/V1_ARCHITECTURE.md §9; #244).
##
## Snapshot-ът вече носи собствена версия (MatchSession.SNAPSHOT_SCHEMA_VERSION)
## и пълна валидация (MatchSession.is_snapshot_valid) — ActiveMatchSave не
## дублира тази логика, само я именува като typed handle, с който
## SaveRepository извикващите работят вместо гол Dictionary навсякъде.
##
## Живее в game/application/ (до match_session.gd), не в game/domain/model/:
## увива application-ов формат (MatchSession snapshot), а domain не бива да
## зависи от application.

var snapshot: Dictionary = {}


static func from_snapshot(p_snapshot: Dictionary) -> ActiveMatchSave:
	var save := ActiveMatchSave.new()
	save.snapshot = p_snapshot.duplicate(true) if p_snapshot != null else {}
	return save


## Договорните ключове + вложеният GameState са валидни и съгласувани
## (делегира изцяло към MatchSession.is_snapshot_valid).
func is_valid() -> bool:
	return MatchSession.is_snapshot_valid(snapshot)


func get_match_id() -> StringName:
	return StringName(str(snapshot.get(MatchSession.SNAPSHOT_KEY_MATCH_ID, "")))


func get_command_sequence() -> int:
	return int(snapshot.get(MatchSession.SNAPSHOT_KEY_COMMAND_SEQUENCE, 0))


func to_dict() -> Dictionary:
	return snapshot.duplicate(true)


static func from_dict(data: Dictionary) -> ActiveMatchSave:
	return from_snapshot(data)


func duplicate_state() -> ActiveMatchSave:
	return ActiveMatchSave.from_snapshot(snapshot)


func equals(other: ActiveMatchSave) -> bool:
	if other == null:
		return false
	return JSON.stringify(snapshot) == JSON.stringify(other.snapshot)
