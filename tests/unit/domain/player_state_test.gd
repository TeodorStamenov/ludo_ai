class_name PlayerStateTest
extends TestCase
## Unit тестове за PlayerState (Task #52 / docs/V1_ARCHITECTURE.md, §4.1).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath.
##   - Полета: player_id, seat, color, controller_type, animal_id, pawns[], rank,
##     status_effects[].
##   - Фабрики create / create_with_base_pawns / create_from_seat_config.
##   - Controller / rank / pawn / status-effect helpers.
##   - is_valid() инварианти (§12: 4 пионки на играч).
##   - Сериализация to_dict / from_dict / equals / duplicate_state.


const _YELLOW_BASE: Array[StringName] = [
	&"c_11_11", &"c_12_11", &"c_11_12", &"c_12_12",
]


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_player_state_extends_ref_counted() -> void:
	var player := PlayerState.new()
	assert_true(player is RefCounted,
			"PlayerState трябва да extends RefCounted, не Node")


func test_player_state_is_not_node() -> void:
	var player: Object = PlayerState.new()
	assert_false(player is Node,
			"PlayerState не трябва да extends Node — domain слой е без сцени")


func test_player_state_script_path_is_in_domain_model() -> void:
	var player := PlayerState.new()
	var path: String = player.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"PlayerState трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	var d := player.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от PlayerState")
	assert_false(d.has("global_position"), "global_position не е част от PlayerState")
	assert_false(d.has("node_path"), "NodePath не е част от PlayerState")
	assert_false(d.has("texture"), "texture не е част от domain PlayerState")
	assert_false(d.has("ai_difficulty"),
			"ai_difficulty живее в MatchConfig.SeatConfig, не в PlayerState")


# ── Стойности по подразбиране ─────────────────────────────────────────────────

func test_default_fields() -> void:
	var player := PlayerState.new()
	assert_eq(player.player_id, &"")
	assert_eq(player.seat, -1)
	assert_eq(player.color, &"")
	assert_eq(player.controller_type, MatchConfig.ControllerType.HUMAN)
	assert_eq(player.animal_id, AnimalId.DEFAULT)
	assert_eq(player.pawns.size(), 0)
	assert_eq(player.rank, PlayerState.RANK_UNRANKED)
	assert_eq(player.status_effects.size(), 0)
	assert_false(player.is_valid(),
			"празен player_id / без pawns → is_valid() == false")


func test_pawns_per_player_matches_pawn_id() -> void:
	assert_eq(PlayerState.PAWNS_PER_PLAYER, PawnId.PAWNS_PER_PLAYER)
	assert_eq(PlayerState.PAWNS_PER_PLAYER, 4)


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_all_fields() -> void:
	var pawns: Array = [
		PawnState.create_in_base(&"green_0", &"c_2_2"),
		PawnState.create_in_base(&"green_1", &"c_3_2"),
		PawnState.create_in_base(&"green_2", &"c_2_3"),
		PawnState.create_in_base(&"green_3", &"c_3_3"),
	]
	var player := PlayerState.create(
			PlayerId.GREEN, 0, PlayerId.GREEN,
			MatchConfig.ControllerType.AI, AnimalId.RABBIT,
			pawns, 2, [{"id": "slow", "turns_remaining": 1}])
	assert_eq(player.player_id, PlayerId.GREEN)
	assert_eq(player.seat, 0)
	assert_eq(player.color, PlayerId.GREEN)
	assert_true(player.is_ai())
	assert_eq(player.animal_id, AnimalId.RABBIT)
	assert_eq(player.pawns.size(), 4)
	assert_eq(player.rank, 2)
	assert_true(player.has_status_effect(&"slow"))
	assert_true(player.is_valid())


func test_create_with_base_pawns_matches_yel_001_start() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, Classic15x15Board.base_cells_for(PlayerId.YELLOW))
	assert_eq(player.player_id, PlayerId.YELLOW)
	assert_eq(player.seat, PlayerId.to_seat(PlayerId.YELLOW))
	assert_eq(player.color, PlayerId.YELLOW)
	assert_eq(player.rank, PlayerState.RANK_UNRANKED)
	assert_eq(player.pawns.size(), PlayerState.PAWNS_PER_PLAYER)
	for i in PlayerState.PAWNS_PER_PLAYER:
		var pawn := player.get_pawn_by_index(i)
		assert_true(pawn != null)
		assert_true(pawn.is_in_base())
		assert_eq(pawn.pawn_id, PawnId.for_player(PlayerId.YELLOW, i))
		assert_eq(pawn.path_index, PawnState.PATH_INDEX_IN_BASE)
	assert_true(player.is_valid())


func test_create_with_base_pawns_custom_color() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.CYAN, MatchConfig.ControllerType.HUMAN,
			AnimalId.DOG, Classic15x15Board.base_cells_for(PlayerId.CYAN),
			&"team_blue")
	assert_eq(player.color, &"team_blue")
	assert_eq(player.player_id, PlayerId.CYAN)
	assert_true(player.is_valid())


func test_create_from_seat_config() -> void:
	var seat := MatchConfig.SeatConfig.create(
			PlayerId.ORANGE, MatchConfig.ControllerType.AI,
			AnimalId.HEN, AIDifficulty.HARD)
	var player := PlayerState.create_from_seat_config(
			seat, Classic15x15Board.base_cells_for(PlayerId.ORANGE))
	assert_eq(player.player_id, PlayerId.ORANGE)
	assert_eq(player.seat, 1)
	assert_true(player.is_ai())
	assert_eq(player.animal_id, AnimalId.HEN)
	assert_eq(player.pawns.size(), 4)
	assert_true(player.is_valid())


# ── Controller / rank helpers ─────────────────────────────────────────────────

func test_controller_helpers_are_mutually_exclusive() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, Classic15x15Board.base_cells_for(PlayerId.GREEN))
	assert_true(player.is_human())
	assert_false(player.is_ai())
	assert_false(player.is_remote())

	player.controller_type = MatchConfig.ControllerType.AI
	assert_true(player.is_ai())
	assert_false(player.is_human())

	player.controller_type = MatchConfig.ControllerType.REMOTE
	assert_true(player.is_remote())
	assert_false(player.is_ai())


func test_rank_helpers() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, Classic15x15Board.base_cells_for(PlayerId.GREEN))
	assert_false(player.is_ranked())
	player.set_rank(1)
	assert_true(player.is_ranked())
	assert_eq(player.rank, 1)
	player.clear_rank()
	assert_false(player.is_ranked())
	assert_eq(player.rank, PlayerState.RANK_UNRANKED)


# ── Pawn helpers ──────────────────────────────────────────────────────────────

func test_get_pawn_and_get_pawn_by_index() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	var by_id := player.get_pawn(&"yellow_2")
	assert_true(by_id != null)
	assert_eq(by_id.get_pawn_index(), 2)
	assert_eq(player.get_pawn_by_index(2).pawn_id, &"yellow_2")
	assert_true(player.get_pawn(&"green_0") == null)
	assert_true(player.get_pawn_by_index(-1) == null)
	assert_true(player.get_pawn_by_index(4) == null)


func test_count_finished_and_zone_helpers() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	assert_eq(player.count_pawns_in_zone(PawnZone.BASE), 4)
	assert_eq(player.count_finished_pawns(), 0)
	assert_false(player.has_finished_all_pawns())

	player.pawns[0] = PawnState.create_finished(&"yellow_0", 56, &"c_7_11")
	player.pawns[1] = PawnState.create_finished(&"yellow_1", 56, &"c_7_10")
	assert_eq(player.count_finished_pawns(), 2)
	assert_eq(player.count_pawns_in_zone(PawnZone.FINISHED), 2)
	assert_false(player.has_finished_all_pawns())

	player.pawns[2] = PawnState.create_finished(&"yellow_2", 56, &"c_7_9")
	player.pawns[3] = PawnState.create_finished(&"yellow_3", 56, &"c_7_8")
	assert_true(player.has_finished_all_pawns())
	assert_true(player.is_valid())


# ── Status effects ────────────────────────────────────────────────────────────

func test_apply_and_remove_status_effect() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, Classic15x15Board.base_cells_for(PlayerId.GREEN))
	player.apply_status_effect(&"freeze", 2)
	assert_true(player.has_status_effect(&"freeze"))
	assert_eq(player.status_effects.size(), 1)
	player.apply_status_effect(&"freeze", 1)
	assert_eq(player.status_effects.size(), 1,
			"същият id се обновява, не се дублира")
	assert_eq(int(player.status_effects[0]["turns_remaining"]), 1)
	assert_true(player.remove_status_effect(&"freeze"))
	assert_false(player.has_status_effect(&"freeze"))
	player.apply_status_effect(&"boost", 3)
	player.clear_status_effects()
	assert_eq(player.status_effects.size(), 0)


func test_apply_status_effect_clamps_negative_turns() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.GREEN, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, Classic15x15Board.base_cells_for(PlayerId.GREEN))
	player.apply_status_effect(&"x", -5)
	assert_eq(int(player.status_effects[0]["turns_remaining"]), 0)


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_rejects_invalid_player_id() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.player_id = &"purple"
	assert_false(player.is_valid())


func test_is_valid_rejects_seat_mismatch() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.seat = 0
	assert_false(player.is_valid(),
			"seat трябва да съвпада с PlayerId.to_seat(player_id)")


func test_is_valid_rejects_empty_color() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.color = &""
	assert_false(player.is_valid())


func test_is_valid_rejects_invalid_controller_type() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.controller_type = 99
	assert_false(player.is_valid())


func test_is_valid_rejects_invalid_animal_id() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.animal_id = &"dragon"
	assert_false(player.is_valid())


func test_is_valid_rejects_invalid_rank() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.rank = -1
	assert_false(player.is_valid())
	player.rank = 5
	assert_false(player.is_valid())
	player.rank = 4
	assert_true(player.is_valid())


func test_is_valid_rejects_wrong_pawn_count() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.pawns.pop_back()
	assert_false(player.is_valid(), "трябва да има точно 4 пионки (§12)")


func test_is_valid_rejects_pawn_from_other_player() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.pawns[0] = PawnState.create_in_base(&"green_0", &"c_2_2")
	assert_false(player.is_valid())


func test_is_valid_rejects_duplicate_pawn_index() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.pawns[1] = PawnState.create_in_base(&"yellow_0", &"c_12_11")
	assert_false(player.is_valid())


func test_is_valid_rejects_invalid_nested_pawn() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	(player.pawns[0] as PawnState).zone = 99
	assert_false(player.is_valid())


func test_is_valid_rejects_bad_status_effects() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	player.status_effects = ["not_a_dict"]
	assert_false(player.is_valid())
	player.status_effects = [{"id": "", "turns_remaining": 1}]
	assert_false(player.is_valid())
	player.status_effects = [{"id": "ok", "turns_remaining": -1}]
	assert_false(player.is_valid())


func test_is_valid_accepts_all_four_seats_at_match_start() -> void:
	for pid in PlayerId.ALL:
		var player := PlayerState.create_with_base_pawns(
				pid, MatchConfig.ControllerType.HUMAN,
				AnimalId.DEFAULT, Classic15x15Board.base_cells_for(pid))
		assert_true(player.is_valid(),
				"очаква се валиден PlayerState за seat %s" % pid)


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_contains_expected_keys_and_types() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.CYAN, MatchConfig.ControllerType.AI,
			AnimalId.COW, Classic15x15Board.base_cells_for(PlayerId.CYAN))
	player.set_rank(3)
	player.apply_status_effect(&"boost", 2)
	var d := player.to_dict()
	assert_eq(d["player_id"], "cyan")
	assert_eq(d["seat"], 3)
	assert_eq(d["color"], "cyan")
	assert_eq(d["controller_type"], MatchConfig.ControllerType.AI)
	assert_eq(d["animal_id"], "cow")
	assert_eq(d["rank"], 3)
	assert_true(d["player_id"] is String)
	assert_true(d["color"] is String)
	assert_true(d["animal_id"] is String)
	assert_true(d["pawns"] is Array)
	assert_eq((d["pawns"] as Array).size(), 4)
	assert_true(d["status_effects"] is Array)
	assert_eq((d["status_effects"] as Array).size(), 1)


func test_from_dict_round_trip() -> void:
	var original := PlayerState.create_with_base_pawns(
			PlayerId.ORANGE, MatchConfig.ControllerType.HUMAN,
			AnimalId.RABBIT, Classic15x15Board.base_cells_for(PlayerId.ORANGE))
	original.set_rank(1)
	original.apply_status_effect(&"slow", 2)
	(original.pawns[0] as PawnState).exit_base_to_spawn(
			Classic15x15Board.spawn_cell_for(PlayerId.ORANGE))
	var restored := PlayerState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_eq(restored.player_id, PlayerId.ORANGE)
	assert_true(restored.get_pawn_by_index(0).is_on_main_path())


func test_from_dict_missing_fields_use_defaults() -> void:
	var player := PlayerState.from_dict({})
	assert_eq(player.player_id, &"")
	assert_eq(player.seat, -1)
	assert_eq(player.color, &"")
	assert_eq(player.controller_type, MatchConfig.ControllerType.HUMAN)
	assert_eq(player.animal_id, AnimalId.DEFAULT)
	assert_eq(player.pawns.size(), 0)
	assert_eq(player.rank, PlayerState.RANK_UNRANKED)
	assert_eq(player.status_effects.size(), 0)


func test_duplicate_state_is_independent_deep_copy() -> void:
	var original := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	original.apply_status_effect(&"boost", 1)
	var copy := original.duplicate_state()
	assert_true(original.equals(copy))
	(copy.pawns[0] as PawnState).path_index = 5
	copy.status_effects[0]["turns_remaining"] = 9
	copy.rank = 2
	assert_false(original.equals(copy))
	assert_eq((original.pawns[0] as PawnState).path_index,
			PawnState.PATH_INDEX_IN_BASE)
	assert_eq(int(original.status_effects[0]["turns_remaining"]), 1)
	assert_eq(original.rank, PlayerState.RANK_UNRANKED)


func test_equals_null_is_false() -> void:
	var player := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	assert_false(player.equals(null))


func test_equals_detects_field_differences() -> void:
	var a := PlayerState.create_with_base_pawns(
			PlayerId.YELLOW, MatchConfig.ControllerType.HUMAN,
			AnimalId.PIG, _YELLOW_BASE)
	var b := a.duplicate_state()
	assert_true(a.equals(b))
	b.animal_id = AnimalId.DOG
	assert_false(a.equals(b))
