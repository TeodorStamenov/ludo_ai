class_name TelemetrySink
extends RefCounted
## Port интерфейс за gameplay телеметрия и bug reports
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## В v1 имплементацията е локален file sink: записва state hash-ове и
## bug report bundle при нарушен game state invariant (#143).
## MatchSession подава match snapshot като трети аргумент; LocalTelemetrySink
## пакетира BugReportBundle в user://logs/. Личните данни не влизат в записа.
##
## Имплементации:
##   - platform/telemetry/local_telemetry_sink.gd  (production)
##   - NullTelemetrySink                            (тестове — не пише нищо)


func record_event(event_type: StringName, payload: Dictionary = {}) -> void:
	pass


func record_state_hash(match_id: StringName, command_sequence: int, hash_value: int) -> void:
	pass


## При нарушен §12 инвариант: лог + локален bug report bundle (#143).
## snapshot — MatchSession.to_snapshot() (или празен dict в тестове).
func record_invariant_violation(match_id: StringName, description: String,
		snapshot: Dictionary = {}) -> void:
	push_error("TelemetrySink: invariant violation in match '%s': %s" % [match_id, description])


## Път към последния bug report bundle; "" в no-op имплементации.
func get_last_bug_report_path() -> String:
	return ""


func flush() -> void:
	pass
