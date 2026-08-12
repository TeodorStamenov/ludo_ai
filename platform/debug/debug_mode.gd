class_name DebugMode
extends RefCounted
## Единен гейт за debug-only функционалност (docs/V1_ARCHITECTURE.md §6.4).
##
## Целият developer инструментариум (forced зар, forced power-up, визуална
## подредба на дъската преди старт) минава оттук, за да има едно място, което
## решава дали сме в debug build. DebugDiceAdapter делегира на този клас.
##
## В release/production export is_authorized() е false — UI трябва да се скрие
## и всички forced стойности да се игнорират.


## True само в editor / debug export (`OS.is_debug_build()`).
static func is_authorized() -> bool:
	return OS.is_debug_build()
