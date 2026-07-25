class_name TwoPlayerOppositeSeatsTest
extends TestCase
## Unit тестове за срещуположни места при двама играчи (Task #44).
##
## Покрива docs/V1_GAME_DESIGN.md §3.3 и docs/V1_ARCHITECTURE.md §4.6 / §5.1:
##   - При 2 играчи се използват срещуположни бази (NW↔SE или NE↔SW).
##   - MatchConfig носи активните seats; BoardDefinition филтрира player_definitions.
##   - Classic15x15Board предоставя helpers за двете валидни двойки.


# ── PlayerId геометрия ────────────────────────────────────────────────────────

func test_opposite_of_maps_diagonal_pairs() -> void:
	assert_eq(PlayerId.opposite_of(PlayerId.GREEN), PlayerId.YELLOW)
	assert_eq(PlayerId.opposite_of(PlayerId.YELLOW), PlayerId.GREEN)
	assert_eq(PlayerId.opposite_of(PlayerId.ORANGE), PlayerId.CYAN)
	assert_eq(PlayerId.opposite_of(PlayerId.CYAN), PlayerId.ORANGE)


func test_opposite_of_invalid_is_empty() -> void:
	assert_eq(PlayerId.opposite_of(&""), &"")
	assert_eq(PlayerId.opposite_of(&"red"), &"")


func test_are_opposite_accepts_both_pairs() -> void:
	assert_true(PlayerId.are_opposite(PlayerId.GREEN, PlayerId.YELLOW))
	assert_true(PlayerId.are_opposite(PlayerId.YELLOW, PlayerId.GREEN))
	assert_true(PlayerId.are_opposite(PlayerId.ORANGE, PlayerId.CYAN))
	assert_true(PlayerId.are_opposite(PlayerId.CYAN, PlayerId.ORANGE))


func test_are_opposite_rejects_adjacent_and_same() -> void:
	assert_false(PlayerId.are_opposite(PlayerId.GREEN, PlayerId.ORANGE))
	assert_false(PlayerId.are_opposite(PlayerId.GREEN, PlayerId.CYAN))
	assert_false(PlayerId.are_opposite(PlayerId.YELLOW, PlayerId.ORANGE))
	assert_false(PlayerId.are_opposite(PlayerId.YELLOW, PlayerId.CYAN))
	assert_false(PlayerId.are_opposite(PlayerId.GREEN, PlayerId.GREEN))
	assert_false(PlayerId.are_opposite(&"", PlayerId.YELLOW))


func test_opposite_pairs_lists_both_diagonals() -> void:
	var pairs := PlayerId.opposite_pairs()
	assert_eq(pairs.size(), 2)
	assert_eq(pairs[0], PlayerId.OPPOSITE_PAIR_GREEN_YELLOW)
	assert_eq(pairs[1], PlayerId.OPPOSITE_PAIR_ORANGE_CYAN)


# ── MatchConfig 2P API ────────────────────────────────────────────────────────

func test_default_and_alternate_2p_are_opposite_pairs() -> void:
	assert_eq(MatchConfig.DEFAULT_SEATS_2P, PlayerId.OPPOSITE_PAIR_GREEN_YELLOW)
	assert_eq(MatchConfig.ALTERNATE_SEATS_2P, PlayerId.OPPOSITE_PAIR_ORANGE_CYAN)
	assert_true(MatchConfig.is_valid_two_player_seats(MatchConfig.DEFAULT_SEATS_2P))
	assert_true(MatchConfig.is_valid_two_player_seats(MatchConfig.ALTERNATE_SEATS_2P))


func test_opposite_seat_pairs_matches_player_id() -> void:
	var pairs := MatchConfig.opposite_seat_pairs()
	assert_eq(pairs.size(), 2)
	assert_eq(pairs[0], MatchConfig.DEFAULT_SEATS_2P)
	assert_eq(pairs[1], MatchConfig.ALTERNATE_SEATS_2P)


func test_is_valid_two_player_seats_order_independent() -> void:
	assert_true(MatchConfig.is_valid_two_player_seats(
			[PlayerId.YELLOW, PlayerId.GREEN]))
	assert_true(MatchConfig.is_valid_two_player_seats(
			[PlayerId.CYAN, PlayerId.ORANGE]))


func test_is_valid_two_player_seats_rejects_adjacent_and_wrong_count() -> void:
	assert_false(MatchConfig.is_valid_two_player_seats(
			[PlayerId.GREEN, PlayerId.ORANGE]))
	assert_false(MatchConfig.is_valid_two_player_seats([PlayerId.GREEN]))
	assert_false(MatchConfig.is_valid_two_player_seats(PlayerId.ALL))
	assert_false(MatchConfig.is_valid_two_player_seats([]))
	assert_false(MatchConfig.is_valid_two_player_seats(
			[PlayerId.GREEN, &"red"]))


func test_create_two_player_opposite_defaults_to_green_yellow() -> void:
	var cfg := MatchConfig.create_two_player_opposite()
	assert_eq(cfg.get_active_seat_count(), 2)
	assert_eq(cfg.get_active_player_ids(), MatchConfig.DEFAULT_SEATS_2P)
	assert_true(cfg.is_valid())
	assert_true(MatchConfig.is_valid_two_player_seats(cfg.get_active_player_ids()))


func test_create_two_player_opposite_accepts_alternate_pair() -> void:
	var cfg := MatchConfig.create_two_player_opposite(MatchConfig.ALTERNATE_SEATS_2P)
	assert_eq(cfg.get_active_player_ids(), MatchConfig.ALTERNATE_SEATS_2P)
	assert_true(cfg.is_valid())


func test_create_two_player_opposite_adjacent_is_invalid_config() -> void:
	var cfg := MatchConfig.create_two_player_opposite(
			[PlayerId.GREEN, PlayerId.ORANGE])
	assert_eq(cfg.get_active_seat_count(), 2)
	assert_false(cfg.is_valid(), "съседни бази трябва да се отхвърлят от валидатора")
	assert_false(MatchConfig.is_valid_two_player_seats(cfg.get_active_player_ids()))


func test_are_opposite_seats_delegates_to_player_id() -> void:
	assert_eq(
			MatchConfig.are_opposite_seats(PlayerId.GREEN, PlayerId.YELLOW),
			PlayerId.are_opposite(PlayerId.GREEN, PlayerId.YELLOW))
	assert_eq(
			MatchConfig.are_opposite_seats(PlayerId.GREEN, PlayerId.ORANGE),
			PlayerId.are_opposite(PlayerId.GREEN, PlayerId.ORANGE))


func test_create_with_seat_count_2_matches_create_two_player_opposite() -> void:
	var a := MatchConfig.create_with_seat_count(2)
	var b := MatchConfig.create_two_player_opposite()
	assert_eq(a.get_active_player_ids(), b.get_active_player_ids())


# ── BoardDefinition активни seats ─────────────────────────────────────────────

func test_board_has_definitions_for_both_opposite_pairs() -> void:
	var board := Classic15x15Board.create()
	for pair in MatchConfig.opposite_seat_pairs():
		assert_true(board.has_definitions_for_players(pair),
				"дъската трябва да има defs за %s" % str(pair))
		var active := board.get_active_player_definitions(pair)
		assert_eq(active.size(), 2, "2P трябва да активира точно 2 defs")
		assert_eq(active[0].player_id, StringName(pair[0]))
		assert_eq(active[1].player_id, StringName(pair[1]))


func test_get_active_player_definitions_preserves_order() -> void:
	var board := Classic15x15Board.create()
	var active := board.get_active_player_definitions(
			[PlayerId.YELLOW, PlayerId.GREEN])
	assert_eq(active.size(), 2)
	assert_eq(active[0].player_id, PlayerId.YELLOW)
	assert_eq(active[1].player_id, PlayerId.GREEN)


func test_get_active_player_definitions_skips_unknown() -> void:
	var board := Classic15x15Board.create()
	var active := board.get_active_player_definitions(
			[PlayerId.GREEN, &"red", PlayerId.YELLOW])
	assert_eq(active.size(), 2)
	assert_eq(active[0].player_id, PlayerId.GREEN)
	assert_eq(active[1].player_id, PlayerId.YELLOW)


func test_has_definitions_for_players_rejects_empty_and_unknown() -> void:
	var board := Classic15x15Board.create()
	assert_false(board.has_definitions_for_players([]))
	assert_false(board.has_definitions_for_players([PlayerId.GREEN, &"red"]))


func test_full_board_still_has_four_seat_definitions() -> void:
	# 2P активира subset; BoardDefinition остава с SEAT_COUNT=4.
	var board := Classic15x15Board.create()
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)
	var active := board.get_active_player_definitions(MatchConfig.DEFAULT_SEATS_2P)
	assert_eq(active.size(), 2)
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)


# ── Classic15x15Board 2P helpers ──────────────────────────────────────────────

func test_classic_default_two_player_seats_match_match_config() -> void:
	assert_eq(
			Classic15x15Board.default_two_player_seats(),
			MatchConfig.DEFAULT_SEATS_2P)
	assert_eq(
			Classic15x15Board.alternate_two_player_seats(),
			MatchConfig.ALTERNATE_SEATS_2P)


func test_classic_two_player_opposite_seat_pairs() -> void:
	var pairs := Classic15x15Board.two_player_opposite_seat_pairs()
	assert_eq(pairs.size(), 2)
	for pair in pairs:
		assert_true(MatchConfig.is_valid_two_player_seats(pair))


func test_build_active_defs_for_default_two_players() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_two_players()
	assert_eq(defs.size(), 2)
	assert_eq(defs[0].player_id, PlayerId.GREEN)
	assert_eq(defs[1].player_id, PlayerId.YELLOW)
	for def in defs:
		assert_true(def.is_valid(), "%s def трябва да е валидна" % def.player_id)


func test_build_active_defs_for_alternate_two_players() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_two_players(
			MatchConfig.ALTERNATE_SEATS_2P)
	assert_eq(defs.size(), 2)
	assert_eq(defs[0].player_id, PlayerId.ORANGE)
	assert_eq(defs[1].player_id, PlayerId.CYAN)


func test_build_active_defs_rejects_adjacent_pair() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_two_players(
			[PlayerId.GREEN, PlayerId.ORANGE])
	assert_eq(defs.size(), 0, "съседни бази не са валиден 2P subset")


func test_two_player_routes_exist_for_both_opposite_pairs() -> void:
	for pair in MatchConfig.opposite_seat_pairs():
		for pid in pair:
			var player_id := StringName(pid)
			var route := Classic15x15Board.player_route_cell_ids_for(player_id)
			assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
					"%s трябва да има пълен маршрут" % player_id)
			assert_eq(route[0], Classic15x15Board.spawn_cell_for(player_id))


func test_match_config_two_player_aligns_with_board_active_defs() -> void:
	for pair in MatchConfig.opposite_seat_pairs():
		var cfg := MatchConfig.create_two_player_opposite(pair)
		assert_true(cfg.is_valid())
		var board := Classic15x15Board.create()
		var active := board.get_active_player_definitions(cfg.get_active_player_ids())
		assert_eq(active.size(), 2)
		assert_eq(active[0].player_id, cfg.get_active_player_ids()[0])
		assert_eq(active[1].player_id, cfg.get_active_player_ids()[1])
