class_name FourPlayerActiveSeatsTest
extends TestCase
## Unit тестове за активните места при четирима играчи (Task #46).
##
## Покрива docs/V1_GAME_DESIGN.md §3.3 и docs/V1_ARCHITECTURE.md §4.6 / §5.1:
##   - При 4 играчи се използват всички четири бази.
##   - MatchConfig носи активните seats; BoardDefinition филтрира player_definitions.
##   - Classic15x15Board предоставя helpers за пълния 4P набор.


# ── PlayerId пълен набор ──────────────────────────────────────────────────────

func test_all_seats_matches_all_constant() -> void:
	assert_eq(PlayerId.all_seats(), PlayerId.ALL)
	assert_eq(PlayerId.all_seats().size(), PlayerId.COUNT)


func test_all_seats_returns_independent_copy() -> void:
	var a := PlayerId.all_seats()
	var b := PlayerId.all_seats()
	a[0] = &"mutated"
	assert_eq(b[0], PlayerId.GREEN, "all_seats() трябва да връща независимо копие")
	assert_eq(PlayerId.ALL[0], PlayerId.GREEN)


func test_is_valid_four_player_set_accepts_all() -> void:
	assert_true(PlayerId.is_valid_four_player_set(PlayerId.ALL))
	assert_true(PlayerId.is_valid_four_player_set(PlayerId.all_seats()))


func test_is_valid_four_player_set_order_independent() -> void:
	assert_true(PlayerId.is_valid_four_player_set(
			[PlayerId.CYAN, PlayerId.YELLOW, PlayerId.ORANGE, PlayerId.GREEN]))
	assert_true(PlayerId.is_valid_four_player_set(
			[PlayerId.YELLOW, PlayerId.GREEN, PlayerId.CYAN, PlayerId.ORANGE]))


func test_is_valid_four_player_set_rejects_wrong_count_and_dupes() -> void:
	assert_false(PlayerId.is_valid_four_player_set([]))
	assert_false(PlayerId.is_valid_four_player_set([PlayerId.GREEN]))
	assert_false(PlayerId.is_valid_four_player_set(
			[PlayerId.GREEN, PlayerId.YELLOW]))
	assert_false(PlayerId.is_valid_four_player_set(
			PlayerId.TRIO_WITHOUT_CYAN))
	assert_false(PlayerId.is_valid_four_player_set(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, PlayerId.GREEN]))
	assert_false(PlayerId.is_valid_four_player_set(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, &"red"]))


# ── MatchConfig 4P API ────────────────────────────────────────────────────────

func test_default_4p_matches_player_id_all() -> void:
	assert_eq(MatchConfig.DEFAULT_SEATS_4P, PlayerId.ALL)
	assert_true(MatchConfig.is_valid_four_player_seats(MatchConfig.DEFAULT_SEATS_4P))


func test_four_player_seat_set_matches_player_id() -> void:
	assert_eq(MatchConfig.four_player_seat_set(), PlayerId.all_seats())
	assert_eq(MatchConfig.four_player_seat_set(), MatchConfig.DEFAULT_SEATS_4P)


func test_is_valid_four_player_seats_accepts_all_orders() -> void:
	assert_true(MatchConfig.is_valid_four_player_seats(MatchConfig.DEFAULT_SEATS_4P))
	assert_true(MatchConfig.is_valid_four_player_seats(
			[PlayerId.CYAN, PlayerId.GREEN, PlayerId.YELLOW, PlayerId.ORANGE]))


func test_is_valid_four_player_seats_rejects_invalid() -> void:
	assert_false(MatchConfig.is_valid_four_player_seats([]))
	assert_false(MatchConfig.is_valid_four_player_seats(
			[PlayerId.GREEN, PlayerId.YELLOW]))
	assert_false(MatchConfig.is_valid_four_player_seats(
			MatchConfig.DEFAULT_SEATS_3P))
	assert_false(MatchConfig.is_valid_four_player_seats(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, &"red"]))


func test_create_four_player_defaults_to_all_seats() -> void:
	var cfg := MatchConfig.create_four_player()
	assert_eq(cfg.get_active_seat_count(), 4)
	assert_eq(cfg.get_active_player_ids(), MatchConfig.DEFAULT_SEATS_4P)
	assert_true(cfg.is_valid())
	assert_true(MatchConfig.is_valid_four_player_seats(cfg.get_active_player_ids()))
	for id in PlayerId.ALL:
		assert_true(cfg.has_active_seat(id), "4P трябва да активира %s" % id)


func test_create_four_player_accepts_custom_order() -> void:
	var order: Array[StringName] = [
		PlayerId.CYAN, PlayerId.YELLOW, PlayerId.ORANGE, PlayerId.GREEN,
	]
	var cfg := MatchConfig.create_four_player(order)
	assert_eq(cfg.get_active_player_ids(), order)
	assert_true(cfg.is_valid())
	assert_eq(cfg.get_active_seat_count(), 4)


func test_create_four_player_invalid_set_is_invalid_config() -> void:
	var cfg := MatchConfig.create_four_player(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, &"red"])
	assert_eq(cfg.get_active_seat_count(), 4)
	assert_false(cfg.is_valid(), "невалиден player_id трябва да се отхвърли")
	assert_false(MatchConfig.is_valid_four_player_seats(cfg.get_active_player_ids()))


func test_create_with_seat_count_4_matches_create_four_player() -> void:
	var a := MatchConfig.create_with_seat_count(4)
	var b := MatchConfig.create_four_player()
	assert_eq(a.get_active_player_ids(), b.get_active_player_ids())


# ── BoardDefinition активни seats ─────────────────────────────────────────────

func test_board_has_definitions_for_four_player_set() -> void:
	var board := Classic15x15Board.create()
	var seats := MatchConfig.DEFAULT_SEATS_4P
	assert_true(board.has_definitions_for_players(seats),
			"дъската трябва да има defs за всички 4 seats")
	var active := board.get_active_player_definitions(seats)
	assert_eq(active.size(), 4, "4P трябва да активира точно 4 defs")
	for i in seats.size():
		assert_eq(active[i].player_id, seats[i])


func test_get_active_player_definitions_preserves_four_player_order() -> void:
	var board := Classic15x15Board.create()
	var order: Array[StringName] = [
		PlayerId.YELLOW, PlayerId.CYAN, PlayerId.GREEN, PlayerId.ORANGE,
	]
	var active := board.get_active_player_definitions(order)
	assert_eq(active.size(), 4)
	assert_eq(active[0].player_id, PlayerId.YELLOW)
	assert_eq(active[1].player_id, PlayerId.CYAN)
	assert_eq(active[2].player_id, PlayerId.GREEN)
	assert_eq(active[3].player_id, PlayerId.ORANGE)


func test_full_board_still_has_four_seat_definitions_after_4p_filter() -> void:
	# 4P активира всички; BoardDefinition остава с SEAT_COUNT=4.
	var board := Classic15x15Board.create()
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)
	var active := board.get_active_player_definitions(MatchConfig.DEFAULT_SEATS_4P)
	assert_eq(active.size(), 4)
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)


# ── Classic15x15Board 4P helpers ──────────────────────────────────────────────

func test_classic_default_four_player_seats_match_match_config() -> void:
	assert_eq(
			Classic15x15Board.default_four_player_seats(),
			MatchConfig.DEFAULT_SEATS_4P)


func test_classic_four_player_seat_set() -> void:
	var seats := Classic15x15Board.four_player_seat_set()
	assert_eq(seats.size(), 4)
	assert_true(MatchConfig.is_valid_four_player_seats(seats))
	assert_eq(seats, MatchConfig.four_player_seat_set())


func test_build_active_defs_for_default_four_players() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_four_players()
	assert_eq(defs.size(), 4)
	assert_eq(defs[0].player_id, PlayerId.GREEN)
	assert_eq(defs[1].player_id, PlayerId.ORANGE)
	assert_eq(defs[2].player_id, PlayerId.YELLOW)
	assert_eq(defs[3].player_id, PlayerId.CYAN)
	for def in defs:
		assert_true(def.is_valid(), "%s def трябва да е валидна" % def.player_id)


func test_build_active_defs_for_custom_four_player_order() -> void:
	var order: Array[StringName] = [
		PlayerId.CYAN, PlayerId.GREEN, PlayerId.YELLOW, PlayerId.ORANGE,
	]
	var defs := Classic15x15Board.build_active_player_definitions_for_four_players(
			order)
	assert_eq(defs.size(), 4)
	assert_eq(defs[0].player_id, PlayerId.CYAN)
	assert_eq(defs[1].player_id, PlayerId.GREEN)
	assert_eq(defs[2].player_id, PlayerId.YELLOW)
	assert_eq(defs[3].player_id, PlayerId.ORANGE)


func test_build_active_defs_rejects_invalid_four_player_set() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_four_players(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW])
	assert_eq(defs.size(), 0, "3 seats не са валиден 4P набор")
	defs = Classic15x15Board.build_active_player_definitions_for_four_players(
			[PlayerId.GREEN, PlayerId.ORANGE, PlayerId.YELLOW, &"red"])
	assert_eq(defs.size(), 0, "невалиден id не е валиден 4P набор")


func test_four_player_routes_exist_for_all_seats() -> void:
	for pid in MatchConfig.DEFAULT_SEATS_4P:
		var player_id := StringName(pid)
		var route := Classic15x15Board.player_route_cell_ids_for(player_id)
		assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
				"%s трябва да има пълен маршрут" % player_id)
		assert_eq(route[0], Classic15x15Board.spawn_cell_for(player_id))


func test_match_config_four_player_aligns_with_board_active_defs() -> void:
	var cfg := MatchConfig.create_four_player()
	assert_true(cfg.is_valid())
	var board := Classic15x15Board.create()
	var active := board.get_active_player_definitions(cfg.get_active_player_ids())
	assert_eq(active.size(), 4)
	var ids := cfg.get_active_player_ids()
	for i in ids.size():
		assert_eq(active[i].player_id, ids[i])
