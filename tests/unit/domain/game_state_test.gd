class_name GameStateTest
extends TestCase
## Unit тестове за GameState (Task #57 / #58 / #59 / #60 / docs/V1_ARCHITECTURE.md, §4.1).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без Vector2/NodePath.
##   - Полета: schema_version, match_id, match_config, board_id, phase,
##     players[], active_player_index, turn, dice, gifts[], ranking[],
##     rng_state, command_sequence.
##   - schema_version: константа, сериализация, миграция N→N+1, валидация (#58).
##   - command_sequence: next / record / stamp / restore / legal actions (#59).
##   - rng_state: capture / restore / normalize / create_random_source (#60).
##   - Фабрики create / create_from_match_config (YEL-001 start в база).
##   - Accessors: active player, get_player/pawn, gifts, ranking, legal actions.
##   - to_view() read-only snapshot за Presentation.
##   - is_valid() инварианти (§12: 2–4 играчи, nested модели).
##   - Сериализация to_dict / from_dict / equals / duplicate_state.
##   - JSON to_json / from_json: виж game_state_serialization_test.gd (#61).
##   - Стабилен state hash: виж game_state_hash_test.gd (#62).


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_game_state_extends_ref_counted() -> void:
	var state := GameState.new()
	assert_true(state is RefCounted,
			"GameState трябва да extends RefCounted, не Node")


func test_game_state_is_not_node() -> void:
	var state: Object = GameState.new()
	assert_false(state is Node,
			"GameState не трябва да extends Node — domain слой е без сцени")


func test_game_state_script_path_is_in_domain_model() -> void:
	var state := GameState.new()
	var path: String = state.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"GameState трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от GameState")
	assert_false(d.has("global_position"), "global_position не е част от GameState")
	assert_false(d.has("node_path"), "NodePath не е част от GameState")
	assert_false(d.has("texture"), "texture не е част от domain GameState")
	assert_false(d.has("sprite"), "sprite не е част от domain GameState")


# ── Константи и подразбирания ─────────────────────────────────────────────────

func test_player_bounds_and_active_none() -> void:
	assert_eq(GameState.MIN_PLAYERS, 2)
	assert_eq(GameState.MAX_PLAYERS, 4)
	assert_eq(GameState.ACTIVE_PLAYER_NONE, -1)


func test_default_fields_are_invalid() -> void:
	var state := GameState.new()
	assert_eq(state.schema_version, GameState.SCHEMA_VERSION)
	assert_eq(state.match_id, &"")
	assert_true(state.match_config == null)
	assert_eq(state.board_id, &"")
	assert_eq(state.phase, MatchPhase.SETUP)
	assert_eq(state.players.size(), 0)
	assert_eq(state.active_player_index, GameState.ACTIVE_PLAYER_NONE)
	assert_true(state.turn == null)
	assert_true(state.dice == null)
	assert_eq(state.gifts.size(), 0)
	assert_eq(state.ranking.size(), 0)
	assert_eq(state.rng_state.size(), 0)
	assert_eq(state.command_sequence, GameState.COMMAND_SEQUENCE_START)
	assert_false(state.is_valid(),
			"празен GameState → is_valid() == false")
	assert_eq(state.get_active_player_id(), &"")
	assert_eq(state.get_legal_actions().size(), 0)
	assert_eq(state.to_view().get("active_player_id"), "")
	assert_eq(state.to_dict().size(), 14)


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_from_match_config_builds_setup_with_base_pawns() -> void:
	MatchId._reset_counter_for_tests()
	var cfg := _two_player_config(7)
	var state := GameState.create_from_match_config(cfg)
	assert_true(MatchId.is_valid(state.match_id))
	assert_eq(state.board_id, Classic15x15Board.BOARD_ID)
	assert_true(state.is_setup())
	assert_eq(state.player_count(), 2)
	assert_eq(state.active_player_index, 0)
	assert_eq(state.get_active_player_id(), PlayerId.GREEN)
	assert_true(state.turn.is_match_start())
	assert_false(state.dice.has_result())
	assert_eq(state.gifts.size(), 0)
	assert_eq(state.ranking.size(), 0)
	assert_eq(state.command_sequence, GameState.COMMAND_SEQUENCE_START)
	assert_true(state.rng_state.has("seed"))
	assert_true(state.rng_state.has("state"))
	assert_eq(str(state.rng_state["seed"]), "7")
	for pid in [PlayerId.GREEN, PlayerId.YELLOW]:
		var player := state.get_player(pid)
		assert_true(player != null)
		assert_eq(player.count_pawns_in_zone(PawnZone.BASE), 4)
		assert_true(player.is_valid())
	assert_true(state.is_valid())
	assert_true(state.match_config.equals(cfg),
			"match_config трябва да е независимо копие със същите стойности")
	cfg.rng_seed = 99
	assert_eq(state.match_config.rng_seed, 7,
			"мутация на подадения config не трябва да пипа GameState")


func test_create_from_match_config_accepts_explicit_match_id() -> void:
	var cfg := _two_player_config()
	var state := GameState.create_from_match_config(cfg, &"m_fixed_1")
	assert_eq(state.match_id, &"m_fixed_1")
	assert_true(state.is_valid())


func test_create_from_match_config_two_three_four_players() -> void:
	MatchId._reset_counter_for_tests()
	var two := GameState.create_from_match_config(
			_config_with_seats(MatchConfig.DEFAULT_SEATS_2P, 1))
	var three := GameState.create_from_match_config(
			_config_with_seats(MatchConfig.DEFAULT_SEATS_3P, 1))
	var four := GameState.create_from_match_config(
			_config_with_seats(MatchConfig.DEFAULT_SEATS_4P, 1))
	assert_eq(two.player_count(), 2)
	assert_eq(three.player_count(), 3)
	assert_eq(four.player_count(), 4)
	assert_true(two.is_valid())
	assert_true(three.is_valid())
	assert_true(four.is_valid())


func test_create_sets_all_fields() -> void:
	MatchId._reset_counter_for_tests()
	var cfg := _two_player_config(3)
	var players: Array = [
		PlayerState.create_from_seat_config(
				cfg.seats[0], Classic15x15Board.base_cells_for(PlayerId.GREEN)),
		PlayerState.create_from_seat_config(
				cfg.seats[1], Classic15x15Board.base_cells_for(PlayerId.YELLOW)),
	]
	var turn := TurnState.create_for_player_turn(1, true)
	var dice := DiceState.create_roll(PlayerId.GREEN, 6)
	var gift := GiftState.create(&"g_1_0", &"c_6_8")
	var rng := SeededRandomSource.new(3).get_state()
	var state := GameState.create(
			&"m_test_0",
			cfg,
			cfg.board_id,
			MatchPhase.IN_PROGRESS,
			players,
			0,
			turn,
			dice,
			[gift],
			[],
			rng,
			4)
	assert_eq(state.match_id, &"m_test_0")
	assert_true(state.is_in_progress())
	assert_eq(state.command_sequence, 4)
	assert_true(state.dice.is_six())
	assert_eq(state.gifts.size(), 1)
	assert_true(state.is_valid())


# ── Accessors / mutators ──────────────────────────────────────────────────────

func test_get_player_and_pawn_lookups() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.has_player(PlayerId.GREEN))
	assert_false(state.has_player(PlayerId.CYAN))
	assert_eq(state.index_of_player(PlayerId.YELLOW), 1)
	assert_eq(state.index_of_player(PlayerId.CYAN), GameState.ACTIVE_PLAYER_NONE)
	var pawn_id := PawnId.for_player(PlayerId.YELLOW, 2)
	var pawn := state.get_pawn(pawn_id)
	assert_true(pawn != null)
	assert_true(pawn.is_in_base())
	assert_true(state.get_pawn(&"missing_0") == null)


func test_set_active_player_and_phase() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.set_active_player(PlayerId.YELLOW))
	assert_eq(state.get_active_player_id(), PlayerId.YELLOW)
	assert_false(state.set_active_player(PlayerId.CYAN))
	state.set_phase(MatchPhase.IN_PROGRESS)
	assert_true(state.is_in_progress())
	state.set_phase(MatchPhase.FINISHED)
	assert_true(state.is_finished())
	assert_eq(state.phase_name(), &"FINISHED")


func test_gift_helpers() -> void:
	var state := _valid_two_player_setup()
	var gift := GiftState.create(&"g_9_0", &"c_7_6")
	state.add_gift(gift)
	assert_true(state.get_gift(&"g_9_0").equals(gift))
	assert_true(state.get_gift_at(&"c_7_6").equals(gift))
	assert_true(state.get_gift_at(&"c_0_0") == null)
	assert_true(state.remove_gift(&"g_9_0"))
	assert_false(state.remove_gift(&"g_9_0"))
	assert_eq(state.gifts.size(), 0)


func test_rank_player_appends_and_sets_player_rank() -> void:
	var state := _valid_two_player_setup()
	assert_eq(state.rank_player(PlayerId.YELLOW), 1)
	assert_eq(state.rank_player(PlayerId.GREEN), 2)
	assert_eq(state.rank_player(PlayerId.YELLOW), 0, "вече класиран")
	assert_eq(state.rank_player(PlayerId.CYAN), 0, "липсващ играч")
	assert_true(state.is_ranked(PlayerId.YELLOW))
	assert_eq(state.get_ranked_player_ids(),
			[PlayerId.YELLOW, PlayerId.GREEN] as Array[StringName])
	assert_eq(state.get_player(PlayerId.YELLOW).rank, 1)
	assert_eq(state.get_player(PlayerId.GREEN).rank, 2)


# ── to_view / get_legal_actions ───────────────────────────────────────────────

func test_to_view_is_presentation_safe_snapshot() -> void:
	var state := _valid_two_player_setup()
	state.turn.begin_player_turn(1, true)
	state.set_phase(MatchPhase.IN_PROGRESS)
	var view := state.to_view()
	assert_eq(view.get("match_id"), String(state.match_id))
	assert_eq(view.get("phase"), MatchPhase.IN_PROGRESS)
	assert_eq(view.get("phase_name"), "IN_PROGRESS")
	assert_eq(view.get("active_player_id"), "green")
	assert_true(view.has("players"))
	assert_true(view.has("turn"))
	assert_true(view.has("dice"))
	assert_true(view.has("gifts"))
	assert_true(view.has("ranking"))
	assert_true(view.has("valid_pawn_ids"))
	assert_false(view.has("rng_state"),
			"rng_state не трябва да изтича към presentation view")
	assert_false(view.has("command_sequence"),
			"command_sequence не е част от to_view()")
	assert_false(view.has("match_config"),
			"пълният MatchConfig не е нужен в to_view()")


func test_get_legal_actions_roll_dice() -> void:
	var state := _valid_two_player_setup()
	state.turn.begin_player_turn(1, true)
	var actions := state.get_legal_actions()
	assert_eq(actions.size(), 1)
	assert_true(actions[0] is RollDiceCommand)
	var roll := actions[0] as RollDiceCommand
	assert_eq(roll.player_id, PlayerId.GREEN)
	assert_eq(roll.match_id, state.match_id)
	assert_eq(roll.sequence, state.next_command_sequence(),
			"legal action трябва да носи следващия очакван sequence")


func test_get_legal_actions_move_pawns() -> void:
	var state := _valid_two_player_setup()
	var pawn_a := PawnId.for_player(PlayerId.GREEN, 0)
	var pawn_b := PawnId.for_player(PlayerId.GREEN, 1)
	state.turn.enter_awaiting_move(6, [pawn_a, pawn_b])
	var actions := state.get_legal_actions()
	assert_eq(actions.size(), 2)
	assert_true(actions[0] is MovePawnCommand)
	assert_true(actions[1] is MovePawnCommand)
	assert_eq((actions[0] as MovePawnCommand).pawn_id, pawn_a)
	assert_eq((actions[1] as MovePawnCommand).pawn_id, pawn_b)
	assert_eq((actions[0] as MovePawnCommand).player_id, PlayerId.GREEN)


func test_get_legal_actions_empty_when_no_active_or_not_awaiting() -> void:
	var state := _valid_two_player_setup()
	assert_eq(state.get_legal_actions().size(), 0,
			"MATCH_START без valid commands → празен списък")
	state.active_player_index = GameState.ACTIVE_PLAYER_NONE
	state.turn.begin_player_turn(1, true)
	assert_eq(state.get_legal_actions().size(), 0,
			"без активен играч → празен списък")


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_is_valid_rejects_bad_match_id() -> void:
	var state := _valid_two_player_setup()
	state.match_id = &"not_a_match"
	assert_false(state.is_valid())


func test_is_valid_rejects_board_id_mismatch() -> void:
	var state := _valid_two_player_setup()
	state.board_id = &"other_board"
	assert_false(state.is_valid())


func test_is_valid_rejects_player_order_mismatch() -> void:
	var state := _valid_two_player_setup()
	var tmp = state.players[0]
	state.players[0] = state.players[1]
	state.players[1] = tmp
	assert_false(state.is_valid(),
			"редът на players[] трябва да следва MatchConfig seats")


func test_is_valid_rejects_duplicate_gift_cell() -> void:
	var state := _valid_two_player_setup()
	state.add_gift(GiftState.create(&"g_1_0", &"c_6_8"))
	state.add_gift(GiftState.create(&"g_1_1", &"c_6_8"))
	assert_false(state.is_valid())


func test_is_valid_rejects_ranking_unknown_player() -> void:
	var state := _valid_two_player_setup()
	state.ranking = [PlayerId.CYAN]
	assert_false(state.is_valid())


func test_is_valid_rejects_bad_active_index() -> void:
	var state := _valid_two_player_setup()
	state.active_player_index = 9
	assert_false(state.is_valid())


func test_is_valid_rejects_invalid_rng_state_keys() -> void:
	var state := _valid_two_player_setup()
	state.rng_state = {"seed": "1"}
	assert_false(state.is_valid())
	state.rng_state = {"seed": "1", "state": "2"}
	assert_true(state.is_valid())


func test_is_valid_allows_active_player_none() -> void:
	var state := _valid_two_player_setup()
	state.active_player_index = GameState.ACTIVE_PLAYER_NONE
	assert_true(state.is_valid())


# ── schema_version (docs/V1_ARCHITECTURE.md, §4.1 и §9 / Task #58) ────────────

func test_schema_version_constant() -> void:
	assert_eq(GameState.SCHEMA_VERSION, 1, "SCHEMA_VERSION трябва да е 1")


func test_default_schema_version_matches_constant() -> void:
	var state := GameState.new()
	assert_eq(state.schema_version, GameState.SCHEMA_VERSION,
			"schema_version трябва да съответства на константата")


func test_is_schema_supported_accepts_current_version() -> void:
	assert_true(GameState.is_schema_supported(GameState.SCHEMA_VERSION),
			"текущата SCHEMA_VERSION трябва да е поддържана")


func test_is_schema_supported_rejects_zero() -> void:
	assert_false(GameState.is_schema_supported(0),
			"schema_version 0 (pre-versioned) не е поддържан без миграция")


func test_is_schema_supported_rejects_future_version() -> void:
	assert_false(GameState.is_schema_supported(GameState.SCHEMA_VERSION + 1),
			"бъдещ schema_version не трябва да е поддържан")


func test_is_schema_supported_rejects_negative() -> void:
	assert_false(GameState.is_schema_supported(-1),
			"отрицателен schema_version не трябва да е поддържан")


func test_to_dict_writes_schema_version() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	assert_eq(d.get("schema_version"), GameState.SCHEMA_VERSION,
			"to_dict трябва да записва текущия SCHEMA_VERSION")


func test_schema_version_round_trip() -> void:
	var state := _valid_two_player_setup()
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.schema_version, GameState.SCHEMA_VERSION,
			"round-trip трябва да запази schema_version")
	assert_true(state.equals(restored))


func test_from_dict_missing_schema_version_migrates_to_current() -> void:
	var original := _valid_two_player_setup()
	var data := original.to_dict()
	data.erase("schema_version")
	var restored := GameState.from_dict(data)
	assert_eq(restored.schema_version, GameState.SCHEMA_VERSION,
			"липсващ schema_version трябва да се мигрира до SCHEMA_VERSION")
	assert_true(restored.is_valid(), "мигрираният GameState трябва да е валиден")
	assert_eq(restored.match_id, original.match_id)
	assert_eq(restored.player_count(), original.player_count())


func test_from_dict_schema_version_zero_migrates_to_current() -> void:
	var original := _valid_two_player_setup()
	var data := original.to_dict()
	data["schema_version"] = 0
	var restored := GameState.from_dict(data)
	assert_eq(restored.schema_version, GameState.SCHEMA_VERSION,
			"schema_version 0 трябва да се мигрира до SCHEMA_VERSION")
	assert_true(restored.is_valid())
	assert_true(original.equals(restored),
			"v0→v1 миграцията е identity за текущите имена на полетата")


func test_migrate_dict_sets_schema_version_to_current() -> void:
	var raw := {"match_id": "m_migrate_0", "phase": MatchPhase.SETUP}
	var migrated := GameState.migrate_dict(raw)
	assert_eq(migrated.get("schema_version"), GameState.SCHEMA_VERSION,
			"migrate_dict трябва да запише SCHEMA_VERSION")
	assert_false(raw.has("schema_version"),
			"migrate_dict не трябва да мутира оригиналния dictionary")
	assert_eq(migrated.get("match_id"), "m_migrate_0")


func test_migrate_dict_leaves_future_version_unchanged() -> void:
	var future := GameState.SCHEMA_VERSION + 5
	var raw := {"schema_version": future, "match_id": "m_future_0"}
	var migrated := GameState.migrate_dict(raw)
	assert_eq(migrated.get("schema_version"), future,
			"бъдещ schema_version не трябва да се даунгрейдва")


func test_from_dict_future_schema_version_is_preserved_but_invalid() -> void:
	var future := GameState.SCHEMA_VERSION + 1
	var original := _valid_two_player_setup()
	var data := original.to_dict()
	data["schema_version"] = future
	var restored := GameState.from_dict(data)
	assert_eq(restored.schema_version, future,
			"бъдещ schema_version трябва да се запази за откриване")
	assert_false(restored.is_valid(),
			"GameState с бъдещ schema_version трябва да е невалиден")


func test_invalid_when_schema_version_tampered() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.is_valid(), "precondition: валиден GameState")
	state.schema_version = 0
	assert_false(state.is_valid(),
			"schema_version извън поддържаните трябва да прави state невалиден")
	state.schema_version = GameState.SCHEMA_VERSION + 1
	assert_false(state.is_valid(),
			"бъдещ schema_version трябва да прави state невалиден")


func test_create_from_match_config_uses_current_schema_version() -> void:
	var state := GameState.create_from_match_config(_two_player_config())
	assert_eq(state.schema_version, GameState.SCHEMA_VERSION)
	assert_eq(state.to_dict().get("schema_version"), GameState.SCHEMA_VERSION)


# ── command_sequence (docs/V1_ARCHITECTURE.md, §4.1 и §11 / Task #59) ─────────

func test_command_sequence_start_constant() -> void:
	assert_eq(GameState.COMMAND_SEQUENCE_START, 0,
			"мачът започва с 0 приети команди")


func test_command_sequence_starts_at_zero_on_create() -> void:
	var state := _valid_two_player_setup()
	assert_eq(state.command_sequence, GameState.COMMAND_SEQUENCE_START)
	assert_eq(state.next_command_sequence(), 1,
			"първата команда трябва да носи sequence 1")


func test_next_command_sequence_is_current_plus_one() -> void:
	var state := _valid_two_player_setup()
	state.command_sequence = 4
	assert_eq(state.next_command_sequence(), 5)
	assert_true(state.is_expected_command_sequence(5))
	assert_false(state.is_expected_command_sequence(4),
			"текущият sequence вече е приложен")
	assert_false(state.is_expected_command_sequence(6),
			"пропуск в sequence не е позволен")


func test_record_accepted_command_advances_monotonically() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.record_accepted_command(1))
	assert_eq(state.command_sequence, 1)
	assert_true(state.record_accepted_command(2))
	assert_true(state.record_accepted_command(3))
	assert_eq(state.command_sequence, 3)
	assert_eq(state.next_command_sequence(), 4)


func test_record_accepted_command_rejects_out_of_order() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.record_accepted_command(1))
	assert_false(state.record_accepted_command(3),
			"пропуск (1→3) не трябва да променя state")
	assert_eq(state.command_sequence, 1,
			"отхвърлен sequence не пипа command_sequence (§12)")
	assert_false(state.record_accepted_command(1),
			"дубликат на вече приет sequence се отхвърля")
	assert_eq(state.command_sequence, 1)
	assert_false(state.record_accepted_command(0))
	assert_false(state.record_accepted_command(-1))


func test_advance_command_sequence() -> void:
	var state := _valid_two_player_setup()
	assert_eq(state.command_sequence, GameState.COMMAND_SEQUENCE_START)
	assert_eq(state.advance_command_sequence(), 1)
	assert_eq(state.advance_command_sequence(), 2)
	assert_eq(state.command_sequence, 2)
	assert_true(state.is_expected_command_sequence(3))


func test_set_command_sequence_for_snapshot_restore() -> void:
	var state := _valid_two_player_setup()
	state.set_command_sequence(12)
	assert_eq(state.command_sequence, 12)
	assert_eq(state.next_command_sequence(), 13)
	state.set_command_sequence(-5)
	assert_eq(state.command_sequence, GameState.COMMAND_SEQUENCE_START,
			"отрицателен restore се клампва до START")


func test_stamp_command_sets_match_id_and_next_sequence() -> void:
	var state := _valid_two_player_setup()
	state.record_accepted_command(1)
	state.record_accepted_command(2)
	var cmd := RollDiceCommand.new(PlayerId.GREEN)
	cmd.match_id = &"stale"
	cmd.sequence = 99
	var stamped := state.stamp_command(cmd)
	assert_true(stamped == cmd, "stamp_command връща същата инстанция")
	assert_eq(cmd.match_id, state.match_id)
	assert_eq(cmd.sequence, 3)
	assert_eq(state.command_sequence, 2,
			"stamp не трябва да инкрементира — само record след accept")


func test_stamp_command_null_is_safe() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.stamp_command(null) == null)


func test_is_valid_rejects_negative_command_sequence() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.is_valid())
	state.command_sequence = -1
	assert_false(state.is_valid(),
			"отрицателен command_sequence прави GameState невалиден")


func test_command_sequence_round_trip_and_equals() -> void:
	var original := _valid_two_player_setup()
	assert_true(original.record_accepted_command(1))
	assert_true(original.record_accepted_command(2))
	var restored := GameState.from_dict(original.to_dict())
	assert_eq(restored.command_sequence, 2)
	assert_true(original.equals(restored))
	assert_eq(restored.to_dict().get("command_sequence"), 2)
	restored.command_sequence = 3
	assert_false(original.equals(restored),
			"equals трябва да включва command_sequence")


func test_command_sequence_missing_in_dict_defaults_to_start() -> void:
	var data := _valid_two_player_setup().to_dict()
	data.erase("command_sequence")
	var restored := GameState.from_dict(data)
	assert_eq(restored.command_sequence, GameState.COMMAND_SEQUENCE_START)


func test_get_legal_actions_stamp_next_sequence_after_advances() -> void:
	var state := _valid_two_player_setup()
	state.record_accepted_command(1)
	state.turn.begin_player_turn(1, true)
	var actions := state.get_legal_actions()
	assert_eq(actions.size(), 1)
	assert_eq((actions[0] as RollDiceCommand).sequence, 2)
	assert_eq((actions[0] as RollDiceCommand).match_id, state.match_id)


func test_to_view_excludes_command_sequence() -> void:
	var state := _valid_two_player_setup()
	state.record_accepted_command(1)
	var view := state.to_view()
	assert_false(view.has("command_sequence"),
			"command_sequence е engine/snapshot поле, не presentation view")


# ── rng_state sync / restore (docs/V1_ARCHITECTURE.md §4.1 / §4.5 / §12 / #60) ─

func test_rng_state_key_constants() -> void:
	assert_eq(GameState.RNG_STATE_KEY_SEED, "seed")
	assert_eq(GameState.RNG_STATE_KEY_STATE, "state")


func test_create_from_match_config_has_json_safe_rng_state() -> void:
	var state := GameState.create_from_match_config(_two_player_config(7))
	assert_true(state.has_rng_state())
	assert_eq(typeof(state.rng_state[GameState.RNG_STATE_KEY_SEED]), TYPE_STRING)
	assert_eq(typeof(state.rng_state[GameState.RNG_STATE_KEY_STATE]), TYPE_STRING)
	assert_eq(state.rng_state.size(), 2,
			"нормализираният payload е точно {seed, state}")
	assert_eq(state.get_rng_seed(), 7)
	assert_true(state.is_valid())


func test_set_rng_state_copies_and_normalizes_to_strings() -> void:
	var state := _valid_two_player_setup()
	var payload := {"seed": 11, "state": 22, "extra": true}
	state.set_rng_state(payload)
	payload["seed"] = 99
	assert_eq(state.rng_state[GameState.RNG_STATE_KEY_SEED], "11")
	assert_eq(state.rng_state[GameState.RNG_STATE_KEY_STATE], "22")
	assert_false(state.rng_state.has("extra"),
			"излишни ключове се отрязват при normalize")
	assert_eq(str(payload["seed"]), "99",
			"мутация на подадения dict не пипа GameState")


func test_set_rng_state_incomplete_kept_invalid() -> void:
	var state := _valid_two_player_setup()
	assert_true(state.has_rng_state())
	state.set_rng_state({"seed": "1"})
	assert_true(state.has_rng_state(),
			"непълен payload се запазва за откриване")
	assert_false(state.is_valid(),
			"непълен rng_state прави GameState невалиден")
	assert_false(state.restore_rng(SeededRandomSource.new(0)),
			"restore от непълен snapshot не пипа живия RNG")


func test_clear_rng_state() -> void:
	var state := _valid_two_player_setup()
	state.clear_rng_state()
	assert_false(state.has_rng_state())
	assert_eq(state.rng_state.size(), 0)
	assert_true(state.is_valid(), "празен rng_state е валиден")


func test_capture_rng_syncs_from_live_source() -> void:
	var state := _valid_two_player_setup()
	var rng := SeededRandomSource.new(55)
	for _i in 5:
		rng.next_int(1, 6)
	assert_true(state.capture_rng(rng))
	assert_true(state.has_rng_state())
	assert_true(state.rng_matches(rng))
	assert_eq(state.get_rng_seed(), 55)
	assert_eq(state.rng_state[GameState.RNG_STATE_KEY_SEED], "55")


func test_capture_rng_null_rejected_without_mutation() -> void:
	var state := _valid_two_player_setup()
	var before_seed: String = str(state.rng_state[GameState.RNG_STATE_KEY_SEED])
	var before_inner: String = str(state.rng_state[GameState.RNG_STATE_KEY_STATE])
	assert_false(state.capture_rng(null))
	assert_eq(str(state.rng_state[GameState.RNG_STATE_KEY_SEED]), before_seed,
			"null capture не трябва да пипа rng_state (§12)")
	assert_eq(str(state.rng_state[GameState.RNG_STATE_KEY_STATE]), before_inner,
			"null capture не трябва да пипа rng_state (§12)")


func test_capture_rng_empty_export_clears() -> void:
	var state := _valid_two_player_setup()
	var fixed := RandomSource.new()
	assert_true(state.capture_rng(fixed),
			"базов RandomSource (празен export) е позволен")
	assert_false(state.has_rng_state())


func test_restore_rng_continues_stream() -> void:
	var state := _valid_two_player_setup()
	var original := SeededRandomSource.new(777)
	for _i in 8:
		original.next_int(1, 6)
	assert_true(state.capture_rng(original))

	var expected: Array = []
	for _i in 15:
		expected.append(original.next_int(1, 6))

	var restored := SeededRandomSource.new(0)
	assert_true(state.restore_rng(restored))
	var actual: Array = []
	for _i in 15:
		actual.append(restored.next_int(1, 6))
	assert_eq(actual, expected,
			"restore_rng трябва да продължи next_int потока от GameState")


func test_restore_rng_rejects_null_and_empty() -> void:
	var state := _valid_two_player_setup()
	assert_false(state.restore_rng(null))
	var rng := SeededRandomSource.new(1)
	var before := rng.get_state()
	state.clear_rng_state()
	assert_false(state.restore_rng(rng),
			"празен rng_state не трябва да пипа живия RNG")
	assert_eq(rng.get_state(), before)


func test_rng_matches_detects_divergence() -> void:
	var state := _valid_two_player_setup()
	var a := SeededRandomSource.new(42)
	var b := SeededRandomSource.new(42)
	assert_true(state.capture_rng(a))
	assert_true(state.rng_matches(b), "еднакъв seed → match преди draws")
	a.next_int(1, 6)
	assert_true(state.capture_rng(a))
	assert_false(state.rng_matches(b), "след draw без sync → divergence")
	assert_true(state.restore_rng(b))
	assert_true(state.rng_matches(b))


func test_create_random_source_from_state_replays_stream() -> void:
	var state := _valid_two_player_setup()
	var source := SeededRandomSource.new(314)
	for _i in 6:
		source.next_int(1, 6)
	state.capture_rng(source)

	var expected: Array = []
	for _i in 12:
		expected.append(source.next_int(1, 6))

	var from_state := state.create_random_source_from_state()
	var actual: Array = []
	for _i in 12:
		actual.append(from_state.next_int(1, 6))
	assert_eq(actual, expected)


func test_create_random_source_from_state_falls_back_to_match_config_seed() -> void:
	var state := _valid_two_player_setup()
	state.clear_rng_state()
	var from_state := state.create_random_source_from_state()
	var from_config := SeededRandomSource.new(state.match_config.rng_seed)
	assert_eq(from_state.next_int(1, 6), from_config.next_int(1, 6))
	assert_eq(from_state.next_int(1, 6), from_config.next_int(1, 6))


func test_get_rng_seed_falls_back_to_match_config() -> void:
	var state := _valid_two_player_setup()
	assert_eq(state.get_rng_seed(), 42)
	state.clear_rng_state()
	assert_eq(state.get_rng_seed(), 42,
			"без snapshot → match_config.rng_seed")


func test_capture_then_restore_keeps_live_rng_unchanged_on_reject_path() -> void:
	# Инвариант §12: без capture след „отхвърлена“ команда живият RNG и
	# GameState.rng_state остават както преди командата.
	var state := _valid_two_player_setup()
	var rng := SeededRandomSource.new(9)
	for _i in 4:
		rng.next_int(1, 6)
	assert_true(state.capture_rng(rng))
	var snapshot_before := state.rng_state.duplicate(true)
	var live_before := rng.get_state()
	# Симулираме отхвърлена команда: без capture_rng / без next_int.
	assert_eq(state.rng_state[GameState.RNG_STATE_KEY_STATE],
			snapshot_before[GameState.RNG_STATE_KEY_STATE])
	assert_eq(rng.get_state()[GameState.RNG_STATE_KEY_STATE],
			live_before[GameState.RNG_STATE_KEY_STATE])
	assert_true(state.rng_matches(rng))


func test_rng_state_round_trip_preserves_stream() -> void:
	var original := _valid_two_player_setup()
	var rng := SeededRandomSource.new(4242)
	for _i in 10:
		rng.next_int(1, 6)
	original.capture_rng(rng)

	var expected: Array = []
	for _i in 10:
		expected.append(rng.next_int(1, 6))

	var restored_state := GameState.from_dict(original.to_dict())
	assert_true(original.equals(restored_state))
	assert_eq(typeof(restored_state.rng_state[GameState.RNG_STATE_KEY_STATE]),
			TYPE_STRING)
	var replay := restored_state.create_random_source_from_state()
	var actual: Array = []
	for _i in 10:
		actual.append(replay.next_int(1, 6))
	assert_eq(actual, expected,
			"to_dict → from_dict трябва да запази RNG потока")


func test_rng_state_json_round_trip_preserves_64bit() -> void:
	var state := _valid_two_player_setup()
	var rng := SeededRandomSource.new(424242)
	for _i in 8:
		rng.next_int(1, 6)
	state.capture_rng(rng)
	var state_int: int = str(state.rng_state[GameState.RNG_STATE_KEY_STATE]).to_int()
	assert_true(absi(state_int) > 9007199254740992,
			"fixture state трябва да е > 2^53")

	var expected: Array = []
	for _i in 12:
		expected.append(rng.next_int(1, 6))

	var json_text := JSON.stringify(state.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary)
	var restored := GameState.from_dict(parsed as Dictionary)
	var replay := restored.create_random_source_from_state()
	var actual: Array = []
	for _i in 12:
		actual.append(replay.next_int(1, 6))
	assert_eq(actual, expected,
			"JSON stringify на GameState трябва да пази 64-bit rng_state")


func test_to_view_excludes_rng_state() -> void:
	var state := _valid_two_player_setup()
	var view := state.to_view()
	assert_false(view.has("rng_state"),
			"rng_state е engine/snapshot поле, не presentation view")


func test_equals_includes_rng_state() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	assert_true(a.equals(b))
	var rng := SeededRandomSource.new(1)
	rng.next_int(1, 6)
	b.capture_rng(rng)
	assert_false(a.equals(b), "equals трябва да включва rng_state")


func test_duplicate_state_rng_is_independent() -> void:
	var original := _valid_two_player_setup()
	var copy := original.duplicate_state()
	var rng := SeededRandomSource.new(99)
	for _i in 3:
		rng.next_int(1, 6)
	copy.capture_rng(rng)
	assert_false(original.rng_matches(rng),
			"capture върху копие не трябва да пипа оригинала")
	assert_true(original.has_rng_state())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_contains_all_schema_keys() -> void:
	var state := _valid_two_player_setup()
	var d := state.to_dict()
	for key in [
		"schema_version", "match_id", "match_config", "board_id", "phase",
		"players", "active_player_index", "turn", "dice", "gifts", "ranking",
		"rng_state", "command_sequence",
	]:
		assert_true(d.has(key), "липсва ключ %s" % key)
	assert_eq(d["schema_version"], GameState.SCHEMA_VERSION)
	assert_true(d["match_id"] is String)
	assert_true(d["board_id"] is String)
	assert_true(d["match_config"] is Dictionary)
	assert_true(d["players"] is Array)
	assert_eq((d["players"] as Array).size(), 2)


func test_from_dict_round_trip() -> void:
	var original := _valid_two_player_setup()
	original.set_phase(MatchPhase.IN_PROGRESS)
	original.turn.begin_player_turn(2, false)
	original.dice.set_roll(PlayerId.GREEN, 4)
	original.add_gift(GiftState.create(&"g_2_0", &"c_8_6"))
	original.rank_player(PlayerId.GREEN)
	original.command_sequence = 5
	var restored := GameState.from_dict(original.to_dict())
	assert_true(original.equals(restored))
	assert_true(restored.is_valid())
	assert_eq(restored.get_active_player_id(), PlayerId.GREEN)
	assert_eq(restored.gifts.size(), 1)
	assert_eq(restored.ranking.size(), 1)


func test_from_dict_missing_fields_use_defaults() -> void:
	var state := GameState.from_dict({})
	assert_eq(state.schema_version, GameState.SCHEMA_VERSION)
	assert_eq(state.match_id, &"")
	assert_true(state.match_config == null)
	assert_eq(state.board_id, &"")
	assert_eq(state.phase, MatchPhase.SETUP)
	assert_eq(state.players.size(), 0)
	assert_eq(state.active_player_index, GameState.ACTIVE_PLAYER_NONE)
	assert_true(state.turn != null)
	assert_true(state.dice != null)
	assert_eq(state.gifts.size(), 0)
	assert_eq(state.ranking.size(), 0)
	assert_eq(state.command_sequence, GameState.COMMAND_SEQUENCE_START)


func test_duplicate_state_is_independent_deep_copy() -> void:
	var original := _valid_two_player_setup()
	original.add_gift(GiftState.create(&"g_3_0", &"c_6_8"))
	var copy := original.duplicate_state()
	assert_true(original.equals(copy))
	copy.command_sequence = 10
	(copy.players[0] as PlayerState).rank = 1
	copy.gifts.clear()
	copy.turn.begin_player_turn(1, true)
	assert_false(original.equals(copy))
	assert_eq(original.command_sequence, GameState.COMMAND_SEQUENCE_START)
	assert_eq(original.get_player(PlayerId.GREEN).rank, PlayerState.RANK_UNRANKED)
	assert_eq(original.gifts.size(), 1)
	assert_true(original.turn.is_match_start())


func test_equals_null_is_false() -> void:
	var state := _valid_two_player_setup()
	assert_false(state.equals(null))


func test_equals_detects_field_differences() -> void:
	var a := _valid_two_player_setup()
	var b := a.duplicate_state()
	assert_true(a.equals(b))
	b.command_sequence = 1
	assert_false(a.equals(b))


# ── Helpers ───────────────────────────────────────────────────────────────────

func _two_player_config(rng_seed: int = 42) -> MatchConfig:
	return _config_with_seats(MatchConfig.DEFAULT_SEATS_2P, rng_seed)


func _config_with_seats(seats: Array, rng_seed: int = 42) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(seats)
	# Първият seat — HUMAN; останалите AI (валиден free-play договор).
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		if i == 0:
			seat.configure(MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
		else:
			seat.configure(
					MatchConfig.ControllerType.AI, AnimalId.DOG, AIDifficulty.EASY)
	assert_true(cfg.is_valid(), "helper MatchConfig трябва да е валиден")
	return cfg


func _valid_two_player_setup() -> GameState:
	MatchId._reset_counter_for_tests()
	var state := GameState.create_from_match_config(_two_player_config())
	assert_true(state.is_valid(), "helper GameState трябва да е валиден")
	return state
