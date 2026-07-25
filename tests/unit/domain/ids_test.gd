class_name IdsTest
extends TestCase
## Unit тестове за стабилните идентификатори: PlayerId, PawnId, CellId, MatchId.
##
## Покрити инварианти (docs/V1_ARCHITECTURE.md, раздел 12):
##   - Domain не използва Vector2, NodePath или editor-generated имена.
##   - Всяка пионка е точно в една зона — изисква уникален, стабилен pawn_id.
##   - Командите носят match_id и player_id — те трябва да са добре дефинирани.


# ── PlayerId ─────────────────────────────────────────────────────────────────

func test_player_id_constants_are_string_names() -> void:
	assert_true(PlayerId.GREEN is StringName, "GREEN трябва да е StringName")
	assert_true(PlayerId.ORANGE is StringName, "ORANGE трябва да е StringName")
	assert_true(PlayerId.YELLOW is StringName, "YELLOW трябва да е StringName")
	assert_true(PlayerId.CYAN is StringName, "CYAN трябва да е StringName")


func test_player_id_constants_have_expected_values() -> void:
	assert_eq(PlayerId.GREEN, &"green", "GREEN трябва да е &\"green\"")
	assert_eq(PlayerId.ORANGE, &"orange", "ORANGE трябва да е &\"orange\"")
	assert_eq(PlayerId.YELLOW, &"yellow", "YELLOW трябва да е &\"yellow\"")
	assert_eq(PlayerId.CYAN, &"cyan", "CYAN трябва да е &\"cyan\"")


func test_player_id_all_has_exactly_four_entries() -> void:
	assert_eq(PlayerId.ALL.size(), 4, "PlayerId.ALL трябва да съдържа точно 4 ID-та")
	assert_eq(PlayerId.COUNT, 4, "PlayerId.COUNT трябва да е 4")


func test_player_id_all_entries_are_valid() -> void:
	for id in PlayerId.ALL:
		assert_true(PlayerId.is_valid(id),
				"Всяко ID в PlayerId.ALL трябва да е валидно: %s" % id)


func test_player_id_is_valid_accepts_all_four() -> void:
	assert_true(PlayerId.is_valid(&"green"),  "green е валиден")
	assert_true(PlayerId.is_valid(&"orange"), "orange е валиден")
	assert_true(PlayerId.is_valid(&"yellow"), "yellow е валиден")
	assert_true(PlayerId.is_valid(&"cyan"),   "cyan е валиден")


func test_player_id_is_valid_rejects_unknown() -> void:
	assert_false(PlayerId.is_valid(&""), "празен StringName не е валиден")
	assert_false(PlayerId.is_valid(&"red"), "red не е player_id в това Ludo")
	assert_false(PlayerId.is_valid(&"purple"), "purple не е валиден")
	assert_false(PlayerId.is_valid(&"player_0"), "player_0 не е валиден формат")


func test_player_id_from_seat_returns_correct_id() -> void:
	assert_eq(PlayerId.from_seat(0), PlayerId.GREEN,  "seat 0 → GREEN")
	assert_eq(PlayerId.from_seat(1), PlayerId.ORANGE, "seat 1 → ORANGE")
	assert_eq(PlayerId.from_seat(2), PlayerId.YELLOW, "seat 2 → YELLOW")
	assert_eq(PlayerId.from_seat(3), PlayerId.CYAN,   "seat 3 → CYAN")


func test_player_id_from_seat_out_of_range_returns_empty() -> void:
	assert_eq(PlayerId.from_seat(-1), &"", "seat -1 → &\"\"")
	assert_eq(PlayerId.from_seat(4),  &"", "seat 4 → &\"\"")


func test_player_id_to_seat_returns_correct_index() -> void:
	assert_eq(PlayerId.to_seat(PlayerId.GREEN),  0, "GREEN → seat 0")
	assert_eq(PlayerId.to_seat(PlayerId.ORANGE), 1, "ORANGE → seat 1")
	assert_eq(PlayerId.to_seat(PlayerId.YELLOW), 2, "YELLOW → seat 2")
	assert_eq(PlayerId.to_seat(PlayerId.CYAN),   3, "CYAN → seat 3")


func test_player_id_to_seat_returns_minus_one_for_invalid() -> void:
	assert_eq(PlayerId.to_seat(&""), -1, "невалиден ID → -1")
	assert_eq(PlayerId.to_seat(&"red"), -1, "red → -1")


func test_player_id_from_seat_to_seat_roundtrip() -> void:
	for seat in PlayerId.COUNT:
		var id := PlayerId.from_seat(seat)
		assert_eq(PlayerId.to_seat(id), seat,
				"roundtrip seat %d трябва да върне същата стойност" % seat)


# ── PawnId ────────────────────────────────────────────────────────────────────

func test_pawn_id_for_player_returns_expected_format() -> void:
	assert_eq(PawnId.for_player(&"yellow", 0), &"yellow_0")
	assert_eq(PawnId.for_player(&"yellow", 3), &"yellow_3")
	assert_eq(PawnId.for_player(&"green",  1), &"green_1")
	assert_eq(PawnId.for_player(&"cyan",   2), &"cyan_2")


func test_pawn_id_all_for_player_returns_four_ids() -> void:
	for player_id in PlayerId.ALL:
		var pawns := PawnId.all_for_player(player_id)
		assert_eq(pawns.size(), PawnId.PAWNS_PER_PLAYER,
				"%s трябва да има %d пионки" % [player_id, PawnId.PAWNS_PER_PLAYER])


func test_pawn_id_all_for_player_ids_are_unique() -> void:
	var all_ids: Array[StringName] = []
	for player_id in PlayerId.ALL:
		all_ids.append_array(PawnId.all_for_player(player_id))
	var unique: Dictionary = {}
	for id in all_ids:
		assert_false(unique.has(id), "pawn_id %s се повтаря!" % id)
		unique[id] = true
	assert_eq(all_ids.size(), 16, "Трябва да има точно 16 уникални pawn_id")


func test_pawn_id_get_player_id_extracts_correctly() -> void:
	assert_eq(PawnId.get_player_id(&"yellow_0"), &"yellow")
	assert_eq(PawnId.get_player_id(&"green_3"),  &"green")
	assert_eq(PawnId.get_player_id(&"cyan_2"),   &"cyan")
	assert_eq(PawnId.get_player_id(&"orange_1"), &"orange")


func test_pawn_id_get_player_id_returns_empty_for_invalid() -> void:
	assert_eq(PawnId.get_player_id(&""), &"", "празен → &\"\"")
	assert_eq(PawnId.get_player_id(&"yellow"), &"", "без underscore → &\"\"")


func test_pawn_id_get_index_extracts_correctly() -> void:
	assert_eq(PawnId.get_index(&"yellow_0"), 0)
	assert_eq(PawnId.get_index(&"yellow_3"), 3)
	assert_eq(PawnId.get_index(&"cyan_2"),   2)


func test_pawn_id_get_index_returns_minus_one_for_invalid() -> void:
	assert_eq(PawnId.get_index(&""), -1, "празен → -1")
	assert_eq(PawnId.get_index(&"yellow"), -1, "без индекс → -1")


func test_pawn_id_is_valid_accepts_well_formed() -> void:
	for player_id in PlayerId.ALL:
		for i in PawnId.PAWNS_PER_PLAYER:
			var pid := PawnId.for_player(player_id, i)
			assert_true(PawnId.is_valid(pid),
					"%s трябва да е валиден pawn_id" % pid)


func test_pawn_id_is_valid_rejects_unknown_player() -> void:
	assert_false(PawnId.is_valid(&"purple_0"), "purple не е валиден player_id")
	assert_false(PawnId.is_valid(&"red_1"),    "red не е валиден player_id")


func test_pawn_id_is_valid_rejects_out_of_range_index() -> void:
	assert_false(PawnId.is_valid(&"yellow_4"), "индекс 4 е извън [0,3]")


func test_pawn_id_roundtrip_player_and_index() -> void:
	for player_id in PlayerId.ALL:
		for i in PawnId.PAWNS_PER_PLAYER:
			var pid := PawnId.for_player(player_id, i)
			assert_eq(PawnId.get_player_id(pid), player_id,
					"roundtrip player_id за %s" % pid)
			assert_eq(PawnId.get_index(pid), i,
					"roundtrip index за %s" % pid)


# ── CellId ────────────────────────────────────────────────────────────────────

func test_cell_id_center_constant() -> void:
	assert_eq(CellId.CENTER, &"c_7_7", "CENTER трябва да е &\"c_7_7\"")


func test_cell_id_from_grid_format() -> void:
	assert_eq(CellId.from_grid(0, 0),   &"c_0_0")
	assert_eq(CellId.from_grid(7, 7),   &"c_7_7")
	assert_eq(CellId.from_grid(14, 14), &"c_14_14")
	assert_eq(CellId.from_grid(8, 2),   &"c_8_2")   # GREEN spawn
	assert_eq(CellId.from_grid(12, 8),  &"c_12_8")  # ORANGE spawn
	assert_eq(CellId.from_grid(6, 12),  &"c_6_12")  # YELLOW spawn
	assert_eq(CellId.from_grid(2, 6),   &"c_2_6")   # CYAN spawn


func test_cell_id_from_vec_matches_from_grid() -> void:
	var test_positions: Array[Vector2i] = [
		Vector2i(7, 7), Vector2i(0, 0), Vector2i(14, 14),
		Vector2i(8, 2), Vector2i(6, 12),
	]
	for pos in test_positions:
		assert_eq(CellId.from_vec(pos), CellId.from_grid(pos.x, pos.y),
				"from_vec(%s) трябва да съответства на from_grid" % str(pos))


func test_cell_id_from_vec_center_equals_constant() -> void:
	assert_eq(CellId.from_vec(Vector2i(7, 7)), CellId.CENTER,
			"from_vec(7,7) трябва да е CENTER")


func test_cell_id_to_vec_roundtrip() -> void:
	var test_positions: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(7, 7), Vector2i(14, 14),
		Vector2i(8, 2), Vector2i(2, 11), Vector2i(11, 3),
	]
	for pos in test_positions:
		var cell_id := CellId.from_vec(pos)
		var roundtrip := CellId.to_vec(cell_id)
		assert_eq(roundtrip, pos, "roundtrip за %s" % str(pos))


func test_cell_id_to_vec_invalid_returns_minus_one() -> void:
	assert_eq(CellId.to_vec(&""), Vector2i(-1, -1), "празен → (-1,-1)")
	assert_eq(CellId.to_vec(&"yellow"), Vector2i(-1, -1), "без c_ префикс → (-1,-1)")
	assert_eq(CellId.to_vec(&"c_7"), Vector2i(-1, -1), "непълен формат → (-1,-1)")


func test_cell_id_is_valid_accepts_in_bounds() -> void:
	assert_true(CellId.is_valid(&"c_0_0"),    "c_0_0 е валидно")
	assert_true(CellId.is_valid(&"c_7_7"),    "c_7_7 е валидно")
	assert_true(CellId.is_valid(&"c_14_14"),  "c_14_14 е валидно")


func test_cell_id_is_valid_rejects_out_of_bounds() -> void:
	assert_false(CellId.is_valid(&"c_15_0"),  "col=15 е извън [0,14]")
	assert_false(CellId.is_valid(&"c_0_15"),  "row=15 е извън [0,14]")
	assert_false(CellId.is_valid(&"c_-1_0"),  "отрицателна колона")


func test_cell_id_is_valid_rejects_bad_format() -> void:
	assert_false(CellId.is_valid(&""),        "празен string")
	assert_false(CellId.is_valid(&"7_7"),     "без c_ префикс")
	assert_false(CellId.is_valid(&"c_abc_0"), "нечислова стойност")


func test_cell_id_board_size_constant() -> void:
	assert_eq(CellId.BOARD_SIZE, 15, "BOARD_SIZE трябва да е 15")


func test_cell_id_all_grid_positions_are_valid() -> void:
	for col in CellId.BOARD_SIZE:
		for row in CellId.BOARD_SIZE:
			var id := CellId.from_grid(col, row)
			assert_true(CellId.is_valid(id),
					"Клетка (%d,%d) трябва да е валидна" % [col, row])


# ── MatchId ───────────────────────────────────────────────────────────────────

func test_match_id_generate_returns_string_name() -> void:
	var id := MatchId.generate()
	assert_true(id is StringName, "generate() трябва да върне StringName")


func test_match_id_generate_starts_with_m_prefix() -> void:
	var id := MatchId.generate()
	assert_true(MatchId.is_valid(id),
			"generate() трябва да върне ID с 'm_' префикс")


func test_match_id_generate_is_unique_per_call() -> void:
	var ids: Array[StringName] = []
	for _i in 10:
		var id := MatchId.generate()
		assert_false(id in ids, "generate() върна дублиран ID: %s" % id)
		ids.append(id)


func test_match_id_is_valid_accepts_m_prefix() -> void:
	assert_true(MatchId.is_valid(&"m_0_0"),           "минимален валиден ID")
	assert_true(MatchId.is_valid(&"m_1721915400000_3"), "типичен генериран ID")


func test_match_id_is_valid_rejects_other_prefixes() -> void:
	assert_false(MatchId.is_valid(&""),         "празен")
	assert_false(MatchId.is_valid(&"yellow"),   "player_id не е match_id")
	assert_false(MatchId.is_valid(&"yellow_0"), "pawn_id не е match_id")
	assert_false(MatchId.is_valid(&"match_1"),  "match_ не е m_ префикс")
