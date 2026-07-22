class_name TelemetrySink
extends RefCounted
## Port интерфейс за gameplay телеметрия и bug reports
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## В v1 имплементацията е локален file sink: записва gameplay journal,
## state hash-ове и bug report bundle при нарушен game state invariant.
## Личните данни не влизат в записа.
##
## Имплементации:
##   - platform/telemetry/local_telemetry_sink.gd  (production)
##   - NullTelemetrySink                            (тестове — не пише нищо)


func record_event(event_type: StringName, payload: Dictionary = {}) -> void:
	pass


func record_state_hash(match_id: StringName, command_sequence: int, hash_value: int) -> void:
	pass


func record_invariant_violation(match_id: StringName, description: String, snapshot: Dictionary = {}) -> void:
	push_error("TelemetrySink: invariant violation in match '%s': %s" % [match_id, description])


func flush() -> void:
	pass
