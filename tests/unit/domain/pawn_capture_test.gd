extends TestCase
## Business-critical тестове за взимане на пионки (Task #118 /
## docs/V1_GAME_DESIGN.md §3.1–3.2; docs/V1_ARCHITECTURE.md §4.4 / §12;
## GAP-005; #113/#114 имплементация).
##
## Стъпване върху единична незащитена противникова → PawnCaptured + PawnSentHome
## в първа свободна база. Прескачането не взима. Купчина от 2 и щит блокират
## взимане. Home stretch защита → #119 / home_stretch_protection_test.gd.


var _rules: MoveRules
var _stacks: StackRules
var _capture: CaptureRules
var _engine: GameEngine


func before_each() -> void:
	_stacks = StackRules.new()
	_capture = CaptureRules.new(_stacks)
	_rules = MoveRules.new(null, _stacks, _capture)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## §3.1: кацане върху единична противникова → Moved + Captured + SentHome.
func test_engine_landing_captures_single_enemy_and_sends_home() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	var expected_base: StringName = green_pawn.cell_id
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(99)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is PawnCapturedEvent)
	assert_true(result.events[2] is PawnSentHomeEvent)
	var captured_event := result.events[1] as PawnCapturedEvent
	var sent := result.events[2] as PawnSentHomeEvent
	assert_eq(captured_event.capturing_pawn_id, mover.pawn_id)
	assert_eq(captured_event.captured_pawn_id, green_pawn.pawn_id)
	assert_eq(sent.pawn_id, green_pawn.pawn_id)
	assert_eq(sent.from_cell_id, dest_cell)
	assert_eq(sent.base_cell_id, expected_base)
	var after_mover := result.state.get_player(PlayerId.YELLOW).get_pawn(mover.pawn_id)
	var after_victim := result.state.get_player(PlayerId.GREEN).get_pawn(green_pawn.pawn_id)
	assert_eq(after_mover.cell_id, dest_cell)
	assert_true(after_mover.is_on_main_path())
	assert_true(after_victim.is_in_base())
	assert_eq(after_victim.cell_id, expected_base)
	assert_eq(after_victim.path_index, PawnState.PATH_INDEX_IN_BASE)
	assert_eq(CellOccupancy.from_state(result.state).count_at(dest_cell), 1)


## Прескачане на единична противникова не я взима — само кацане (#113).
func test_engine_passing_over_single_enemy_does_not_capture() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_cell: StringName = route[2]
	var dest_cell: StringName = route[4]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])
	state.turn.enter_awaiting_move(4, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 4)
	var rng := SeededRandomSource.new(42)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	for entry in result.events:
		assert_false(entry is PawnCapturedEvent,
				"прескачането не взима единична противникова")
		assert_false(entry is PawnSentHomeEvent)
	assert_eq(
			result.state.get_player(PlayerId.YELLOW).get_pawn(mover.pawn_id).cell_id,
			dest_cell)
	var after_green := result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id)
	assert_true(after_green.is_on_main_path())
	assert_eq(after_green.cell_id, mid_cell)


## Купчина от 2 е имунна — кацането е ILLEGAL_MOVE; без capture (§3.2 / #111).
func test_engine_rejects_landing_on_immune_stack_without_capture() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(7)
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")
	assert_true(_stacks.is_enemy_stack(state, dest_cell, PlayerId.YELLOW))


## Щит → не capturable; кацането не връща противника в база.
func test_engine_shielded_enemy_is_not_captured() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green_pawn.apply_shield(2)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(11)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	for entry in result.events:
		assert_false(entry is PawnCapturedEvent)
		assert_false(entry is PawnSentHomeEvent)
	var after_victim := result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id)
	assert_true(after_victim.is_on_main_path())
	assert_eq(after_victim.cell_id, dest_cell)
	assert_true(after_victim.has_shield())


## Exit-base върху spawn с единична противникова → capture (#113).
func test_engine_exit_base_onto_single_enemy_captures() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	var expected_base: StringName = green_pawn.cell_id
	green_pawn.set_position(PawnZone.MAIN_PATH, 0, spawn)
	var in_base := player.get_pawn_by_index(0)
	state.turn.enter_awaiting_move(DiceState.EXIT_BASE_VALUE, [in_base.pawn_id])
	state.dice.set_roll(player.player_id, DiceState.EXIT_BASE_VALUE)
	var rng := SeededRandomSource.new(55)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, in_base.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnExitedBaseEvent)
	assert_true(result.events[1] is PawnCapturedEvent)
	assert_true(result.events[2] is PawnSentHomeEvent)
	var after_victim := result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id)
	assert_true(after_victim.is_in_base())
	assert_eq(after_victim.cell_id, expected_base)
	assert_eq(
			result.state.get_player(PlayerId.YELLOW).get_pawn(in_base.pawn_id).cell_id,
			spawn)


## #114: жертвата отива в първа свободна база (каноничен ред), не original slot.
func test_engine_capture_sends_home_to_first_free_base() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var green := state.get_player(PlayerId.GREEN)
	var bases: Array = Classic15x15Board.base_cells_for(PlayerId.GREEN)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
	var green0 := green.get_pawn_by_index(0)
	var green1 := green.get_pawn_by_index(1)
	green0.set_position(PawnZone.MAIN_PATH, 10, CellId.from_grid(8, 6))
	green1.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(99)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[2] is PawnSentHomeEvent)
	var sent := result.events[2] as PawnSentHomeEvent
	var after_victim := result.state.get_player(PlayerId.GREEN).get_pawn(green1.pawn_id)
	assert_eq(sent.base_cell_id, bases[0],
			"green0 още е на пътя → първи свободен е bases[0]")
	assert_true(after_victim.is_in_base())
	assert_eq(after_victim.cell_id, bases[0])
	assert_eq(after_victim.path_index, PawnState.PATH_INDEX_IN_BASE)
	assert_true(Classic15x15Board.is_base_cell_of(PlayerId.GREEN, after_victim.cell_id))


## След разпадане на купчина оставащата е уязвима и се взима.
func test_engine_captures_remaining_pawn_after_stack_breaks() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
	var green := state.get_player(PlayerId.GREEN)
	# Бивша купчина: едната вече е напуснала — остава единична.
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 25, route[8])
	assert_false(_stacks.is_enemy_stack(state, dest_cell, PlayerId.YELLOW))
	assert_true(_capture.is_capturable(green.get_pawn_by_index(0)))
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(13)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[1] is PawnCapturedEvent)
	assert_true(result.state.get_player(PlayerId.GREEN).get_pawn(
			green.get_pawn_by_index(0).pawn_id).is_in_base())
	assert_true(result.state.get_player(PlayerId.GREEN).get_pawn(
			green.get_pawn_by_index(1).pawn_id).is_on_main_path())


## Ход към единична противникова е в valid list; към купчина — не.
func test_capture_target_is_valid_move_but_immune_stack_is_not() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var single_cell: StringName = route[4]
	var stack_cell: StringName = route[5]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, single_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 21, stack_cell)
	green.get_pawn_by_index(2).set_position(PawnZone.MAIN_PATH, 21, stack_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.can_move_pawn(state, player, mover, 3))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))
	assert_false(_rules.can_move_pawn(state, player, mover, 4))
	assert_false(_rules.collect_valid_pawn_ids(state, player, 4).has(mover.pawn_id))


## Кацане върху своя + единична противникова → capture, после stack (#110/#113).
func test_engine_capture_then_forms_friendly_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
	player.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, dest_cell)
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(99)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	assert_true(result.events[1] is PawnCapturedEvent)
	assert_true(result.events[2] is PawnSentHomeEvent)
	assert_true(result.events[3] is PawnStackFormedEvent)
	assert_true(_stacks.is_friendly_stack(result.state, dest_cell, PlayerId.YELLOW))
	assert_true(result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id).is_in_base())


## Всички seats могат да взимат единична противникова по собствения route (§12).
func test_all_seats_can_capture_single_enemy() -> void:
	for player_id in PlayerId.ALL:
		var state := _four_player_in_progress()
		var player := state.get_player(player_id)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		var dest_cell: StringName = route[4]
		var victim_seat: StringName = _first_other_seat(player_id)
		var victim := state.get_player(victim_seat).get_pawn_by_index(0)
		victim.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
		var mover := player.get_pawn_by_index(0)
		mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

		assert_true(_capture.is_capturable(victim),
				"%s: жертвата е capturable" % player_id)
		assert_true(_rules.can_move_pawn(state, player, mover, 3),
				"%s: ходът към capture е валиден" % player_id)
		assert_true(_rules.apply_board_move(state, player, mover, 3),
				"%s: apply достига дестинацията" % player_id)
		var events := _capture.resolve_capture(state, mover, 1)
		assert_eq(events.size(), 2, "%s: Captured + SentHome" % player_id)
		assert_true(victim.is_in_base(), "%s: жертвата е в база" % player_id)
		assert_true(
				Classic15x15Board.is_base_cell_of(victim_seat, victim.cell_id),
				"%s: base клетка на жертвата" % player_id)
		assert_eq(mover.cell_id, dest_cell, "%s: атакуващият остава" % player_id)


func _first_other_seat(player_id: StringName) -> StringName:
	for other in PlayerId.ALL:
		if other != player_id:
			return other
	return &""


func _two_player_in_progress(rng_seed: int = 42) -> GameState:
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
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(1, true)
	return state


func _four_player_in_progress(rng_seed: int = 42) -> GameState:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.DEFAULT_SEATS_4P)
	var animals: Array[StringName] = [
		AnimalId.PIG, AnimalId.RABBIT, AnimalId.DOG, AnimalId.COW,
	]
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		var ctrl: int = (
				MatchConfig.ControllerType.HUMAN if i == 0
				else MatchConfig.ControllerType.AI)
		seat.configure(ctrl, animals[i], AIDifficulty.EASY)
	var state := GameState.create_from_match_config(cfg)
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.turn.begin_player_turn(0, true)
	return state
