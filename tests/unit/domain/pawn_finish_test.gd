extends TestCase
## Business-critical тестове за прибиране + класиране на играч (Task #99 /
## docs/V1_GAME_DESIGN.md §3.1 / §3.2; docs/V1_ARCHITECTURE.md §4.1 / §12).
##
## V1.1: прибирането е играч-ниво флаг-превключване на място (FinishRules.
## resolve_home_stretch_completion), не на отделна пионка чрез точен зар до
## CellId.CENTER — вижте exact_finish_dice_test.gd за самия механизъм.
## Тук: изисква ВСИЧКИТЕ 4 (не само едната в home stretch); 4-тата приета
## пионка каскадира до PlayerRanked (+ auto-rank последен / MatchFinished при 2p).


var _finish: FinishRules
var _move: MoveRules
var _engine: GameEngine


func before_each() -> void:
	_finish = FinishRules.new()
	_move = MoveRules.new(_finish)
	_engine = GameEngine.new()
	MatchId._reset_counter_for_tests()


## Три в home stretch + една на MAIN_PATH → все още не е "прибрал" никого.
func test_finish_requires_all_four_in_home_stretch_not_just_some() -> void:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		var idx: int = first_home + i
		player.get_pawn_by_index(i).set_position(PawnZone.HOME_STRETCH, idx, route[idx])
	player.get_pawn_by_index(0).set_position(
			PawnZone.MAIN_PATH, first_home - 1, route[first_home - 1])

	var events := _finish.resolve_home_stretch_completion(player, 3)

	assert_true(events.is_empty(),
			"пионка на MAIN_PATH блокира прибирането на целия играч")
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		assert_false(player.get_pawn_by_index(i).is_finished())


## 4-та прибрана пионка → PlayerRanked (+ auto-rank последен при 2p → MatchFinished).
func test_engine_fourth_finish_ranks_player_and_finishes_two_player_match() -> void:
	var state := _setup_yellow_awaiting_home_stretch_move(1)
	var player := state.get_active_player()
	var route := Classic15x15Board.player_route_cell_ids_for(player.player_id)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	for i in range(1, PlayerState.PAWNS_PER_PLAYER):
		var idx: int = first_home + i
		player.get_pawn_by_index(i).mark_finished(idx, route[idx])
	assert_eq(player.count_finished_pawns(), 3)
	var rng := SeededRandomSource.new(state.get_rng_seed())
	var cmd := MovePawnCommand.create_for_pawn(
			player.player_id, player.get_pawn_by_index(0).pawn_id)
	state.stamp_command(cmd)

	var result := _engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	var after_player := result.state.get_player(player.player_id)
	assert_true(after_player.has_finished_all_pawns())
	assert_true(after_player.is_ranked())
	assert_eq(after_player.rank, PlayerState.RANK_FIRST)
	var ranked := false
	var match_finished := false
	for entry in result.events:
		if entry is PlayerRankedEvent:
			var ev := entry as PlayerRankedEvent
			if ev.player_id == player.player_id:
				assert_eq(ev.rank, 1)
				ranked = true
		elif entry is MatchFinishedEvent:
			match_finished = true
	assert_true(ranked, "4 прибрани → PlayerRanked")
	assert_true(match_finished, "2p: auto-rank последен → MatchFinished")
	assert_true(result.state.is_finished())


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


func _setup_yellow_in_home_stretch() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	state.set_phase(MatchPhase.IN_PROGRESS)
	state.set_active_player_index(1)
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	state.turn.begin_player_turn(1, false)
	return state


## Пионка на последна HOME клетка, готова да "остане" там (dice_value=1 е
## overshoot от там — реалният finish идва от completion-а на играча, не от
## тази команда; helper-ът се ползва само за 4-тата-пионка сценария, при
## който мовърът влиза в home stretch с dice_value от MAIN_PATH).
func _setup_yellow_awaiting_home_stretch_move(dice_value: int) -> GameState:
	var state := _setup_yellow_in_home_stretch()
	var player := state.get_active_player()
	var pawn := player.get_pawn_by_index(0)
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var first_home: int = Classic15x15Board.first_home_stretch_path_index()
	pawn.set_position(PawnZone.MAIN_PATH, first_home - 1, route[first_home - 1])
	state.turn.enter_awaiting_move(dice_value, [pawn.pawn_id])
	state.dice.set_roll(player.player_id, dice_value)
	return state
