class_name AIController
extends PlayerController
## Контролер за AI играч (docs/V1_ARCHITECTURE.md, раздел 5.3).
##
## Делегира избора на команда към AIPolicy.
## Не знае за визуалния слой и не заобикаля GameEngine.
## AI използва същите legal_actions като HumanController.

var _player_id: StringName = &""
var _policy: AIPolicy = null


func _init(p_player_id: StringName = &"", p_policy: AIPolicy = null) -> void:
	_player_id = p_player_id
	_policy = p_policy


func is_autonomous() -> bool:
	return true


func get_action(state_view: Dictionary, legal_actions: Array) -> GameCommand:
	if not _policy:
		push_error("AIController: no AIPolicy assigned for player '%s'" % _player_id)
		return null
	if legal_actions.is_empty():
		return null
	var cmd: GameCommand = _policy.choose_action(state_view, legal_actions)
	if cmd:
		cmd.player_id = _player_id
	return cmd


func get_player_id() -> StringName:
	return _player_id


func get_policy() -> AIPolicy:
	return _policy
