class_name NullTelemetrySink
extends TelemetrySink
## No-op имплементация на TelemetrySink за unit тестове
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Не пише нищо никъде. record_invariant_violation НЕ извиква push_error,
## за да не замърсява тестовия output при очаквани invariant violation тестове.
##
## Ако тестът трябва да провери дали violation е бил регистриран, използвай
## SpyTelemetrySink (инлайн наследник в теста) с брояч.

var violation_count: int = 0


func record_invariant_violation(match_id: StringName, _description: String,
		_snapshot: Dictionary = {}) -> void:
	violation_count += 1
