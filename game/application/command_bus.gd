class_name CommandBus
extends RefCounted
## Единственото входно гнездо за GameCommand-и към MatchSession
## (docs/V1_ARCHITECTURE.md, раздел 5 / §11).
##
## Human / AI / Remote / Presentation подават команди само оттук —
## не директно към GameEngine и не към MatchSession.receive_command().
## Sequence и match_id се задават от MatchSession чрез
## GameState.stamp_command() (source of truth: GameState.command_sequence).
##
## Във v2 NetworkClient може да замени локалния submit без промяна
## в controllers или view слоя.

signal command_rejected(command: GameCommand, reason: String)

var _session: MatchSession = null


func bind(session: MatchSession) -> void:
	unbind()
	if session == null:
		push_error("CommandBus.bind: session не може да е null")
		return
	_session = session
	_session.command_rejected.connect(_on_session_command_rejected)


func unbind() -> void:
	if _session != null and _session.command_rejected.is_connected(_on_session_command_rejected):
		_session.command_rejected.disconnect(_on_session_command_rejected)
	_session = null


func submit(command: GameCommand) -> bool:
	if _session == null:
		push_error("CommandBus.submit: no MatchSession bound")
		return false
	if command == null:
		push_error("CommandBus.submit: null command")
		return false
	_session.receive_command(command)
	return true


func is_bound() -> bool:
	return _session != null


func get_session() -> MatchSession:
	return _session


func _on_session_command_rejected(command: GameCommand, reason: String) -> void:
	command_rejected.emit(command, reason)
