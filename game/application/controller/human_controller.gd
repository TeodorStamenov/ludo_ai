class_name HumanController
extends PlayerController
## Контролер за човешки играч (docs/V1_ARCHITECTURE.md, раздел 5.3).
##
## НЕ е autonomous — MatchSession го сигнализира чрез awaiting_human_action.
## GamePresenter активира input и извиква submit_roll() / submit_move(pawn_id).
## Intent-ът се резолва към GameCommand от същия legal_actions списък като AI
## (§5.3 / MATCH_FLOW §4) — не се фабрикува нова команда извън списъка.
## MatchSession свързва action_ready → CommandBus.submit(), така че Presenter
## не вика MatchSession.receive_command() директно.

signal action_ready(command: GameCommand)

var _player_id: StringName = &""
var _pending_legal_actions: Array = []
var _waiting: bool = false


func _init(p_player_id: StringName = &"") -> void:
	_player_id = p_player_id


func is_autonomous() -> bool:
	return false


func notify_turn(legal_actions: Array) -> void:
	_pending_legal_actions = legal_actions.duplicate()
	_waiting = true


func submit_roll() -> bool:
	if not _waiting:
		return false
	var cmd := _find_roll_action()
	if cmd == null:
		return false
	_finish_action(cmd.duplicate_command())
	return true


func submit_move(pawn_id: StringName) -> bool:
	if not _waiting or pawn_id == &"":
		return false
	var cmd := _find_move_action(pawn_id)
	if cmd == null:
		return false
	_finish_action(cmd.duplicate_command())
	return true


func cancel() -> void:
	_waiting = false
	_pending_legal_actions = []


func is_waiting() -> bool:
	return _waiting


func get_player_id() -> StringName:
	return _player_id


func _find_roll_action() -> RollDiceCommand:
	for action in _pending_legal_actions:
		if action is RollDiceCommand:
			var roll := action as RollDiceCommand
			if roll.player_id == _player_id or _player_id == &"":
				return roll
	return null


func _find_move_action(pawn_id: StringName) -> MovePawnCommand:
	for action in _pending_legal_actions:
		if action is MovePawnCommand:
			var move := action as MovePawnCommand
			if move.pawn_id != pawn_id:
				continue
			if move.player_id == _player_id or _player_id == &"":
				return move
	return null


func _finish_action(cmd: GameCommand) -> void:
	_waiting = false
	_pending_legal_actions = []
	action_ready.emit(cmd)
