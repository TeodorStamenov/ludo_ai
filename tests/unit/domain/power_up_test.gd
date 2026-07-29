extends TestCase
## Unit тестове за power-up системата (#201-#218).
##
## Покрива:
##   - PowerUpResolver базов интерфейс / type-contract на четирите ефекта
##   - GiftRules: seeded spawn interval, свободни клетки, spawn_if_due
##   - TeleportEffect / ShieldEffect / ExtraTurnEffect / PushEffect: реално
##     поведение върху GameState (не само "resolve() връща Array")
##   - #212 конфликт resolution (MoveRules.resolve_power_up_destination_index)
##   - #213: push не действа върху пионки в home stretch/база
##   - GameEngine интеграция: MovePawnCommand, кацнала върху подарък, отключва
##     GiftCollected + ефектни събития + PowerUpResolved (#204/#206/#207)
##   - AnimalPassive дефолтни модификатори / ModifierPipeline инстанцируемост
##
## docs/V1_ARCHITECTURE.md, раздел 4.7, 4.8; V1_GAME_DESIGN.md, раздел 4.3


# --- PowerUpResolver базов интерфейс ---

func test_power_up_resolver_extends_ref_counted() -> void:
	var resolver := PowerUpResolver.new()
	assert_not_null(resolver)
	assert_true(resolver is RefCounted,
			"PowerUpResolver трябва да extends RefCounted, не Node")


func test_power_up_resolver_base_resolve_returns_array() -> void:
	var resolver := PowerUpResolver.new()
	var rng := SeededRandomSource.new(1)
	var state := GameState.new()
	var result := resolver.resolve(PowerUpContext.create(&"p1", &"p1_0", &""), state, rng)
	assert_true(result is Array,
			"PowerUpResolver.resolve() трябва да върне Array")
	assert_true(result.is_empty(),
			"Базовата имплементация трябва да върне празен масив")


func test_teleport_effect_extends_power_up_resolver() -> void:
	assert_true(TeleportEffect.new() is PowerUpResolver)


func test_shield_effect_extends_power_up_resolver() -> void:
	assert_true(ShieldEffect.new() is PowerUpResolver)


func test_extra_turn_effect_extends_power_up_resolver() -> void:
	assert_true(ExtraTurnEffect.new() is PowerUpResolver)


func test_push_effect_extends_power_up_resolver() -> void:
	assert_true(PushEffect.new() is PowerUpResolver)


func test_effects_are_not_nodes() -> void:
	assert_false((TeleportEffect.new() as Object) is Node)
	assert_false((ShieldEffect.new() as Object) is Node)
	assert_false((ExtraTurnEffect.new() as Object) is Node)
	assert_false((PushEffect.new() as Object) is Node)


# --- GiftRules: seeded spawn interval / свободни клетки / spawn_if_due (#201-203) ---

var _gift_rules: GiftRules


func before_each() -> void:
	_gift_rules = GiftRules.new()


func test_schedule_first_spawn_is_within_interval_bounds() -> void:
	var rng := SeededRandomSource.new(7)
	var threshold := _gift_rules.schedule_first_spawn(rng, 0)
	assert_true(threshold >= GiftRules.MIN_INTERVAL and threshold <= GiftRules.MAX_INTERVAL)


func test_schedule_first_spawn_offsets_from_given_sequence() -> void:
	var rng := SeededRandomSource.new(7)
	var threshold := _gift_rules.schedule_first_spawn(rng, 100)
	assert_true(
			threshold >= 100 + GiftRules.MIN_INTERVAL
			and threshold <= 100 + GiftRules.MAX_INTERVAL)


func test_is_spawn_due_false_before_threshold() -> void:
	var state := GameState.new()
	state.next_gift_spawn_at = 10
	state.command_sequence = 9
	assert_false(_gift_rules.is_spawn_due(state))


func test_is_spawn_due_true_at_and_after_threshold() -> void:
	var state := GameState.new()
	state.next_gift_spawn_at = 10
	state.command_sequence = 10
	assert_true(_gift_rules.is_spawn_due(state))
	state.command_sequence = 11
	assert_true(_gift_rules.is_spawn_due(state))


func test_free_spawn_cells_excludes_already_occupied_gift_cells() -> void:
	var state := _two_player_in_progress()
	var all_cells := Classic15x15Board.main_loop_cell_ids()
	var occupied: StringName = all_cells[0]
	state.add_gift(GiftState.create_on_cell(occupied, 1))

	var free := _gift_rules.free_spawn_cells(state)

	assert_false(occupied in free, "заета от подарък клетка не е свободна за нов spawn")
	assert_eq(free.size(), all_cells.size() - 1)


func test_spawn_if_due_creates_gift_and_reschedules_next_threshold() -> void:
	var state := _two_player_in_progress()
	state.command_sequence = 5
	state.next_gift_spawn_at = 5
	var rng := SeededRandomSource.new(3)

	var event := _gift_rules.spawn_if_due(state, rng, state.command_sequence)

	assert_true(event is GiftSpawnedEvent)
	assert_eq(state.gifts.size(), 1)
	assert_true(state.next_gift_spawn_at > state.command_sequence,
			"threshold-ът трябва да се презареди напред след spawn")


func test_spawn_if_due_returns_null_when_not_due() -> void:
	var state := _two_player_in_progress()
	state.next_gift_spawn_at = state.command_sequence + 5
	var rng := SeededRandomSource.new(3)

	var event := _gift_rules.spawn_if_due(state, rng, state.command_sequence)

	assert_null(event)
	assert_eq(state.gifts.size(), 0)


# --- TeleportEffect: реално движение напред (#208, #212) ---

func test_teleport_effect_moves_pawn_forward_by_rolled_distance() -> void:
	var state := _two_player_in_progress()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.MAIN_PATH, 10, route[10])
	var rng := _fixed_rng(5)
	var effect := TeleportEffect.new()
	var context := PowerUpContext.create(PlayerId.GREEN, pawn.pawn_id, pawn.cell_id, 7)

	var events := effect.resolve(context, state, rng)

	assert_eq(pawn.path_index, 15, "5-клетъчен телепорт от 10 → 15")
	assert_eq(pawn.cell_id, route[15])
	assert_eq(events.size(), 1)
	assert_true(events[0] is PawnMovedEvent)


func test_teleport_effect_captures_lone_enemy_on_landing_cell() -> void:
	var state := _two_player_in_progress()
	var green_route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var green := state.get_player(PlayerId.GREEN)
	var mover := green.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 10, green_route[10])
	var dest_cell: StringName = green_route[13]
	var yellow := state.get_player(PlayerId.YELLOW)
	var victim := yellow.get_pawn_by_index(0)
	victim.set_position(PawnZone.MAIN_PATH, 20, dest_cell)

	var rng := _fixed_rng(3)
	var context := PowerUpContext.create(PlayerId.GREEN, mover.pawn_id, mover.cell_id, 9)
	var events := TeleportEffect.new().resolve(context, state, rng)

	assert_eq(mover.cell_id, dest_cell)
	assert_true(victim.is_in_base(), "хванатата пионка се връща в базата")
	var has_capture := false
	for event in events:
		if event is PawnCapturedEvent:
			has_capture = true
	assert_true(has_capture, "телепорт върху единична противникова → capture")


func test_teleport_effect_ignores_pawn_not_on_main_path() -> void:
	var state := _two_player_in_progress()
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)
	assert_true(pawn.is_in_base(), "по подразбиране пионките са в базата")

	var rng := _fixed_rng(5)
	var context := PowerUpContext.create(PlayerId.GREEN, pawn.pawn_id, pawn.cell_id, 1)
	var events := TeleportEffect.new().resolve(context, state, rng)

	assert_true(events.is_empty(),
			"пионка в базата не е на main path — телепортът е no-op")
	assert_true(pawn.is_in_base())


func test_teleport_effect_conflict_stops_at_nearer_valid_cell() -> void:
	# #212: пълното разстояние е блокирано от собствен full stack (2) →
	# отстъпва до най-близката свободна клетка по-назад в същата посока.
	var state := _two_player_in_progress()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var player := state.get_player(PlayerId.GREEN)
	var mover := player.get_pawn_by_index(0)
	mover.set_position(PawnZone.MAIN_PATH, 5, route[5])
	# Пълно разстояние (5) → route[10]; блокираме го с 2 свои пионки (max stack).
	player.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 10, route[10])
	player.get_pawn_by_index(2).set_position(PawnZone.MAIN_PATH, 10, route[10])

	var rng := _fixed_rng(5)
	var context := PowerUpContext.create(PlayerId.GREEN, mover.pawn_id, mover.cell_id, 4)
	var events := TeleportEffect.new().resolve(context, state, rng)

	assert_eq(mover.path_index, 9, "route[10] е блокирана → отстъпва до 9")
	assert_eq(mover.cell_id, route[9])
	assert_false(events.is_empty())


# --- ShieldEffect: продължителност + no-op извън main path (#209) ---

func test_shield_effect_applies_duration_and_emits_event() -> void:
	var state := _two_player_in_progress()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.MAIN_PATH, 6, route[6])

	var context := PowerUpContext.create(PlayerId.GREEN, pawn.pawn_id, pawn.cell_id, 3)
	var events := ShieldEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_true(pawn.has_shield())
	assert_eq(pawn.shield_turns_remaining, ShieldEffect.BASE_DURATION)
	assert_eq(events.size(), 1)
	var applied := events[0] as ShieldAppliedEvent
	assert_not_null(applied)
	assert_eq(applied.pawn_id, pawn.pawn_id)
	assert_eq(applied.turns, ShieldEffect.BASE_DURATION)


func test_shield_effect_ignores_pawn_not_on_main_path() -> void:
	var state := _two_player_in_progress()
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)

	var context := PowerUpContext.create(PlayerId.GREEN, pawn.pawn_id, pawn.cell_id, 3)
	var events := ShieldEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_true(events.is_empty())
	assert_false(pawn.has_shield())


# --- ExtraTurnEffect: незабавен extra roll (#210) ---

func test_extra_turn_effect_grants_extra_roll_on_turn() -> void:
	var state := _two_player_in_progress()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.MAIN_PATH, 6, route[6])
	assert_false(state.turn.has_extra_roll_pending())

	var context := PowerUpContext.create(PlayerId.GREEN, pawn.pawn_id, pawn.cell_id, 3)
	var events := ExtraTurnEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_true(state.turn.has_extra_roll_pending())
	assert_true(events.is_empty(),
			"ExtraTurnEffect не произвежда собствено събитие (#210)")


func test_extra_turn_effect_ignores_pawn_not_on_main_path() -> void:
	var state := _two_player_in_progress()
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)

	var context := PowerUpContext.create(PlayerId.GREEN, pawn.pawn_id, pawn.cell_id, 3)
	ExtraTurnEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_false(state.turn.has_extra_roll_pending())


# --- PushEffect: избутва най-близкия противник назад (#211, #212, #213) ---

func test_push_effect_moves_nearest_opponent_backward() -> void:
	var state := _two_player_in_progress()
	var yellow_route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var yellow := state.get_player(PlayerId.YELLOW)
	var target := yellow.get_pawn_by_index(0)
	target.set_position(PawnZone.MAIN_PATH, 10, yellow_route[10])

	var attacker_cell := _cell_near(target.cell_id, 3)
	var green := state.get_player(PlayerId.GREEN)
	var attacker := green.get_pawn_by_index(0)
	attacker.set_position(PawnZone.MAIN_PATH, 0, attacker_cell)

	var context := PowerUpContext.create(PlayerId.GREEN, attacker.pawn_id, attacker.cell_id, 6)
	var events := PushEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_eq(target.path_index, 8, "базово разстояние 2 назад: 10 → 8")
	assert_eq(target.cell_id, yellow_route[8])
	assert_false(events.is_empty())


func test_push_effect_ignores_opponent_in_home_stretch() -> void:
	# #213: избутването не действа върху пионки в home stretch/база — единствен
	# опонент е в home stretch → няма валидна цел → no-op.
	var state := _two_player_in_progress()
	var yellow_route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var home_index := Classic15x15Board.MAIN_LOOP_LENGTH
	var yellow := state.get_player(PlayerId.YELLOW)
	var pawn := yellow.get_pawn_by_index(0)
	pawn.set_position(PawnZone.HOME_STRETCH, home_index, yellow_route[home_index])

	var green := state.get_player(PlayerId.GREEN)
	var attacker := green.get_pawn_by_index(0)
	attacker.set_position(PawnZone.MAIN_PATH, 0, Classic15x15Board.main_loop_cell_ids()[0])

	var context := PowerUpContext.create(PlayerId.GREEN, attacker.pawn_id, attacker.cell_id, 6)
	var events := PushEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_true(events.is_empty())
	assert_eq(pawn.path_index, home_index, "home stretch пионката не е засегната")


func test_push_effect_conflict_stops_at_nearer_valid_cell() -> void:
	# #212: пълното разстояние назад (2) е блокирано от собствен full stack на
	# target-а → отстъпва до 1 клетка назад вместо да откаже целия push.
	var state := _two_player_in_progress()
	var yellow_route := Classic15x15Board.player_route_cell_ids_for(PlayerId.YELLOW)
	var yellow := state.get_player(PlayerId.YELLOW)
	var target := yellow.get_pawn_by_index(0)
	target.set_position(PawnZone.MAIN_PATH, 10, yellow_route[10])
	yellow.get_pawn_by_index(1).set_position(PawnZone.MAIN_PATH, 8, yellow_route[8])
	yellow.get_pawn_by_index(2).set_position(PawnZone.MAIN_PATH, 8, yellow_route[8])

	var attacker_cell := _cell_near(target.cell_id, 3)
	var green := state.get_player(PlayerId.GREEN)
	var attacker := green.get_pawn_by_index(0)
	attacker.set_position(PawnZone.MAIN_PATH, 0, attacker_cell)

	var context := PowerUpContext.create(PlayerId.GREEN, attacker.pawn_id, attacker.cell_id, 6)
	var events := PushEffect.new().resolve(context, state, SeededRandomSource.new(1))

	assert_eq(target.path_index, 9, "route[8] е блокирана от 2 свои → отстъпва до 9")
	assert_eq(target.cell_id, yellow_route[9])


# --- AnimalPassive дефолтни модификатори (passthrough) ---

func test_animal_passive_extends_ref_counted() -> void:
	var passive := AnimalPassive.new()
	assert_not_null(passive)
	assert_true(passive is RefCounted,
			"AnimalPassive трябва да extends RefCounted, не Node")


func test_animal_passive_default_teleport_modifier_passthrough() -> void:
	var passive := AnimalPassive.new()
	assert_eq(passive.modify_teleport_distance(3), 3,
			"Базовото modify_teleport_distance трябва да върне стойността без промяна")
	assert_eq(passive.modify_teleport_distance(6), 6)


func test_animal_passive_default_push_modifier_passthrough() -> void:
	var passive := AnimalPassive.new()
	assert_eq(passive.modify_push_distance(2), 2,
			"Базовото modify_push_distance трябва да върне стойността без промяна")


func test_animal_passive_default_shield_modifier_passthrough() -> void:
	var passive := AnimalPassive.new()
	assert_eq(passive.modify_shield_duration(1), 1,
			"Базовото modify_shield_duration трябва да върне стойността без промяна")


func test_animal_passive_default_gift_spawn_weight_passthrough() -> void:
	var passive := AnimalPassive.new()
	var result := passive.modify_gift_spawn_weight(1.0)
	assert_true(absf(result - 1.0) < 0.0001,
			"Базовото modify_gift_spawn_weight трябва да върне стойността без промяна")


# --- ModifierPipeline ---

func test_modifier_pipeline_extends_ref_counted() -> void:
	var pipeline := ModifierPipeline.new()
	assert_not_null(pipeline, "ModifierPipeline трябва да може да се инстанцира")
	assert_true(pipeline is RefCounted,
			"ModifierPipeline трябва да extends RefCounted, не Node")


func test_modifier_pipeline_is_not_node() -> void:
	var pipeline: Object = ModifierPipeline.new()
	assert_false(pipeline is Node,
			"ModifierPipeline не трябва да extends Node")


func test_modifier_pipeline_chains_added_passives() -> void:
	var pipeline := ModifierPipeline.new()
	pipeline.add(_DoublingPassive.new())
	assert_eq(pipeline.modify_teleport_distance(3), 6)
	assert_eq(pipeline.modify_push_distance(2), 4)


# --- PowerUpRegistry (#196/#213: id → resolver, без match/if по низ) ---

func test_power_up_registry_resolves_all_four_v1_ids() -> void:
	var registry := PowerUpRegistry.new()
	assert_true(registry.resolver_for(PowerUpId.TELEPORT_FORWARD) is TeleportEffect)
	assert_true(registry.resolver_for(PowerUpId.SHIELD) is ShieldEffect)
	assert_true(registry.resolver_for(PowerUpId.EXTRA_TURN) is ExtraTurnEffect)
	assert_true(registry.resolver_for(PowerUpId.PUSH) is PushEffect)


func test_power_up_registry_unknown_id_returns_null() -> void:
	var registry := PowerUpRegistry.new()
	assert_null(registry.resolver_for(&"not_a_power_up"))


# --- GameEngine интеграция: MovePawnCommand кацнало на подарък (#204/#206/#207) ---

func test_move_pawn_landing_on_gift_resolves_power_up_through_engine() -> void:
	var state := _two_player_in_progress()
	var route := Classic15x15Board.player_route_cell_ids_for(PlayerId.GREEN)
	var gift_cell: StringName = route[6]
	state.add_gift(GiftState.create_on_cell(gift_cell, 1))
	var player := state.get_player(PlayerId.GREEN)
	var pawn := player.get_pawn_by_index(0)
	pawn.set_position(PawnZone.MAIN_PATH, 2, route[2])
	state.turn.enter_awaiting_move(4, [pawn.pawn_id])

	var cmd := MovePawnCommand.create_for_pawn(PlayerId.GREEN, pawn.pawn_id)
	state.stamp_command(cmd)
	var rng := _fixed_rng(4)
	var engine := GameEngine.new()

	var result := engine.validate_and_apply(state, cmd, rng)

	assert_true(result.accepted)
	assert_true(result.state.get_gift_at(gift_cell) == null,
			"взетият подарък трябва да е премахнат от state.gifts")

	# Резолвнатият power-up (тук: teleport, PowerUpId.ALL[0]) може да премести
	# пионката НАТАТЪК от gift_cell в същата команда (§4.2: взимането е
	# синхронно) — проверяваме взимането през самото GiftCollectedEvent, не
	# крайната клетка на пионката.
	var collected: GiftCollectedEvent = null
	var has_resolved := false
	for event in result.events:
		if event is GiftCollectedEvent:
			collected = event
		if event is PowerUpResolvedEvent:
			has_resolved = true
	assert_not_null(collected,
			"кацане на подарък трябва да произведе GiftCollectedEvent")
	assert_eq(collected.cell_id, gift_cell)
	assert_eq(collected.pawn_id, pawn.pawn_id)
	assert_true(has_resolved,
			"кацане на подарък трябва да произведе PowerUpResolvedEvent")


# --- Помощни функции ---

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


func _fixed_rng(face: int) -> RandomSource:
	return _FixedFaceRandomSource.new(face)


## Main-loop клетка на `steps` разстояние (по посока напред) от `from_cell`
## — удобно за позициониране на "attacker" близо до target-а на PushEffect
## (търсенето е по общ main_loop, не по player-специфичен маршрут).
func _cell_near(from_cell: StringName, steps: int) -> StringName:
	var cells := Classic15x15Board.main_loop_cell_ids()
	var idx := Classic15x15Board.main_loop_index_of(from_cell)
	var target_idx := (idx + steps) % cells.size()
	return cells[target_idx]


class _FixedFaceRandomSource extends RandomSource:
	var _face: int = DiceState.VALUE_MIN

	func _init(face: int) -> void:
		_face = face

	func next_int(min_val: int, max_val: int) -> int:
		return clampi(_face, min_val, max_val)


## Тестова passive: удвоява всяко разстояние — за проверка, че ModifierPipeline
## реално верижва добавени passives, а не просто ги съхранява.
class _DoublingPassive extends AnimalPassive:
	func modify_teleport_distance(base: int) -> int:
		return base * 2

	func modify_push_distance(base: int) -> int:
		return base * 2
