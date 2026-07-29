class_name MoveEvaluator
extends RefCounted
## Оценъчни сигнали за legal MovePawnCommand, консумирани от AIPolicy scoring
## (docs/V1_GAME_DESIGN.md §6; #188-192).
##
## Не въвежда нови правила — само чете вече съществуващите query методи от
## MoveRules/CaptureRules/StackRules/FinishRules, за да отговори „какво би
## станало, ако тази пионка се премести с този зар", без да мутира state.
## GameEngine.get_legal_actions() записва резултата като meta върху всяка
## MovePawnCommand — точните ключове, които MediumAIPolicy/HardAIPolicy вече
## четат в _score_action (game/application/ai/*.gd).

const KEY_CAPTURES_OPPONENT := "captures_opponent"
const KEY_ESCAPES_THREAT := "escapes_threat"
const KEY_FORMS_STACK := "forms_stack"
const KEY_LANDS_ON_GIFT := "lands_on_gift"
const KEY_ENTERS_FINISH := "enters_finish"
const KEY_TARGET_PATH_INDEX := "target_path_index"

var _move_rules: MoveRules
var _capture_rules: CaptureRules
var _finish_rules: FinishRules


func _init(
		move_rules: MoveRules,
		capture_rules: CaptureRules,
		finish_rules: FinishRules
) -> void:
	_move_rules = move_rules
	_capture_rules = capture_rules
	_finish_rules = finish_rules


## Изчислява оценъчните сигнали за pawn при dice_value. pawn трябва вече да е
## минал MoveRules.can_move_pawn (иначе резултатът е недефиниран).
func evaluate(
		state: GameState,
		player: PlayerState,
		pawn: PawnState,
		dice_value: int
) -> Dictionary:
	var result := {
		KEY_CAPTURES_OPPONENT: false,
		KEY_ESCAPES_THREAT: false,
		KEY_FORMS_STACK: false,
		KEY_LANDS_ON_GIFT: false,
		KEY_ENTERS_FINISH: false,
		KEY_TARGET_PATH_INDEX: 0,
	}

	# #191: прибиране в центъра — capture/stack/gift не важат за CENTER.
	if _finish_rules.can_finish_pawn(state, player, pawn, dice_value):
		result[KEY_ENTERS_FINISH] = true
		result[KEY_TARGET_PATH_INDEX] = _move_rules.resolve_player_route(
				state, player.player_id).size()
		return result

	var was_on_board := pawn.is_on_board()
	var dest_cell: StringName

	if pawn.is_in_base():
		dest_cell = _move_rules.resolve_spawn_cell(state, player.player_id)
	else:
		var route := _move_rules.resolve_player_route(state, player.player_id)
		var dest_index := _move_rules.resolve_destination_index(
				pawn.path_index, dice_value, route.size())
		if dest_index == MoveRules.DESTINATION_NONE:
			return result
		dest_cell = route[dest_index]
		result[KEY_TARGET_PATH_INDEX] = dest_index

	if dest_cell == &"":
		return result

	# Home stretch дестинация: недостъпна за противници (#115) — occupancy
	# сама по себе си вече е гарантирала легалността в MoveRules.
	var is_home_stretch := Classic15x15Board.is_home_stretch_cell_of(
			player.player_id, dest_cell)

	if not is_home_stretch:
		result[KEY_CAPTURES_OPPONENT] = (
				_capture_rules.find_capturable_at(state, dest_cell, player.player_id) != null)
		result[KEY_FORMS_STACK] = (
				CellOccupancy.from_state(state).count_of_player_at(
						dest_cell, player.player_id) == 1)
		result[KEY_LANDS_ON_GIFT] = state.get_gift_at(dest_cell) != null

	if was_on_board:
		var currently_threatened := _is_cell_threatened(state, player.player_id, pawn.cell_id)
		var dest_threatened := (
				false if is_home_stretch
				else _is_cell_threatened(state, player.player_id, dest_cell))
		result[KEY_ESCAPES_THREAT] = currently_threatened and not dest_threatened

	return result


## #189: true ако съществува опонентска пионка, за която легален ход с
## някой зар 1–6 приключва точно на cell_id. Reuse-ва
## MoveRules.can_advance_on_board / can_exit_base — не преоткрива блокиране,
## имунитет на купчина или occupancy лимити (те вече живеят там).
func _is_cell_threatened(
		state: GameState,
		defending_player_id: StringName,
		cell_id: StringName
) -> bool:
	if state == null or cell_id == &"":
		return false
	for entry in state.players:
		var opponent := entry as PlayerState
		if opponent == null or opponent.player_id == defending_player_id:
			continue
		for pawn_entry in opponent.pawns:
			var opp_pawn := pawn_entry as PawnState
			if opp_pawn == null or opp_pawn.is_finished():
				continue
			if _threatens_cell_with_any_roll(state, opponent, opp_pawn, cell_id):
				return true
	return false


func _threatens_cell_with_any_roll(
		state: GameState,
		opponent: PlayerState,
		opp_pawn: PawnState,
		cell_id: StringName
) -> bool:
	if opp_pawn.is_in_base():
		if _move_rules.resolve_spawn_cell(state, opponent.player_id) != cell_id:
			return false
		return _move_rules.can_exit_base(state, opponent, opp_pawn, DiceState.EXIT_BASE_VALUE)
	if not opp_pawn.is_on_main_path():
		return false
	var route := _move_rules.resolve_player_route(state, opponent.player_id)
	for roll in range(DiceState.VALUE_MIN, DiceState.VALUE_MAX + 1):
		var dest_index := _move_rules.resolve_destination_index(
				opp_pawn.path_index, roll, route.size())
		if dest_index == MoveRules.DESTINATION_NONE:
			continue
		if route[dest_index] != cell_id:
			continue
		if _move_rules.can_advance_on_board(state, opponent, opp_pawn, roll):
			return true
	return false
