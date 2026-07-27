extends TestCase
## Business-critical тестове за защитата на home stretch (Task #119 /
## docs/V1_GAME_DESIGN.md §3.2; docs/V1_ARCHITECTURE.md §12;
## #115 имплементация).
##
## Инвариант: home stretch не може да бъде атакуван. Пионки в HOME_STRETCH
## са недостъпни за взимане; чужд home stretch блокира кацане; маршрутите
## не включват чужди HOME клетки. Собственият home stretch остава достъпен.


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


## §3.2 / §12: HOME_STRETCH е защитена зона; MAIN_PATH — не.
func test_home_stretch_zone_is_protected_main_path_is_not() -> void:
	var state := _two_player_in_progress()
	var green := state.get_player(PlayerId.GREEN)
	var home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[0]
	var path_cell: StringName = CellId.from_grid(6, 8)
	var home_pawn := green.get_pawn_by_index(0)
	var path_pawn := green.get_pawn_by_index(1)
	home_pawn.set_position(PawnZone.HOME_STRETCH, 50, home)
	path_pawn.set_position(PawnZone.MAIN_PATH, 20, path_cell)

	assert_true(home_pawn.is_in_home_stretch())
	assert_true(_capture.is_protected_from_opponents(home_pawn))
	assert_false(_capture.is_capturable(home_pawn))
	assert_false(_capture.is_protected_from_opponents(path_pawn))
	assert_true(_capture.is_capturable(path_pawn))


## Дори при съвпадение на cell_id — HOME_STRETCH пионка не се взима (#115).
func test_home_stretch_pawn_not_capturable_on_shared_cell_id() -> void:
	var state := _two_player_in_progress()
	var home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[0]
	var green_pawn := state.get_player(PlayerId.GREEN).get_pawn_by_index(0)
	green_pawn.set_position(PawnZone.HOME_STRETCH, 50, home)
	var yellow := state.get_player(PlayerId.YELLOW).get_pawn_by_index(0)
	yellow.set_position(PawnZone.MAIN_PATH, 4, home)

	assert_null(_capture.find_capturable_at(state, home, PlayerId.YELLOW))
	assert_eq(_capture.resolve_capture(state, yellow, 1).size(), 0)
	assert_true(green_pawn.is_in_home_stretch())
	assert_eq(green_pawn.cell_id, home)


## Чужд home stretch блокира кацане; собственият и MAIN_PATH — не.
func test_foreign_home_stretch_blocks_landing_own_does_not() -> void:
	var green_home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.GREEN)[0]
	var yellow_home: StringName = Classic15x15Board.home_stretch_cells_for(
			PlayerId.YELLOW)[0]
	var path_cell: StringName = CellId.from_grid(6, 8)
	var state := _two_player_in_progress()

	assert_true(_capture.is_foreign_home_stretch(green_home, PlayerId.YELLOW))
	assert_false(_capture.is_foreign_home_stretch(yellow_home, PlayerId.YELLOW))
	assert_false(_capture.is_foreign_home_stretch(path_cell, PlayerId.YELLOW))
	assert_true(_capture.blocks_landing(state, green_home, PlayerId.YELLOW))
	assert_false(_capture.blocks_landing(state, yellow_home, PlayerId.YELLOW))
	assert_false(_capture.blocks_landing(state, path_cell, PlayerId.YELLOW))


## Всички HOME клетки на всеки seat са чужди за останалите и блокират кацане.
func test_all_foreign_home_cells_block_landing_for_every_seat() -> void:
	var state := _four_player_in_progress()
	for owner_id in PlayerId.ALL:
		var homes := Classic15x15Board.home_stretch_cells_for(owner_id)
		assert_eq(homes.size(), Classic15x15Board.HOME_STRETCH_CELLS_PER_PLAYER)
		for home_cell in homes:
			for attacker_id in PlayerId.ALL:
				if attacker_id == owner_id:
					assert_false(
							_capture.is_foreign_home_stretch(home_cell, attacker_id),
							"%s върху собствен home %s" % [attacker_id, home_cell])
					assert_false(
							_capture.blocks_landing(state, home_cell, attacker_id),
							"%s не се блокира на собствен home" % attacker_id)
				else:
					assert_true(
							_capture.is_foreign_home_stretch(home_cell, attacker_id),
							"%s → чужд home на %s" % [attacker_id, owner_id])
					assert_true(
							_capture.blocks_landing(state, home_cell, attacker_id),
							"%s блокиран на home на %s" % [attacker_id, owner_id])


## Структурна защита: route на seat съдържа само собствения home stretch.
func test_player_routes_never_include_foreign_home_stretch() -> void:
	for player_id in PlayerId.ALL:
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		for cell_id in route:
			var owner := Classic15x15Board.home_stretch_owner(cell_id)
			if owner == &"":
				continue
			assert_eq(owner, player_id,
					"%s route съдържа чужд home stretch %s" % [player_id, cell_id])
			assert_false(_capture.is_foreign_home_stretch(cell_id, player_id))


## Собственикът може да влезе/напредне в своя home stretch (контраст към чужд).
func test_owner_can_enter_own_home_stretch() -> void:
	var state := _two_player_in_progress()
	state.set_active_player(PlayerId.YELLOW)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var entry_index: int = Classic15x15Board.home_entry_path_index()
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.MAIN_PATH, entry_index, route[entry_index])

	assert_true(_rules.would_enter_home_stretch(state, player, pawn, 1))
	assert_true(_rules.can_move_pawn(state, player, pawn, 1))
	assert_true(_rules.apply_board_move(state, player, pawn, 1))
	assert_true(pawn.is_in_home_stretch())
	assert_eq(pawn.path_index, first_home)
	assert_eq(pawn.cell_id, route[first_home])
	assert_true(Classic15x15Board.is_home_stretch_cell_of(
			PlayerId.YELLOW, pawn.cell_id))


## Всички seats: пионка в home stretch не е capturable за никой противник.
func test_all_seats_home_stretch_pawns_are_immune_to_capture() -> void:
	for owner_id in PlayerId.ALL:
		var state := _four_player_in_progress()
		var homes := Classic15x15Board.home_stretch_cells_for(owner_id)
		var victim := state.get_player(owner_id).get_pawn_by_index(0)
		victim.set_position(PawnZone.HOME_STRETCH, 50, homes[0])
		assert_true(_capture.is_protected_from_opponents(victim),
				"%s home stretch е защитена" % owner_id)
		assert_false(_capture.is_capturable(victim),
				"%s home stretch не е capturable" % owner_id)
		for attacker_id in PlayerId.ALL:
			if attacker_id == owner_id:
				continue
			assert_null(
					_capture.find_capturable_at(state, homes[0], attacker_id),
					"%s не намира capturable на home на %s" % [
						attacker_id, owner_id])
			var attacker := state.get_player(attacker_id).get_pawn_by_index(0)
			attacker.set_position(PawnZone.MAIN_PATH, 4, homes[0])
			assert_eq(
					_capture.resolve_capture(state, attacker, 1).size(), 0,
					"%s resolve_capture не взима home на %s" % [
						attacker_id, owner_id])
			assert_true(victim.is_in_home_stretch())
			assert_eq(victim.cell_id, homes[0])


## Engine: ход на противник по MAIN_PATH не взима пионка в home stretch.
func test_engine_opponent_move_does_not_capture_home_stretch_pawn() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
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


## Engine: кацане върху MAIN_PATH единична противникова все още взима (контраст).
func test_engine_main_path_single_enemy_still_captured() -> void:
	var state := _two_player_in_progress()
	state.set_active_player_index(1)
	state.turn.begin_player_turn(1, false)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var dest_cell: StringName = route[4]
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
	assert_true(result.events[1] is PawnCapturedEvent)
	assert_true(result.events[2] is PawnSentHomeEvent)
	assert_true(result.state.get_player(PlayerId.GREEN).get_pawn(
			green_pawn.pawn_id).is_in_base())


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
