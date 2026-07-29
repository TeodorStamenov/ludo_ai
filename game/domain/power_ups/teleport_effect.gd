class_name TeleportEffect
extends PowerUpResolver
## Телепорт напред: пионката скача 3–6 клетки напред (случайно)
## (docs/V1_GAME_DESIGN.md, §4.3; #208).
##
## Animal passive може да увеличи разстоянието (напр. Заек: +1 клетка) чрез
## ModifierPipeline.modify_teleport_distance. Триждащата пионка е винаги на
## MAIN_PATH (само там могат да стоят подаръци — #203), затова "не действа
## върху пионки в home stretch/база" е гарантирано по конструкция, не
## отделна проверка тук.
##
## При конфликт (max 2 свои / имунна купчина) на пълното разстояние спира на
## най-близката валидна клетка по-назад (#212). Кацането прилага същите
## capture/stack правила като нормално движение (единно правило за всички
## премествания — §4.2).

const MIN_DISTANCE := 3
const MAX_DISTANCE := 6

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
	_move_rules = move_rules if move_rules != null else MoveRules.new(null, _stack_rules, _capture_rules)


func resolve(context: PowerUpContext, state: GameState, rng: RandomSource) -> Array:
	var events: Array = []
	var player := state.get_player(context.player_id)
	var pawn := state.get_pawn(context.pawn_id)
	if player == null or pawn == null or not pawn.is_on_main_path():
		return events

	var base_distance: int = rng.next_int(MIN_DISTANCE, MAX_DISTANCE)
	var distance: int = context.modifiers.modify_teleport_distance(base_distance)
	if distance <= 0:
		return events

	var dest_index := _move_rules.resolve_power_up_destination_index(
			state, player, pawn, distance, 1)
	if dest_index == MoveRules.DESTINATION_NONE:
		return events

	var route := _move_rules.resolve_player_route(state, player.player_id)
	var dest_cell: StringName = route[dest_index]
	var before := pawn.duplicate_state()
	var zone := (
			PawnZone.HOME_STRETCH
			if Classic15x15Board.is_home_stretch_cell_of(player.player_id, dest_cell)
			else PawnZone.MAIN_PATH
	)
	pawn.set_position(zone, dest_index, dest_cell)
	events.append(PawnMovedEvent.create_from_states(before, pawn, context.command_sequence))

	for entry in _capture_rules.resolve_capture(state, pawn, context.command_sequence):
		events.append(entry)
	var stack_event := _stack_rules.resolve_stack_formed(state, pawn, context.command_sequence)
	if stack_event != null:
		events.append(stack_event)

	return events
