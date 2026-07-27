class_name TelemetrySink
extends RefCounted
## Port интерфейс за gameplay телеметрия и bug reports
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## В v1 имплементацията е локален file sink: записва state hash-ове,
## bug report bundle при нарушен invariant (#143) и кратко MatchSummary
## при нормално приключил мач (#145). MatchSession подава match snapshot
## като трети аргумент при violation; LocalTelemetrySink пакетира
## BugReportBundle / MatchSummary в user://logs/. Без лични данни.
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


## Нормално приключил мач: кратко MatchSummary в user://logs/ (#145).
## summary — MatchSummary.build_* payload (без journal).
func record_match_finished(summary: Dictionary) -> void:
	pass


## Път към последния bug report bundle; "" в no-op имплементации.
func get_last_bug_report_path() -> String:
	return ""


## Път към последния MatchSummary лог; "" в no-op имплементации.
func get_last_match_summary_path() -> String:
	return ""


func flush() -> void:
	pass
