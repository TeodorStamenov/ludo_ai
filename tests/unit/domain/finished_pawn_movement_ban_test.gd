extends TestCase
## Business-critical тестове за забраната за движение на FINISHED пионка
## (Task #100 / docs/V1_GAME_DESIGN.md §3.1; docs/V1_ARCHITECTURE.md §4.1 / §12).
##
## Инварианти: FINISHED никога не е в collect_valid_pawn_ids; can_move_pawn /
## apply_* връщат false без мутация; MovePawnCommand → ILLEGAL_MOVE дори при
## tampered valid_pawn_ids; state и RNG непроменени (§12).


var _move: MoveRules
var _finish: FinishRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_move = MoveRules.new(_finish)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## FINISHED: can_move_pawn false за всеки зар 1–6.
func test_can_move_pawn_false_for_all_dice_on_finished() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH)
	for face in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
		assert_false(_move.can_move_pawn(state, player, pawn, face),
				"FINISHED не е подвижна при зар %d" % face)


## FINISHED изключена от collect; останалите валидни пионки остават.
func test_collect_excludes_finished_keeps_movable() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var finished := player.get_pawn_by_index(0)
	finished.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH)
	var on_board := player.get_pawn_by_index(1)
	on_board.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	var valid: Array = _move.collect_valid_pawn_ids(state, player, 3)
	assert_false(valid.has(finished.pawn_id))
	assert_true(valid.has(on_board.pawn_id))
	assert_eq(valid.size(), 1)


## apply_board_move / apply_exit_base / apply_finish_pawn не мутират FINISHED.
func test_apply_methods_refuse_finished_without_mutation() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH)
	var before := pawn.duplicate_state()

	assert_false(_move.apply_board_move(state, player, pawn, 4))
	assert_false(_move.apply_exit_base(state, player, pawn, 6))
	assert_false(_finish.apply_finish_pawn(state, player, pawn, 1))
	assert_true(pawn.equals(before))
	assert_true(pawn.is_finished())
	assert_eq(pawn.cell_id, CellId.CENTER)


## Engine: MovePawn върху FINISHED (forced valid list) → ILLEGAL_MOVE, без мутация.
func test_engine_rejects_move_of_finished_pawn() -> void:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	pawn.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH)
	# Невалиден клиент: FINISHED е в valid_pawn_ids.
	state.turn.enter_awaiting_move(3, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, pawn.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "finished pawn cannot move")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)
	assert_true(state.get_active_player().get_pawn(pawn.pawn_id).is_finished())


## След прибиране + extra roll: следващият RollDice не включва FINISHED пионката.
func test_roll_after_finish_excludes_finished_from_valid_moves() -> void:
	var state := _setup_awaiting_finish_with_extra_roll()
	var player := state.get_active_player()
	var finishing := player.get_pawn_by_index(0)
	var other := player.get_pawn_by_index(1)
	other.exit_base_to_spawn(Classic15x15Board.spawn_cell_for(player.player_id))
	var finish_cmd := MovePawnCommand.create_for_pawn(
			player.player_id, finishing.pawn_id)
	state.stamp_command(finish_cmd)
	var rng := SeededRandomSource.new(state.get_rng_seed())

	var after_finish := _engine.validate_and_apply(state, finish_cmd, rng)
	assert_true(after_finish.accepted)
	assert_true(after_finish.state.get_player(player.player_id)
			.get_pawn(finishing.pawn_id).is_finished())
	assert_true(after_finish.state.turn.is_awaiting_roll())
	assert_eq(after_finish.state.get_active_player_id(), player.player_id)

	var roll_rng := _FixedFaceRandomSource.new(2)
	var roll_cmd := RollDiceCommand.create_for_player(player.player_id)
	after_finish.state.stamp_command(roll_cmd)
	var after_roll := _engine.validate_and_apply(after_finish.state, roll_cmd, roll_rng)

	assert_true(after_roll.accepted)
	assert_true(after_roll.state.turn.is_awaiting_move())
	assert_false(after_roll.state.turn.has_valid_pawn(finishing.pawn_id),
			"#100: FINISHED не влиза във valid_pawn_ids след нов зар")
	assert_true(after_roll.state.turn.has_valid_pawn(other.pawn_id))


func _setup_in_progress() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	assert_true(state.is_in_progress())
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	return state


## Пионка на последна HOME, зар 1, с право на extra roll след хода (като след 6).
func _setup_awaiting_finish_with_extra_roll() -> GameState:
	var state := _setup_in_progress()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var last_index: int = route.size() - 1
	pawn.set_position(PawnZone.HOME_STRETCH, last_index, route[last_index])
	state.turn.enter_awaiting_move(1, [pawn.pawn_id])
	state.turn.grant_extra_roll()
	state.dice.set_roll(player.player_id, 1)
	return state


func _two_player_config(rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_2P)
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		if i == 0:
			seat.configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		else:
			seat.configure(
					MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	return cfg


class _FixedFaceRandomSource extends RandomSource:
	var _face: int = DiceState.VALUE_MIN

	func _init(face: int) -> void:
		_face = face

	func next_int(min_val: int, max_val: int) -> int:
		return clampi(_face, min_val, max_val)

	func get_state() -> Dictionary:
		return {"seed": str(_face), "state": "0"}

	func set_state(state: Dictionary) -> void:
		_face = str(state.get("seed", _face)).to_int()
