extends TestCase
## Business-critical тестове за купчини (#108 / #110 / docs/V1_GAME_DESIGN.md §3.2;
## docs/V1_ARCHITECTURE.md §4.4 / §12; GAP-004 / GAP-006).
##
## Max-2 / reject трета → #108–#109. Образуване (PawnStackFormed) и разпадане
## при напускане → #110. Имунитет при кацане → #111 (capture_rules_test).
## Прескачане → #112.


var _rules: MoveRules
var _stacks: StackRules
var _engine: GameEngine


func before_each() -> void:
	_stacks = StackRules.new()
	_rules = MoveRules.new(null, _stacks, CaptureRules.new(_stacks))
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_stack_rules_extends_ref_counted() -> void:
	assert_not_null(_stacks)
	assert_true(_stacks is RefCounted)
	var as_object: Object = _stacks
	assert_false(as_object is Node)
	var path: String = _stacks.get_script().resource_path
	assert_true(path.contains("game/domain/"))


func test_max_own_pawns_per_cell_is_two() -> void:
	assert_eq(StackRules.MAX_OWN_PAWNS_PER_CELL, 2)
	assert_eq(CellOccupancy.MAX_OWN_PAWNS_PER_CELL, 2)


## Празна MAIN_PATH клетка → може да кацне; една своя → още може (купчина от 2).
func test_can_place_own_on_empty_or_single_own() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	assert_true(_stacks.can_place_own_pawn(state, cell, PlayerId.YELLOW))

	state.get_player(PlayerId.YELLOW).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 4, cell)
	assert_true(_stacks.can_place_own_pawn(state, cell, PlayerId.YELLOW))
	assert_false(_stacks.is_friendly_stack(state, cell, PlayerId.YELLOW))


## Две свои → friendly stack; трета не може (#108).
func test_friendly_stack_blocks_third_own_pawn() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	yellow.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 4, cell)
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 4, cell)

	assert_true(_stacks.is_friendly_stack(state, cell, PlayerId.YELLOW))
	assert_false(_stacks.can_place_own_pawn(state, cell, PlayerId.YELLOW))
	assert_false(_stacks.can_place_own_pawn(
			state, cell, PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 2)))
	assert_true(_stacks.can_place_own_pawn(
			state, cell, PlayerId.YELLOW, PawnId.for_player(PlayerId.YELLOW, 0)))


## Кацане върху една своя на MAIN_PATH е валиден ход (образува купчина от 2).
func test_landing_on_single_own_pawn_is_valid() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, dest_index, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.can_advance_on_board(state, player, mover, 3))
	assert_true(_rules.apply_board_move(state, player, mover, 3))
	assert_eq(mover.cell_id, dest_cell)
	assert_true(_stacks.is_friendly_stack(state, dest_cell, PlayerId.YELLOW))


## Ход към клетка с 2 свои е невалиден; apply не мутира (GAP-004).
func test_landing_on_two_own_pawns_is_invalid() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, dest_index, dest_cell)
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, dest_index, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	var before := mover.duplicate_state()

	assert_false(_rules.can_advance_on_board(state, player, mover, 3))
	assert_false(_rules.can_move_pawn(state, player, mover, 3))
	assert_false(_rules.apply_board_move(state, player, mover, 3))
	assert_true(mover.equals(before))
	assert_false(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


## Междинна своя купчина не блокира преминаване — само крайната клетка (#108 / #112).
func test_intermediate_friendly_stack_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, mid_index, route[mid_index])
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, mid_index, route[mid_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])

	assert_true(_stacks.is_friendly_stack(state, route[mid_index], PlayerId.YELLOW))
	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 4))
	assert_true(_rules.can_advance_on_board(state, player, mover, 4))
	assert_true(_rules.apply_board_move(state, player, mover, 4))
	assert_eq(mover.cell_id, route[4])


## Spawn с 2 свои → излизане от база е невалидно (GAP-006 / #108).
func test_exit_base_blocked_when_spawn_has_two_own() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	player.get_pawn_by_index(0).exit_base_to_spawn(spawn)
	player.get_pawn_by_index(1).exit_base_to_spawn(spawn)
	var in_base := player.get_pawn_by_index(2)

	assert_true(_stacks.is_friendly_stack(state, spawn, PlayerId.YELLOW))
	assert_false(_rules.can_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.can_move_pawn(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.apply_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_true(in_base.is_in_base())


## Spawn с 1 своя → излизане образува купчина от 2.
func test_exit_base_allowed_when_spawn_has_one_own() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	player.get_pawn_by_index(0).exit_base_to_spawn(spawn)
	var in_base := player.get_pawn_by_index(1)

	assert_true(_rules.can_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_true(_rules.apply_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_eq(in_base.cell_id, spawn)
	assert_true(_stacks.is_friendly_stack(state, spawn, PlayerId.YELLOW))


## Engine: MovePawn към клетка с 2 свои → reject без мутация на state/RNG.
func test_engine_rejects_move_onto_full_friendly_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(99)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "cannot place third own pawn on cell")
	assert_true(state.equals(before))


## #110: кацане върху една своя → resolve_stack_formed връща валиден event.
func test_resolve_stack_formed_after_landing_on_single_own() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var resident := player.get_pawn_by_index(1)
	resident.set_position(PawnZone.MAIN_PATH, dest_index, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.apply_board_move(state, player, mover, 3))
	var event := _stacks.resolve_stack_formed(state, mover, 7)
	assert_not_null(event)
	assert_true(event.is_valid())
	assert_eq(event.cell_id, dest_cell)
	assert_eq(event.arriving_pawn_id, mover.pawn_id)
	assert_eq(event.resident_pawn_id, resident.pawn_id)
	assert_eq(event.command_sequence, 7)


## #110: кацане на празна клетка → няма PawnStackFormed.
func test_resolve_stack_formed_null_on_empty_landing() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.apply_board_move(state, player, mover, 3))
	assert_eq(_stacks.resolve_stack_formed(state, mover, 1), null)


## #110: would_break когато пионка е в купчина от 2; false при единична.
func test_would_break_friendly_stack_detects_leaving_partner() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var yellow := state.get_player(PlayerId.YELLOW)
	var a := yellow.get_pawn_by_index(0)
	var b := yellow.get_pawn_by_index(1)
	a.set_position(PawnZone.MAIN_PATH, 4, cell)
	assert_false(_stacks.would_break_friendly_stack(
			state, cell, PlayerId.YELLOW, a.pawn_id))
	b.set_position(PawnZone.MAIN_PATH, 4, cell)
	assert_true(_stacks.would_break_friendly_stack(
			state, cell, PlayerId.YELLOW, a.pawn_id))
	assert_true(_stacks.would_break_friendly_stack(
			state, cell, PlayerId.YELLOW, b.pawn_id))
	assert_false(_stacks.would_break_friendly_stack(
			state, cell, PlayerId.YELLOW, yellow.get_pawn_by_index(2).pawn_id))


## Engine #110: ход върху една своя → PawnMoved + PawnStackFormed.
func test_engine_landing_on_own_emits_stack_formed() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var resident := player.get_pawn_by_index(1)
	resident.set_position(PawnZone.MAIN_PATH, dest_index, dest_cell)
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
	assert_true(result.events[1] is PawnStackFormedEvent)
	var formed := result.events[1] as PawnStackFormedEvent
	assert_true(formed.is_valid())
	assert_eq(formed.cell_id, dest_cell)
	assert_eq(formed.arriving_pawn_id, mover.pawn_id)
	assert_eq(formed.resident_pawn_id, resident.pawn_id)
	assert_true(_stacks.is_friendly_stack(
			result.state, dest_cell, PlayerId.YELLOW))


## Engine #110: exit-base върху spawn с 1 своя → PawnExitedBase + PawnStackFormed.
func test_engine_exit_base_onto_own_emits_stack_formed() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var resident := player.get_pawn_by_index(0)
	resident.exit_base_to_spawn(spawn)
	var in_base := player.get_pawn_by_index(1)
	state.turn.enter_awaiting_move(DiceState.EXIT_BASE_VALUE, [in_base.pawn_id])
	state.dice.set_roll(player.player_id, DiceState.EXIT_BASE_VALUE)
	var rng := SeededRandomSource.new(11)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, in_base.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnExitedBaseEvent)
	assert_true(result.events[1] is PawnStackFormedEvent)
	var formed := result.events[1] as PawnStackFormedEvent
	assert_eq(formed.cell_id, spawn)
	assert_eq(formed.arriving_pawn_id, in_base.pawn_id)
	assert_eq(formed.resident_pawn_id, resident.pawn_id)
	assert_true(_stacks.is_friendly_stack(result.state, spawn, PlayerId.YELLOW))


## Engine #110: напускане на купчина → разпадане; без PawnStackFormed на старата клетка.
func test_engine_leaving_stack_dissolves_without_formed_event() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var stack_index := 2
	var stack_cell: StringName = route[stack_index]
	var resident := player.get_pawn_by_index(1)
	resident.set_position(PawnZone.MAIN_PATH, stack_index, stack_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, stack_index, stack_cell)
	assert_true(_stacks.is_friendly_stack(state, stack_cell, PlayerId.YELLOW))
	assert_true(_stacks.would_break_friendly_stack(
			state, stack_cell, PlayerId.YELLOW, mover.pawn_id))
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(42)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var after := result.state.get_player(PlayerId.YELLOW)
	var after_mover := after.get_pawn(mover.pawn_id)
	var after_resident := after.get_pawn(resident.pawn_id)
	assert_eq(after_mover.cell_id, route[5])
	assert_eq(after_resident.cell_id, stack_cell)
	assert_false(_stacks.is_friendly_stack(
			result.state, stack_cell, PlayerId.YELLOW))
	assert_eq(
			_stacks.occupancy_of(result.state).count_of_player_at(
					stack_cell, PlayerId.YELLOW),
			1)
	assert_true(result.events[0] is PawnMovedEvent)
	for entry in result.events:
		assert_false(entry is PawnStackFormedEvent,
				"разпадането не емитира PawnStackFormed")


## Engine #110: напускане на купчина + кацане върху друга своя → само нова Formed.
func test_engine_break_and_form_emits_only_new_stack_formed() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var stack_index := 1
	var dest_index := 4
	player.get_pawn_by_index(1).set_position(
			PawnZone.MAIN_PATH, stack_index, route[stack_index])
	player.get_pawn_by_index(2).set_position(
			PawnZone.MAIN_PATH, dest_index, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, stack_index, route[stack_index])
	assert_true(_stacks.is_friendly_stack(
			state, route[stack_index], PlayerId.YELLOW))
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var rng := SeededRandomSource.new(7)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_false(_stacks.is_friendly_stack(
			result.state, route[stack_index], PlayerId.YELLOW))
	assert_true(_stacks.is_friendly_stack(
			result.state, route[dest_index], PlayerId.YELLOW))
	var formed_count := 0
	for entry in result.events:
		if entry is PawnStackFormedEvent:
			formed_count += 1
			var formed := entry as PawnStackFormedEvent
			assert_eq(formed.cell_id, route[dest_index])
			assert_eq(formed.arriving_pawn_id, mover.pawn_id)
	assert_eq(formed_count, 1)


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
