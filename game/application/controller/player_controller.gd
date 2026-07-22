class_name PlayerController
extends RefCounted
## Интерфейс за контролер на един seat (docs/V1_ARCHITECTURE.md, раздел 5.3).
##
## Имплементации:
##   - HumanController   — чака input от UI (controller/human_controller.gd)
##   - AIController      — избира команда от legal_actions (controller/ai_controller.gd)
##   - RemoteController  — placeholder за v2 (controller/remote_controller.gd)
##
## Договор за MatchSession:
##   is_autonomous() -> bool           — true за AI/Remote, false за Human
##   get_action(state_view, legal) -> GameCommand  — само когато is_autonomous() е true


func is_autonomous() -> bool:
	return false


func get_action(_state_view: Dictionary, _legal_actions: Array) -> GameCommand:
	push_error("PlayerController.get_action: не е имплементирано в базовия клас")
	return null
