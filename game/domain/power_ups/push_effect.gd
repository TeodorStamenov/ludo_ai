class_name PushEffect
extends PowerUpResolver
## Избутване: най-близката противникова пионка (по общото трасе) отстъпва
## 2 клетки назад (docs/V1_GAME_DESIGN.md, §4.3; #211).
##
## Animal passive (Куче/Крава) може да промени базовото разстояние чрез
## ModifierPipeline.modify_push_distance — приложено само от страна на
## triggering player-а (target-ово намаление изисква отделен modifiers за
## target-а, извън обхвата на #211; content/animals още няма реални записи).
##
## #213: target search-ът разглежда само опонентски пионки на MAIN_PATH —
## home stretch/база/finished пионки никога не са цел ("не действа върху
## пионки в home stretch или база").
## #212: при конфликт (max 2 свои / имунна купчина) спира на най-близката
## валидна клетка (по-малко от базовото разстояние назад).
##
## V1 опростяване: избутана пионка, кацнала върху подарък, НЕ отключва
## верижно взимане в тази версия — GameEngine._resolve_gift_pickup_if_any е
## private и извикването му оттук би създало кръгова зависимост
## resolver → registry → resolver.

const BASE_DISTANCE := 2

var _move_rules: MoveRules
var _capture_rules: CaptureRules
var _stack_rules: StackRules


func _init(
		move_rules: MoveRules = null,
		capture_rules: CaptureRules = null,
		stack_rules: StackRules = null
) -> void:
	_stack_rules = stack_rules if stack_rules != null else StackRules.new()
	_capture_rules = (
			capture_rules if capture_rules != null else CaptureRules.new(_stack_rules))
	_move_rules = (
			move_rules if move_rules != null
			else MoveRules.new(null, _stack_rules, _capture_rules))


func resolve(context: PowerUpContext, state: GameState, rng: RandomSource) -> Array:
	var events: Array = []
	var triggering_pawn := state.get_pawn(context.pawn_id)
	if triggering_pawn == null:
		return events

	var target := _find_nearest_opponent_on_main_path(
			state, context.player_id, triggering_pawn.cell_id)
	var target_player: PlayerState = target[0]
	var target_pawn: PawnState = target[1]
	if target_player == null or target_pawn == null:
		return events

	var distance: int = context.modifiers.modify_push_distance(BASE_DISTANCE)
	if distance <= 0:
		return events

	var dest_index := _move_rules.resolve_power_up_destination_index(
			state, target_player, target_pawn, distance, -1)
	if dest_index == MoveRules.DESTINATION_NONE:
		return events

	var route := _move_rules.resolve_player_route(state, target_player.player_id)
	var dest_cell: StringName = route[dest_index]
	var before := target_pawn.duplicate_state()
	target_pawn.set_position(PawnZone.MAIN_PATH, dest_index, dest_cell)
	events.append(PawnMovedEvent.create_from_states(before, target_pawn, context.command_sequence))

	for entry in _capture_rules.resolve_capture(state, target_pawn, context.command_sequence):
		events.append(entry)
	var stack_event := _stack_rules.resolve_stack_formed(
			state, target_pawn, context.command_sequence)
	if stack_event != null:
		events.append(stack_event)

	return events


## Най-близката опонентска пионка на MAIN_PATH по circular разстояние в
## main_loop (не player-специфичния маршрут — трасето е общо). Връща
## [PlayerState, PawnState], и двете null ако няма валидна цел.
func _find_nearest_opponent_on_main_path(
		state: GameState,
		attacker_player_id: StringName,
		from_cell_id: StringName
) -> Array:
	var from_index := Classic15x15Board.main_loop_index_of(from_cell_id)
	var best_player: PlayerState = null
	var best_pawn: PawnState = null
	var best_distance := -1
	if from_index < 0:
		return [best_player, best_pawn]

	for entry in state.players:
		var opponent := entry as PlayerState
		if opponent == null or opponent.player_id == attacker_player_id:
			continue
		for pawn_entry in opponent.pawns:
			var pawn := pawn_entry as PawnState
			if pawn == null or not pawn.is_on_main_path():
				continue
			var idx := Classic15x15Board.main_loop_index_of(pawn.cell_id)
			if idx < 0:
				continue
			var diff: int = abs(idx - from_index)
			var loop_distance: int = mini(diff, Classic15x15Board.MAIN_LOOP_LENGTH - diff)
			if best_distance == -1 or loop_distance < best_distance:
				best_distance = loop_distance
				best_player = opponent
				best_pawn = pawn

	return [best_player, best_pawn]
