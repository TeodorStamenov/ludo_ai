class_name GameEngine
extends RefCounted
## Централна точка на domain логиката (docs/V1_ARCHITECTURE.md, §3 / §4.3 / §12).
##
## Публичен договор: команда → CommandResult (ново състояние + събития / грешка).
## При reject state и RNG остават непроменени (§12).
##
## Делегира правилата на MoveRules / StackRules / CaptureRules / TurnRules /
## FinishRules. RollDice ползва само инжектирания RandomSource (#91 / §4.5).


var _move_rules: MoveRules
var _stack_rules: StackRules
var _capture_rules: CaptureRules
var _turn_rules: TurnRules
var _finish_rules: FinishRules


func _init(
		move_rules: MoveRules = null,
		stack_rules: StackRules = null,
		capture_rules: CaptureRules = null,
		turn_rules: TurnRules = null,
		finish_rules: FinishRules = null
) -> void:
	_finish_rules = finish_rules if finish_rules != null else FinishRules.new()
	_stack_rules = stack_rules if stack_rules != null else StackRules.new()
	_capture_rules = (
			capture_rules if capture_rules != null
			else CaptureRules.new(_stack_rules)
	)
	_move_rules = (
			move_rules if move_rules != null
			else MoveRules.new(_finish_rules, _stack_rules, _capture_rules)
	)
	_turn_rules = turn_rules if turn_rules != null else TurnRules.new()


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


## StartMatchCommand → инициализация на GameState + MatchStarted / TurnChanged.
## config е source of truth; phase → IN_PROGRESS; първи seat → AWAITING_ROLL (YEL-003).
func _apply_start_match(
		state: GameState,
		command: StartMatchCommand,
		_rng: RandomSource
) -> CommandResult:
	var config: MatchConfig = command.config
	var match_id: StringName = command.match_id
	if match_id == &"":
		match_id = state.match_id if state.match_id != &"" else MatchId.generate()

	var next: GameState = GameState.create_from_match_config(config, match_id)
	if next.player_count() == 0 or next.get_active_player() == null:
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("StartMatchCommand produced empty roster"))

	var accepted_sequence: int = command.sequence
	if accepted_sequence <= GameCommand.SEQUENCE_UNSET:
		accepted_sequence = next.next_command_sequence()
	# Fresh match timeline; stamped sequence may be > 1 when restarting a finished state.
	next.command_sequence = accepted_sequence - 1
	if not next.record_accepted_command(accepted_sequence):
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("StartMatchCommand sequence could not be recorded"))

	next.set_phase(MatchPhase.IN_PROGRESS)
	if not _turn_rules.begin_player_turn(next, next.active_player_index, 1):
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("StartMatchCommand could not begin first turn"))

	var events: Array = [
		MatchStartedEvent.create_started(next.match_id, config, accepted_sequence),
		TurnChangedEvent.create_from_state(
				next, TurnChangedEvent.PLAYER_INDEX_NONE, accepted_sequence),
	]
	return CommandResult.ok(next, events)


## RollDiceCommand (#91): намерение без dice value; лицето идва от инжектирания
## SeededRandomSource (§4.3 / §4.5). TurnRules.resolve_after_roll (YEL-010–013 /
## YEL-045); при TURN_END → advance. Reject не консумира RNG (§12).
func _apply_roll_dice(
		state: GameState,
		command: RollDiceCommand,
		rng: RandomSource
) -> CommandResult:
	if state.turn == null or not state.turn.allows_roll_dice():
		return CommandResult.rejected(
				state,
				CommandError.wrong_phase(
						"RollDiceCommand requires AWAITING_ROLL with roll_dice"))

	var next: GameState = state.duplicate_state()
	var player := next.get_active_player()
	if player == null:
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("no active player for RollDiceCommand"))

	var accepted_sequence: int = command.sequence
	if accepted_sequence <= GameCommand.SEQUENCE_UNSET:
		accepted_sequence = next.next_command_sequence()
	if not next.record_accepted_command(accepted_sequence):
		return CommandResult.rejected(
				state,
				CommandError.create(
						CommandError.CODE_SEQUENCE_MISMATCH,
						"RollDiceCommand sequence could not be recorded"))

	# Клиентът не изпраща лице — авторитетният RNG генерира 1–6.
	var dice_value: int = rng.next_int(DiceState.VALUE_MIN, DiceState.VALUE_MAX)
	var all_in_base: bool = _turn_rules.all_pawns_in_base(player)
	var valid_pawns: Array = _move_rules.collect_valid_pawn_ids(
			next, player, dice_value)
	var outcome: StringName = _turn_rules.resolve_after_roll(
			next.turn, dice_value, all_in_base, valid_pawns)

	var events: Array = [
		DiceRolledEvent.create_rolled(
				command.player_id, dice_value, accepted_sequence),
	]

	if outcome == TurnRules.OUTCOME_AWAITING_MOVE:
		events.append(ValidMovesChangedEvent.create_from_turn(
				command.player_id, next.turn, accepted_sequence))
	else:
		_append_turn_end_advance(next, outcome, accepted_sequence, events)

	_sync_dice_from_turn(next, command.player_id)
	next.capture_rng(rng)
	return CommandResult.ok(next, events)


## MovePawnCommand в AWAITING_MOVE → RESOLVING_MOVE (#87/#88):
## exit-base (YEL-030/032), ход по маршрута (YEL-040–055) или прибиране (#99).
## FINISHED пионка се reject-ва (#100). Трета своя на клетка → ILLEGAL_MOVE (#109).
## Кацане върху своя → PawnStackFormed (#110). Единична противникова → capture (#113).
## Gifts → по-късни tasks.
func _apply_move_pawn(
		state: GameState,
		command: MovePawnCommand,
		rng: RandomSource
) -> CommandResult:
	if state.turn == null or not state.turn.allows_move_pawn():
		return CommandResult.rejected(
				state,
				CommandError.wrong_phase(
						"MovePawnCommand requires AWAITING_MOVE with move_pawn"))

	if not state.turn.has_valid_pawn(command.pawn_id):
		return CommandResult.rejected(
				state,
				CommandError.illegal_move(
						"pawn_id is not in turn.valid_pawn_ids"))

	var player := state.get_active_player()
	if player == null:
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("no active player for MovePawnCommand"))

	var pawn := player.get_pawn(command.pawn_id)
	if pawn == null:
		return CommandResult.rejected(
				state,
				CommandError.create(
						CommandError.CODE_UNKNOWN_PAWN,
						"pawn_id not found on active player"))

	# #100: FINISHED пионка е терминална — дори ако е в valid_pawn_ids (tampered client).
	if pawn.is_finished():
		return CommandResult.rejected(
				state,
				CommandError.illegal_move("finished pawn cannot move"))

	var dice_value: int = state.turn.dice_value
	if not _move_rules.can_move_pawn(state, player, pawn, dice_value):
		# #109: трета своя на MAIN_PATH / spawn — дори при tampered valid_pawn_ids.
		if _move_rules.would_place_third_own_pawn(state, player, pawn, dice_value):
			return CommandResult.rejected(
					state,
					CommandError.illegal_move("cannot place third own pawn on cell"))
		# #111: кацане върху имунна противникова купчина от 2.
		if _move_rules.would_land_on_enemy_stack(state, player, pawn, dice_value):
			return CommandResult.rejected(
					state,
					CommandError.illegal_move("cannot land on immune enemy stack"))
		return CommandResult.rejected(
				state,
				CommandError.illegal_move("pawn is not movable for current dice"))

	var next: GameState = state.duplicate_state()
	var next_player := next.get_active_player()
	var next_pawn := next_player.get_pawn(command.pawn_id)
	if next_player == null or next_pawn == null:
		return CommandResult.rejected(
				state,
				CommandError.invalid_command("MovePawnCommand lost pawn after duplicate"))

	var accepted_sequence: int = command.sequence
	if accepted_sequence <= GameCommand.SEQUENCE_UNSET:
		accepted_sequence = next.next_command_sequence()
	if not next.record_accepted_command(accepted_sequence):
		return CommandResult.rejected(
				state,
				CommandError.create(
						CommandError.CODE_SEQUENCE_MISMATCH,
						"MovePawnCommand sequence could not be recorded"))

	if not _turn_rules.begin_resolving_move(next.turn):
		return CommandResult.rejected(
				state,
				CommandError.wrong_phase("could not enter RESOLVING_MOVE"))

	var before := next_pawn.duplicate_state()
	var events: Array = []

	if next_pawn.is_in_base():
		if not _move_rules.apply_exit_base(
				next, next_player, next_pawn, dice_value):
			return CommandResult.rejected(
					state,
					CommandError.illegal_move("exit base could not be applied"))
		events.append(PawnExitedBaseEvent.create_from_states(
				before, next_pawn, accepted_sequence))
		_append_capture_if_any(next, next_pawn, accepted_sequence, events)
		_append_stack_formed_if_any(next, next_pawn, accepted_sequence, events)
	elif _finish_rules.can_finish_pawn(next, next_player, next_pawn, dice_value):
		if not _finish_rules.apply_finish_pawn(
				next, next_player, next_pawn, dice_value):
			return CommandResult.rejected(
					state,
					CommandError.illegal_move("finish pawn could not be applied"))
		events.append(PawnMovedEvent.create_from_states(
				before, next_pawn, accepted_sequence))
		events.append(PawnFinishedEvent.create_from_states(
				before, next_pawn, accepted_sequence))
		for ranked_event in _finish_rules.resolve_ranking_progress(
				next, next_player.player_id, accepted_sequence):
			events.append(ranked_event)
	else:
		if not _move_rules.apply_board_move(
				next, next_player, next_pawn, dice_value):
			return CommandResult.rejected(
					state,
					CommandError.illegal_move("board move could not be applied"))
		events.append(PawnMovedEvent.create_from_states(
				before, next_pawn, accepted_sequence))
		_append_capture_if_any(next, next_pawn, accepted_sequence, events)
		_append_stack_formed_if_any(next, next_pawn, accepted_sequence, events)

	var outcome: StringName = _turn_rules.resolve_after_move(next.turn, false)
	_append_turn_end_advance(next, outcome, accepted_sequence, events)

	_sync_dice_from_turn(next, command.player_id)
	next.capture_rng(rng)
	return CommandResult.ok(next, events)


## #113/#114: кацане върху единична незащитена противникова →
## PawnCaptured + PawnSentHome (в свободна base клетка).
## Преди stack formed — capture освобождава клетката от противника.
func _append_capture_if_any(
		state: GameState,
		arriving: PawnState,
		command_sequence: int,
		events: Array
) -> void:
	for entry in _capture_rules.resolve_capture(state, arriving, command_sequence):
		events.append(entry)


## #110: кацане върху една своя на MAIN_PATH → PawnStackFormed след exit/move.
func _append_stack_formed_if_any(
		state: GameState,
		arriving: PawnState,
		command_sequence: int,
		events: Array
) -> void:
	var stack_event: PawnStackFormedEvent = _stack_rules.resolve_stack_formed(
			state, arriving, command_sequence)
	if stack_event != null:
		events.append(stack_event)


## TURN_END → auto-rank last place → advance (TurnChanged / MATCH_FINISHED).
## Extra roll при 6 (#93) ≠ advance — остава същият играч в AWAITING_ROLL.
## MATCH_FINISHED → FinishRules.apply_match_finished (#90).
func _append_turn_end_advance(
		state: GameState,
		outcome: StringName,
		command_sequence: int,
		events: Array
) -> void:
	if outcome != TurnRules.OUTCOME_TURN_END:
		return
	var last_ranked: PlayerRankedEvent = _finish_rules.auto_rank_last_remaining(
			state, command_sequence)
	if last_ranked != null:
		events.append(last_ranked)
	var advance: Dictionary = _turn_rules.advance_from_turn_end(
			state, command_sequence)
	if advance.get("event") != null:
		events.append(advance["event"])
	if advance.get("outcome") != TurnRules.OUTCOME_MATCH_FINISHED:
		return
	var finished: MatchFinishedEvent = _finish_rules.apply_match_finished(
			state, command_sequence)
	if finished != null:
		events.append(finished)


## Синхрон GameState.dice ↔ turn.dice_value след roll / advance.
func _sync_dice_from_turn(state: GameState, player_id: StringName) -> void:
	if state.dice == null:
		state.dice = DiceState.create_none()
	if state.turn != null and state.turn.has_dice_result():
		state.dice.set_roll(player_id, state.turn.dice_value)
	else:
		state.dice.clear()


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
