class_name CommandBus
extends RefCounted
## Единственото входно гнездо за GameCommand-и към MatchSession
## (docs/V1_ARCHITECTURE.md, раздел 5).
##
## PlayerController-ите изпращат команди само оттук, а не директно
## към GameEngine. Sequence се задава от MatchSession чрез
## GameState.stamp_command() (source of truth: GameState.command_sequence).

signal command_rejected(command: GameCommand, reason: String)

var _session: MatchSession = null


func bind(session: MatchSession) -> void:
	_session = session


func submit(command: GameCommand) -> void:
	if not _session:
		push_error("CommandBus.submit: no MatchSession bound")
		return
	_session.receive_command(command)


func is_bound() -> bool:
	return _session != null
