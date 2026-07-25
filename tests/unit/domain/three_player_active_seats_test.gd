class_name ThreePlayerActiveSeatsTest
extends TestCase
## Unit тестове за активните места при трима играчи (Task #45).
##
## Покрива docs/V1_GAME_DESIGN.md §3.3 и docs/V1_ARCHITECTURE.md §4.6 / §5.1:
##   - При 3 играчи се използват кои да е три от четирите бази.
##   - MatchConfig носи активните seats; BoardDefinition филтрира player_definitions.
##   - Classic15x15Board предоставя helpers за четирите валидни тройки.


# ── PlayerId тройки ───────────────────────────────────────────────────────────

func test_trio_constants_match_all_minus_one() -> void:
	assert_eq(PlayerId.TRIO_WITHOUT_CYAN, PlayerId.trio_excluding(PlayerId.CYAN))
	assert_eq(PlayerId.TRIO_WITHOUT_YELLOW, PlayerId.trio_excluding(PlayerId.YELLOW))
	assert_eq(PlayerId.TRIO_WITHOUT_ORANGE, PlayerId.trio_excluding(PlayerId.ORANGE))
	assert_eq(PlayerId.TRIO_WITHOUT_GREEN, PlayerId.trio_excluding(PlayerId.GREEN))


func test_trio_excluding_invalid_is_empty() -> void:
	assert_eq(PlayerId.trio_excluding(&"").size(), 0)
	assert_eq(PlayerId.trio_excluding(&"red").size(), 0)


func test_three_player_trios_lists_all_four() -> void:
	var trios := PlayerId.three_player_trios()
	assert_eq(trios.size(), 4)
	assert_eq(trios[0], PlayerId.TRIO_WITHOUT_CYAN)
	assert_eq(trios[1], PlayerId.TRIO_WITHOUT_YELLOW)
	assert_eq(trios[2], PlayerId.TRIO_WITHOUT_ORANGE)
	assert_eq(trios[3], PlayerId.TRIO_WITHOUT_GREEN)


func test_is_valid_three_player_trio_accepts_all_trios() -> void:
	for trio in PlayerId.three_player_trios():
		assert_true(PlayerId.is_valid_three_player_trio(trio),
				"тройката %s трябва да е валидна" % str(trio))


func test_is_valid_three_player_trio_order_independent() -> void:
	assert_true(PlayerId.is_valid_three_player_trio(
			[PlayerId.YELLOW, PlayerId.GREEN, PlayerId.ORANGE]))
	assert_true(PlayerId.is_valid_three_player_trio(
			[PlayerId.CYAN, PlayerId.ORANGE, PlayerId.YELLOW]))


func test_is_valid_three_player_trio_rejects_wrong_count_and_dupes() -> void:
	assert_false(PlayerId.is_valid_three_player_trio([]))
	assert_false(PlayerId.is_valid_three_player_trio([PlayerId.GREEN]))
	assert_false(PlayerId.is_valid_three_player_trio(
			[PlayerId.GREEN, PlayerId.YELLOW]))
	assert_false(PlayerId.is_valid_three_player_trio(PlayerId.ALL))
	assert_false(PlayerId.is_valid_three_player_trio(
			[PlayerId.GREEN, PlayerId.GREEN, PlayerId.YELLOW]))
	assert_false(PlayerId.is_valid_three_player_trio(
			[PlayerId.GREEN, PlayerId.ORANGE, &"red"]))


func test_excluded_from_trio_returns_missing_seat() -> void:
	assert_eq(PlayerId.excluded_from_trio(PlayerId.TRIO_WITHOUT_CYAN), PlayerId.CYAN)
	assert_eq(PlayerId.excluded_from_trio(PlayerId.TRIO_WITHOUT_GREEN), PlayerId.GREEN)
	assert_eq(
			PlayerId.excluded_from_trio(
					[PlayerId.YELLOW, PlayerId.ORANGE, PlayerId.GREEN]),
			PlayerId.CYAN)


func test_excluded_from_trio_invalid_is_empty() -> void:
	assert_eq(PlayerId.excluded_from_trio([]), &"")
	assert_eq(PlayerId.excluded_from_trio(PlayerId.ALL), &"")


# ── MatchConfig 3P API ────────────────────────────────────────────────────────

func test_default_3p_matches_trio_without_cyan() -> void:
	assert_eq(MatchConfig.DEFAULT_SEATS_3P, PlayerId.TRIO_WITHOUT_CYAN)
	assert_true(MatchConfig.is_valid_three_player_seats(MatchConfig.DEFAULT_SEATS_3P))


func test_three_player_seat_trios_matches_player_id() -> void:
	var from_cfg := MatchConfig.three_player_seat_trios()
	var from_pid := PlayerId.three_player_trios()
	assert_eq(from_cfg.size(), from_pid.size())
	for i in from_cfg.size():
		assert_eq(from_cfg[i], from_pid[i])
	assert_eq(from_cfg[0], MatchConfig.DEFAULT_SEATS_3P)


func test_is_valid_three_player_seats_accepts_all_trios() -> void:
	for trio in MatchConfig.three_player_seat_trios():
		assert_true(MatchConfig.is_valid_three_player_seats(trio))


func test_is_valid_three_player_seats_rejects_invalid() -> void:
	assert_false(MatchConfig.is_valid_three_player_seats([]))
	assert_false(MatchConfig.is_valid_three_player_seats(
			[PlayerId.GREEN, PlayerId.YELLOW]))
	assert_false(MatchConfig.is_valid_three_player_seats(PlayerId.ALL))
	assert_false(MatchConfig.is_valid_three_player_seats(
			[PlayerId.GREEN, PlayerId.ORANGE, &"red"]))


func test_create_three_player_defaults_to_without_cyan() -> void:
	var cfg := MatchConfig.create_three_player()
	assert_eq(cfg.get_active_seat_count(), 3)
	assert_eq(cfg.get_active_player_ids(), MatchConfig.DEFAULT_SEATS_3P)
	assert_true(cfg.is_valid())
	assert_true(MatchConfig.is_valid_three_player_seats(cfg.get_active_player_ids()))
	assert_false(cfg.has_active_seat(PlayerId.CYAN))


func test_create_three_player_accepts_each_trio() -> void:
	for trio in MatchConfig.three_player_seat_trios():
		var cfg := MatchConfig.create_three_player(trio)
		assert_eq(cfg.get_active_player_ids(), trio)
		assert_true(cfg.is_valid(), "тройката %s трябва да даде валиден config" % str(trio))
		assert_eq(cfg.get_active_seat_count(), 3)


func test_create_three_player_invalid_trio_is_invalid_config() -> void:
	var cfg := MatchConfig.create_three_player(
			[PlayerId.GREEN, PlayerId.ORANGE, &"red"])
	assert_eq(cfg.get_active_seat_count(), 3)
	assert_false(cfg.is_valid(), "невалиден player_id трябва да се отхвърли")
	assert_false(MatchConfig.is_valid_three_player_seats(cfg.get_active_player_ids()))


func test_create_with_seat_count_3_matches_create_three_player() -> void:
	var a := MatchConfig.create_with_seat_count(3)
	var b := MatchConfig.create_three_player()
	assert_eq(a.get_active_player_ids(), b.get_active_player_ids())


# ── BoardDefinition активни seats ─────────────────────────────────────────────

func test_board_has_definitions_for_all_three_player_trios() -> void:
	var board := Classic15x15Board.create()
	for trio in MatchConfig.three_player_seat_trios():
		assert_true(board.has_definitions_for_players(trio),
				"дъската трябва да има defs за %s" % str(trio))
		var active := board.get_active_player_definitions(trio)
		assert_eq(active.size(), 3, "3P трябва да активира точно 3 defs")
		assert_eq(active[0].player_id, StringName(trio[0]))
		assert_eq(active[1].player_id, StringName(trio[1]))
		assert_eq(active[2].player_id, StringName(trio[2]))


func test_get_active_player_definitions_preserves_three_player_order() -> void:
	var board := Classic15x15Board.create()
	var active := board.get_active_player_definitions(
			[PlayerId.YELLOW, PlayerId.CYAN, PlayerId.GREEN])
	assert_eq(active.size(), 3)
	assert_eq(active[0].player_id, PlayerId.YELLOW)
	assert_eq(active[1].player_id, PlayerId.CYAN)
	assert_eq(active[2].player_id, PlayerId.GREEN)


func test_full_board_still_has_four_seat_definitions_after_3p_filter() -> void:
	# 3P активира subset; BoardDefinition остава с SEAT_COUNT=4.
	var board := Classic15x15Board.create()
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)
	var active := board.get_active_player_definitions(MatchConfig.DEFAULT_SEATS_3P)
	assert_eq(active.size(), 3)
	assert_eq(board.player_definition_count(), BoardDefinition.SEAT_COUNT)


# ── Classic15x15Board 3P helpers ──────────────────────────────────────────────

func test_classic_default_three_player_seats_match_match_config() -> void:
	assert_eq(
			Classic15x15Board.default_three_player_seats(),
			MatchConfig.DEFAULT_SEATS_3P)


func test_classic_three_player_seat_trios() -> void:
	var trios := Classic15x15Board.three_player_seat_trios()
	assert_eq(trios.size(), 4)
	for trio in trios:
		assert_true(MatchConfig.is_valid_three_player_seats(trio))


func test_build_active_defs_for_default_three_players() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_three_players()
	assert_eq(defs.size(), 3)
	assert_eq(defs[0].player_id, PlayerId.GREEN)
	assert_eq(defs[1].player_id, PlayerId.ORANGE)
	assert_eq(defs[2].player_id, PlayerId.YELLOW)
	for def in defs:
		assert_true(def.is_valid(), "%s def трябва да е валидна" % def.player_id)


func test_build_active_defs_for_each_three_player_trio() -> void:
	for trio in MatchConfig.three_player_seat_trios():
		var defs := Classic15x15Board.build_active_player_definitions_for_three_players(
				trio)
		assert_eq(defs.size(), 3, "тройката %s трябва да даде 3 defs" % str(trio))
		assert_eq(defs[0].player_id, StringName(trio[0]))
		assert_eq(defs[1].player_id, StringName(trio[1]))
		assert_eq(defs[2].player_id, StringName(trio[2]))


func test_build_active_defs_rejects_invalid_three_player_set() -> void:
	var defs := Classic15x15Board.build_active_player_definitions_for_three_players(
			[PlayerId.GREEN, PlayerId.ORANGE])
	assert_eq(defs.size(), 0, "2 seats не са валиден 3P subset")
	defs = Classic15x15Board.build_active_player_definitions_for_three_players(
			[PlayerId.GREEN, PlayerId.ORANGE, &"red"])
	assert_eq(defs.size(), 0, "невалиден id не е валиден 3P subset")


func test_three_player_routes_exist_for_all_trios() -> void:
	for trio in MatchConfig.three_player_seat_trios():
		for pid in trio:
			var player_id := StringName(pid)
			var route := Classic15x15Board.player_route_cell_ids_for(player_id)
			assert_eq(route.size(), Classic15x15Board.PLAYER_ROUTE_LENGTH,
					"%s трябва да има пълен маршрут" % player_id)
			assert_eq(route[0], Classic15x15Board.spawn_cell_for(player_id))


func test_match_config_three_player_aligns_with_board_active_defs() -> void:
	for trio in MatchConfig.three_player_seat_trios():
		var cfg := MatchConfig.create_three_player(trio)
		assert_true(cfg.is_valid())
		var board := Classic15x15Board.create()
		var active := board.get_active_player_definitions(cfg.get_active_player_ids())
		assert_eq(active.size(), 3)
		var ids := cfg.get_active_player_ids()
		assert_eq(active[0].player_id, ids[0])
		assert_eq(active[1].player_id, ids[1])
		assert_eq(active[2].player_id, ids[2])
