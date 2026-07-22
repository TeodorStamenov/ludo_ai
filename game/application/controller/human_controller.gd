class_name HumanController
extends PlayerController
## Контролер за човешки играч (docs/V1_ARCHITECTURE.md, раздел 5.3).
##
## НЕ е autonomous — MatchSession го сигнализира чрез awaiting_human_action.
## GamePresenter активира input и извиква submit_roll() / submit_move(pawn_id),
## след което сам изпраща командата на MatchSession.receive_command().
##
## HumanController съхранява последната валидна команда и я предоставя
## при поискване — така GamePresenter не трябва да знае за MatchSession директно.

signal action_ready(command: GameCommand)

var _player_id: StringName = &""
var _pending_legal_actions: Array = []
var _waiting: bool = false


func _init(p_player_id: StringName = &"") -> void:
	_player_id = p_player_id


func is_autonomous() -> bool:
	return false


func notify_turn(legal_actions: Array) -> void:
	_pending_legal_actions = legal_actions
	_waiting = true


func submit_roll() -> void:
	if not _waiting:
		return
	var cmd := RollDiceCommand.new(_player_id)
	_finish_action(cmd)


func submit_move(pawn_id: StringName) -> void:
	if not _waiting:
		return
	var cmd := MovePawnCommand.new(_player_id, pawn_id)
	_finish_action(cmd)


func cancel() -> void:
	_waiting = false
	_pending_legal_actions = []


func is_waiting() -> bool:
	return _waiting


func get_player_id() -> StringName:
	return _player_id


func _finish_action(cmd: GameCommand) -> void:
	_waiting = false
	_pending_legal_actions = []
	action_ready.emit(cmd)
