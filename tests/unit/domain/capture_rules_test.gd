extends TestCase
## Business-critical тестове за CaptureRules API — имунитет (#111), прескачане
## (#112), взимане (#113), свободна база (#114), home stretch (#115)
## (docs/V1_ARCHITECTURE.md §12; V1_GAME_DESIGN.md §3.1–3.2).
##
## Сценарии end-to-end за взимане → Task #118 / pawn_capture_test.gd.
## Home stretch защита → Task #119 / home_stretch_protection_test.gd.


var _capture: CaptureRules
var _stacks: StackRules
var _rules: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_stacks = StackRules.new()
	_capture = CaptureRules.new(_stacks)
	_rules = MoveRules.new(null, _stacks, _capture)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


func test_capture_rules_extends_ref_counted() -> void:
	assert_not_null(_capture)
	assert_true(_capture is RefCounted)
	var as_object: Object = _capture
	assert_false(as_object is Node)
	var path: String = _capture.get_script().resource_path
	assert_true(path.contains("game/domain/"))


## #111: две противникови на клетка → имунна купчина; blocks_landing.
func test_enemy_stack_of_two_is_immune_and_blocks_landing() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, cell)

	assert_true(_stacks.is_enemy_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, cell, PlayerId.YELLOW))


## Една противникова → не е имунна; capturable (#113).
func test_single_enemy_pawn_is_not_immune_stack() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, cell)

	assert_false(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_false(_capture.blocks_landing(state, cell, PlayerId.YELLOW))
	assert_true(_capture.is_capturable(green_pawn))
	var found := _capture.find_capturable_at(state, cell, PlayerId.YELLOW)
	assert_not_null(found)
	assert_eq(found.pawn_id, green_pawn.pawn_id)


## #111: кацане върху enemy stack → невалиден ход; изключен от valid list.
func test_landing_on_enemy_stack_is_illegal_and_excluded() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	var before := mover.duplicate_state()

	assert_true(_rules.would_land_on_enemy_stack(state, player, mover, 3))
	assert_false(_rules.can_advance_on_board(state, player, mover, 3))
	assert_false(_rules.can_move_pawn(state, player, mover, 3))
	assert_false(_rules.apply_board_move(state, player, mover, 3))
	assert_true(mover.equals(before))
	assert_false(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


## #111/#113: единична противникова на дестинацията не блокира — ходът е валиден за взимане.
func test_landing_on_single_enemy_is_not_blocked_by_stack_immunity() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, route[dest_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_false(_rules.would_land_on_enemy_stack(state, player, mover, 3))
	assert_true(_rules.can_advance_on_board(state, player, mover, 3))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 3).has(mover.pawn_id))


## #111: exit-base върху spawn с противникова купчина → блокиран.
func test_exit_base_blocked_when_spawn_has_enemy_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 0, spawn)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 0, spawn)
	var in_base := player.get_pawn_by_index(0)

	assert_true(_capture.blocks_landing(state, spawn, PlayerId.YELLOW))
	assert_true(_rules.would_land_on_enemy_stack(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.can_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.can_move_pawn(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_false(_rules.apply_exit_base(
			state, player, in_base, DiceState.EXIT_BASE_VALUE))
	assert_true(in_base.is_in_base())


## Engine #111: MovePawn към immune stack (tampered valid list) → ILLEGAL_MOVE.
func test_engine_rejects_landing_on_enemy_stack_without_mutation() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	state.turn.enter_awaiting_move(3, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 3)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(99)
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "cannot land on immune enemy stack")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before, "§12: reject не консумира RNG")


## Engine #111: exit-base върху spawn с enemy stack → ILLEGAL_MOVE.
func test_engine_rejects_exit_base_onto_enemy_stack_without_mutation() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var spawn := Classic15x15Board.spawn_cell_for(PlayerId.YELLOW)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 0, spawn)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 0, spawn)
	var in_base := player.get_pawn_by_index(0)
	state.turn.enter_awaiting_move(DiceState.EXIT_BASE_VALUE, [in_base.pawn_id])
	state.dice.set_roll(player.player_id, DiceState.EXIT_BASE_VALUE)
	var before := state.duplicate_state()
	var rng := SeededRandomSource.new(55)
	var rng_before := rng.get_state()
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, in_base.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.is_rejected())
	assert_eq(result.error.code, CommandError.CODE_ILLEGAL_MOVE)
	assert_eq(result.error.message, "cannot land on immune enemy stack")
	assert_true(state.equals(before))
	assert_eq(rng.get_state(), rng_before)
	assert_true(state.get_active_player().get_pawn(in_base.pawn_id).is_in_base())


## #112: имунна купчина не блокира преминаване — само кацане (#111).
func test_enemy_stack_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, cell)

	assert_true(_capture.is_immune_stack(state, cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, cell, PlayerId.YELLOW))
	assert_false(_capture.blocks_passage(state, cell, PlayerId.YELLOW))


## #112: междинна противникова купчина не блокира ход; дестинацията се достига.
func test_intermediate_enemy_stack_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	var mid_cell: StringName = route[mid_index]
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])

	assert_true(_stacks.is_enemy_stack(state, mid_cell, PlayerId.YELLOW))
	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 4))
	assert_false(_rules.would_land_on_enemy_stack(state, player, mover, 4))
	assert_true(_rules.can_advance_on_board(state, player, mover, 4))
	assert_true(_rules.can_move_pawn(state, player, mover, 4))
	assert_true(_rules.collect_valid_pawn_ids(state, player, 4).has(mover.pawn_id))
	assert_true(_rules.apply_board_move(state, player, mover, 4))
	assert_eq(mover.cell_id, route[4])
	assert_true(_stacks.is_enemy_stack(state, mid_cell, PlayerId.YELLOW))


## #112: единична противникова на междинна клетка също не блокира преминаване.
func test_intermediate_single_enemy_does_not_block_passage() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 3
	state.get_player(PlayerId.GREEN).get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, 20, route[mid_index])
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_false(_rules.would_be_blocked_en_route(state, player, mover, 3))
	assert_true(_rules.can_advance_on_board(state, player, mover, 3))
	assert_true(_rules.apply_board_move(state, player, mover, 3))
	assert_eq(mover.cell_id, route[4])


## Engine #112: MovePawn прескача противникова купчина и каца след нея.
func test_engine_accepts_jump_over_enemy_stack() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mid_index := 2
	var mid_cell: StringName = route[mid_index]
	var dest_index := 4
	var green := state.get_player(PlayerId.GREEN)
	green.get_pawn_by_index(0).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	green.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 20, mid_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 0, route[0])
	state.turn.enter_awaiting_move(4, [mover.pawn_id])
	state.dice.set_roll(player.player_id, 4)
	var rng := SeededRandomSource.new(99)
	var cmd := MovePawnCommand.create_for_pawn(player.player_id, mover.pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.events[0] is PawnMovedEvent)
	var after := result.state.get_player(PlayerId.YELLOW).get_pawn(mover.pawn_id)
	assert_eq(after.cell_id, route[dest_index])
	assert_eq(after.path_index, dest_index)
	assert_true(_stacks.is_enemy_stack(result.state, mid_cell, PlayerId.YELLOW))
	for entry in result.events:
		assert_false(entry is PawnCapturedEvent,
				"прескачането не взима купчината")


## #113: resolve_capture след кацане → PawnCaptured + PawnSentHome; противникът в база.
func test_resolve_capture_sends_single_enemy_home() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	var green_base: StringName = green_pawn.cell_id
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.apply_board_move(state, player, mover, 3))
	assert_eq(mover.cell_id, dest_cell)
	var events := _capture.resolve_capture(state, mover, 7)

	assert_eq(events.size(), 2)
	assert_true(events[0] is PawnCapturedEvent)
	assert_true(events[1] is PawnSentHomeEvent)
	var captured_event := events[0] as PawnCapturedEvent
	var sent := events[1] as PawnSentHomeEvent
	assert_true(captured_event.is_valid())
	assert_eq(captured_event.capturing_pawn_id, mover.pawn_id)
	assert_eq(captured_event.captured_pawn_id, green_pawn.pawn_id)
	assert_eq(captured_event.command_sequence, 7)
	assert_true(sent.is_valid())
	assert_eq(sent.pawn_id, green_pawn.pawn_id)
	assert_eq(sent.from_cell_id, dest_cell)
	assert_true(green_pawn.is_in_base())
	assert_eq(green_pawn.cell_id, sent.base_cell_id)
	assert_eq(green_pawn.cell_id, green_base,
			"първи свободен слот е оригиналната base клетка")
	assert_eq(CellOccupancy.from_state(state).count_opponents_at(
			dest_cell, PlayerId.YELLOW), 0)


## #113: празна дестинация → няма capture events.
func test_resolve_capture_null_on_empty_landing() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])

	assert_true(_rules.apply_board_move(state, player, mover, 3))
	assert_eq(_capture.resolve_capture(state, mover, 1).size(), 0)


## #113: щит → не е capturable; resolve не мутира.
func test_shielded_enemy_is_not_capturable() -> void:
	var state := _two_player_in_progress()
	var cell: StringName = CellId.from_grid(6, 8)
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.MAIN_PATH, 20, cell)
	green_pawn.apply_shield(2)
	var yellow := state.get_player(PlayerId.YELLOW).get_pawn_by_index(0)
	yellow.set_position(PawnZone.MAIN_PATH, 4, cell)

	assert_false(_capture.is_capturable(green_pawn))
	assert_null(_capture.find_capturable_at(state, cell, PlayerId.YELLOW))
	var before := green_pawn.duplicate_state()
	assert_eq(_capture.resolve_capture(state, yellow, 1).size(), 0)
	assert_true(green_pawn.equals(before))


## #115: HOME_STRETCH / BASE / FINISHED са защитени; само MAIN_PATH е capturable.
func test_protected_zones_are_not_capturable() -> void:
	var state := _two_player_in_progress()
	var green := state.get_player(PlayerId.GREEN)
	var home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[0]
	var base: StringName = Classic15x15Board.base_cells_for(PlayerId.GREEN)[0]
	var home_pawn := green.get_pawn_by_index(0)
	var base_pawn := green.get_pawn_by_index(1)
	var finished_pawn := green.get_pawn_by_index(2)
	var path_pawn := green.get_pawn_by_index(3)
	home_pawn.set_position(PawnZone.HOME_STRETCH, 50, home)
	base_pawn.place_in_base(base)
	finished_pawn.mark_finished(Classic15x15Board.PLAYER_ROUTE_LENGTH - 1, home)
	path_pawn.set_position(PawnZone.MAIN_PATH, 20, CellId.from_grid(6, 8))

	assert_true(_capture.is_protected_from_opponents(home_pawn))
	assert_true(_capture.is_protected_from_opponents(base_pawn))
	assert_true(_capture.is_protected_from_opponents(finished_pawn))
	assert_false(_capture.is_protected_from_opponents(path_pawn))
	assert_false(_capture.is_capturable(home_pawn))
	assert_false(_capture.is_capturable(base_pawn))
	assert_false(_capture.is_capturable(finished_pawn))
	assert_true(_capture.is_capturable(path_pawn))


## #115: home stretch пионка не се взима дори при съвпадение на cell_id.
func test_home_stretch_pawn_is_not_capturable() -> void:
	var state := _two_player_in_progress()
	var home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[0]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.HOME_STRETCH, 50, home)
	var yellow := state.get_player(PlayerId.YELLOW).get_pawn_by_index(0)
	yellow.set_position(PawnZone.MAIN_PATH, 4, home)

	assert_true(_capture.is_protected_from_opponents(green_pawn))
	assert_false(_capture.is_capturable(green_pawn))
	assert_null(_capture.find_capturable_at(state, home, PlayerId.YELLOW))
	assert_eq(_capture.resolve_capture(state, yellow, 1).size(), 0)
	assert_true(green_pawn.is_in_home_stretch())
	assert_eq(green_pawn.cell_id, home)


## #115: чужд home stretch блокира кацане; собственият не.
func test_foreign_home_stretch_blocks_landing() -> void:
	var state := _two_player_in_progress()
	var green_home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[0]
	var yellow_home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.YELLOW)[0]
	var path_cell: StringName = CellId.from_grid(6, 8)

	assert_true(_capture.is_foreign_home_stretch(green_home, PlayerId.YELLOW))
	assert_false(_capture.is_foreign_home_stretch(yellow_home, PlayerId.YELLOW))
	assert_false(_capture.is_foreign_home_stretch(path_cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, green_home, PlayerId.YELLOW))
	assert_false(_capture.blocks_landing(state, yellow_home, PlayerId.YELLOW))
	assert_false(_capture.blocks_landing(state, path_cell, PlayerId.YELLOW))


## #115: маршрутите не включват чужд home stretch — структурна защита.
func test_player_routes_never_include_foreign_home_stretch() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		for cell_id in route:
			var owner := Classic15x15Board.home_stretch_owner(cell_id)
			if owner == &"":
				continue
			assert_eq(owner, player_id,
					"%s route не трябва да съдържа чужд home stretch %s" % [
						player_id, cell_id])
			assert_false(_capture.is_foreign_home_stretch(cell_id, player_id))


## Engine #115: пионка в home stretch остава там след ход на противник по MAIN_PATH.
func test_engine_opponent_move_does_not_capture_home_stretch_pawn() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green_home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[1]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.HOME_STRETCH, 51, green_home)
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
	for event in result.events:
		assert_false(event is PawnCapturedEvent,
				"home stretch пионка не се взима")
		assert_false(event is PawnSentHomeEvent)
	var after_green := result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id)
	assert_true(after_green.is_in_home_stretch())
	assert_eq(after_green.cell_id, green_home)
	assert_eq(result.state.get_player(PlayerId.YELLOW).get_pawn(
			mover.pawn_id).cell_id, dest_cell)


## Engine #113: ход върху единична противникова → Moved + Captured + SentHome.
func test_engine_landing_on_single_enemy_captures_and_sends_home() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
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
	assert_true(after_victim.is_in_base())
	assert_eq(after_victim.cell_id, expected_base)
	assert_eq(CellOccupancy.from_state(result.state).count_at(dest_cell), 1)


## Engine #113: exit-base върху spawn с единична противникова → capture.
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
	var after_victim := result.state.get_player(PlayerId.GREEN).get_pawn(green_pawn.pawn_id)
	assert_true(after_victim.is_in_base())
	assert_eq(after_victim.cell_id, expected_base)
	var after_mover := result.state.get_player(PlayerId.YELLOW).get_pawn(in_base.pawn_id)
	assert_eq(after_mover.cell_id, spawn)
	assert_true(after_mover.is_on_main_path())


## Engine #113: кацане върху своя + единична противникова → capture после stack.
func test_engine_capture_then_stack_formed_on_mixed_cell() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var resident := player.get_pawn_by_index(1)
	resident.set_position(PawnZone.MAIN_PATH, dest_index, dest_cell)
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
	var formed := result.events[3] as PawnStackFormedEvent
	assert_eq(formed.cell_id, dest_cell)
	assert_true(_stacks.is_friendly_stack(result.state, dest_cell, PlayerId.YELLOW))
	assert_true(result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id).is_in_base())


## #114: първа свободна base клетка в каноничен ред — не „оригиналният“ слот.
func test_send_home_uses_first_free_base_not_original_slot() -> void:
	var state := _two_player_in_progress()
	var green := state.get_player(PlayerId.GREEN)
	var bases: Array = Classic15x15Board.base_cells_for(PlayerId.GREEN)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var pawn0 := green.get_pawn_by_index(0)
	var pawn1 := green.get_pawn_by_index(1)
	pawn0.set_position(PawnZone.MAIN_PATH, 0, route[0])
	pawn1.set_position(PawnZone.MAIN_PATH, 5, route[5])

	assert_eq(_capture.first_free_base_cell(state, PlayerId.GREEN), bases[0])
	var original_slot: StringName = bases[1]
	var from_cell: StringName = pawn1.cell_id
	pawn1.apply_shield(3)

	var sent := _capture.send_pawn_home(state, pawn1, from_cell, 4)

	assert_not_null(sent)
	assert_true(sent.is_valid())
	assert_eq(sent.pawn_id, pawn1.pawn_id)
	assert_eq(sent.from_cell_id, from_cell)
	assert_eq(sent.base_cell_id, bases[0],
			"канонично първи свободен слот, не original bases[1]")
	assert_true(pawn1.is_in_base())
	assert_eq(pawn1.cell_id, bases[0])
	assert_ne(pawn1.cell_id, original_slot)
	assert_eq(pawn1.path_index, PawnState.PATH_INDEX_IN_BASE)
	assert_false(pawn1.has_shield(), "щитът се нулира при връщане в база")
	assert_true(Classic15x15Board.is_base_cell_of(PlayerId.GREEN, pawn1.cell_id))
	assert_eq(CellOccupancy.free_base_cells(state, PlayerId.GREEN, bases).size(), 1)
	assert_eq(CellOccupancy.free_base_cells(state, PlayerId.GREEN, bases)[0], bases[1])


## #114: втори capture заема следващия свободен слот — без двойна заетост.
func test_resolve_capture_fills_next_free_base_after_prior_send_home() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var green := state.get_player(PlayerId.GREEN)
	var bases: Array = Classic15x15Board.base_cells_for(PlayerId.GREEN)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
	var green0 := green.get_pawn_by_index(0)
	var green1 := green.get_pawn_by_index(1)
	green0.set_position(PawnZone.MAIN_PATH, 10, CellId.from_grid(8, 6))
	green1.set_position(PawnZone.MAIN_PATH, 20, dest_cell)
	# Предишен send-home: green0 вече заема bases[0] (първи свободен тогава).
	assert_not_null(_capture.send_pawn_home(
			state, green0, green0.cell_id, 1))
	assert_eq(green0.cell_id, bases[0])
	assert_eq(_capture.first_free_base_cell(state, PlayerId.GREEN), bases[1])

	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 1, route[1])
	assert_true(_rules.apply_board_move(state, player, mover, 3))
	var events := _capture.resolve_capture(state, mover, 8)

	assert_eq(events.size(), 2)
	var sent := events[1] as PawnSentHomeEvent
	assert_eq(sent.base_cell_id, bases[1],
			"следващият свободен слот след bases[0]")
	assert_true(green1.is_in_base())
	assert_eq(green1.cell_id, bases[1])
	assert_eq(green0.cell_id, bases[0])
	assert_ne(green0.cell_id, green1.cell_id)
	assert_eq(CellOccupancy.free_base_cells(state, PlayerId.GREEN, bases).size(), 0)


## Engine #114: capture → жертвата в първа свободна база (не original slot).
func test_engine_capture_sends_home_to_first_free_base_slot() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var green := state.get_player(PlayerId.GREEN)
	var bases: Array = Classic15x15Board.base_cells_for(PlayerId.GREEN)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_index := 4
	var dest_cell: StringName = route[dest_index]
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
	assert_eq(sent.base_cell_id, bases[0])
	assert_true(after_victim.is_in_base())
	assert_eq(after_victim.cell_id, bases[0],
			"green1 → bases[0], защото green0 още е на пътя")
	assert_eq(after_victim.path_index, PawnState.PATH_INDEX_IN_BASE)


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
