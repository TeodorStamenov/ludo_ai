class_name GameEngine
extends RefCounted
## Централна точка на domain логиката (docs/V1_ARCHITECTURE.md, §3 / §4.3 / §12).
##
## Публичен договор: команда → CommandResult (ново състояние + събития / грешка).
## При reject state и RNG остават непроменени (§12).
##
## Делегира правилата на MoveRules / StackRules / CaptureRules / TurnRules /
## FinishRules. Конкретните handlers се попълват от #84–#95.


@warning_ignore("unused_private_class_variable")
var _move_rules: MoveRules
@warning_ignore("unused_private_class_variable")
var _stack_rules: StackRules
@warning_ignore("unused_private_class_variable")
var _capture_rules: CaptureRules
@warning_ignore("unused_private_class_variable")
var _turn_rules: TurnRules
@warning_ignore("unused_private_class_variable")
var _finish_rules: FinishRules


func _init(
		move_rules: MoveRules = null,
		stack_rules: StackRules = null,
		capture_rules: CaptureRules = null,
		turn_rules: TurnRules = null,
		finish_rules: FinishRules = null
) -> void:
	_move_rules = move_rules if move_rules != null else MoveRules.new()
	_stack_rules = stack_rules if stack_rules != null else StackRules.new()
	_capture_rules = capture_rules if capture_rules != null else CaptureRules.new()
	_turn_rules = turn_rules if turn_rules != null else TurnRules.new()
	_finish_rules = finish_rules if finish_rules != null else FinishRules.new()


## Авторитетен вход (§3): валидира и прилага команда → CommandResult.
func validate_and_apply(
		state: GameState,
		command: GameCommand,
		rng: RandomSource
) -> CommandResult:
	if state == null:
		return CommandResult.rejected(
				null,
				CommandError.invalid_command("GameState is null"))
	if command == null:
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("GameCommand is null"))
	if rng == null:
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("RandomSource is null"))
	if not command.is_valid():
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("command failed is_valid()"))

	var envelope_error := _validate_envelope(state, command)
	if envelope_error != null:
		return CommandResult.rejected(state, envelope_error)

	if command is StartMatchCommand:
		return _apply_start_match(state, command as StartMatchCommand, rng)
	if command is RollDiceCommand:
		return _apply_roll_dice(state, command as RollDiceCommand, rng)
	if command is MovePawnCommand:
		return _apply_move_pawn(state, command as MovePawnCommand, rng)

	return CommandResult.rejected(
			state,
			CommandError.invalid_command("unknown command_type"))


## Dictionary адаптер за MatchSession (accepted, state, events, error:String).
## error е празен низ при accept; иначе стабилен CommandError.code.
func apply_command(
		state: GameState,
		command: GameCommand,
		rng: RandomSource
) -> Dictionary:
	return _to_apply_dict(validate_and_apply(state, command, rng))


func _validate_envelope(state: GameState, command: GameCommand) -> CommandError:
	if state.is_finished() and not (command is StartMatchCommand):
		return CommandError.create(
				CommandError.CODE_MATCH_FINISHED,
				"match is finished")

	if (
			command.match_id != &""
			and state.match_id != &""
			and command.match_id != state.match_id
	):
		return CommandError.create(
				CommandError.CODE_WRONG_MATCH,
				"command.match_id does not match GameState.match_id")

	if (
			command.sequence > GameCommand.SEQUENCE_UNSET
			and state.match_id != &""
			and not state.is_expected_command_sequence(command.sequence)
	):
		return CommandError.create(
				CommandError.CODE_SEQUENCE_MISMATCH,
				"command.sequence is not the next expected sequence")

	if command is StartMatchCommand:
		if state.is_in_progress():
			return CommandError.invalid_command(
					"StartMatchCommand is not allowed while match is in progress")
		return null

	if command is RollDiceCommand or command is MovePawnCommand:
		if not state.is_in_progress():
			return CommandError.create(
					CommandError.CODE_MATCH_NOT_ACTIVE,
					"match is not in progress")
		var active_id := state.get_active_player_id()
		if active_id != &"" and command.player_id != active_id:
			return CommandError.wrong_player(
					"command.player_id is not the active player")

	return null


## #84: StartMatchCommand → инициализация на GameState + MatchStarted/TurnChanged.
func _apply_start_match(
		state: GameState,
		_command: StartMatchCommand,
		_rng: RandomSource
) -> CommandResult:
	return CommandResult.not_implemented(state, "StartMatchCommand")


## #91 / #86: RollDiceCommand → seeded зар + фаза AWAITING_ROLL.
func _apply_roll_dice(
		state: GameState,
		_command: RollDiceCommand,
		_rng: RandomSource
) -> CommandResult:
	return CommandResult.not_implemented(state, "RollDiceCommand")


## #87 / #88: MovePawnCommand → движение / capture / stacks / finish.
func _apply_move_pawn(
		state: GameState,
		_command: MovePawnCommand,
		_rng: RandomSource
) -> CommandResult:
	return CommandResult.not_implemented(state, "MovePawnCommand")


static func _to_apply_dict(result: CommandResult) -> Dictionary:
	var error_text := ""
	if result.error != null:
		error_text = String(result.error.code)
	return {
		"accepted": result.accepted,
		"state": result.state,
		"events": result.events,
		"error": error_text,
	}
