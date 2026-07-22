class_name CommandBus
extends RefCounted
## Единственото входно гнездо за GameCommand-и към MatchSession
## (docs/V1_ARCHITECTURE.md, раздел 5).
##
## PlayerController-ите изпращат команди само оттук, а не директно
## към GameEngine. Добавя sequence номера и може да логва без да знае
## за правилата.

signal command_rejected(command: GameCommand, reason: String)

var _session: MatchSession = null
var _next_sequence: int = 1


func bind(session: MatchSession) -> void:
	_session = session
	_next_sequence = 1


func submit(command: GameCommand) -> void:
	if not _session:
		push_error("CommandBus.submit: no MatchSession bound")
		return
	command.sequence = _next_sequence
	_next_sequence += 1
	_session.receive_command(command)


func is_bound() -> bool:
	return _session != null
