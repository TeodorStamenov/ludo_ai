extends Node2D

const PAWN_SCENE := preload("res://scenes/pawn.tscn")
const YELLOW_PAWN_TEXTURE := "res://rss/pawns/User05.png"
const BASE_ROLL_ATTEMPTS := 3

@onready var board: BoardView = $Board
@onready var pawns_root: Node2D = $Pawns
@onready var dice: DiceView = $UI/DiceViewportContainer/SubViewport/DiceWorld/Dice
@onready var dice_result: Label = $UI/DiceResult
@onready var dice_button: Button = $UI/DiceButton
@onready var debug_rolls: HBoxContainer = $UI/DebugRolls
@onready var turn_label: Label = $UI/TurnLabel

## Visual pawns; logical zone/path_index live in parallel PawnState (#154).
var _yellow_pawns: Array[PawnView] = []
var _yellow_pawn_states: Array[PawnState] = []
var _yellow_path: Array[Vector2i] = []
var _selected_pawn: PawnView = null
var _awaiting_pawn_choice: bool = false
var _move_in_progress: bool = false
var _turn_locked: bool = false

var _current_player: StringName = PlayerId.YELLOW
var _last_dice: int = 0
var _extra_roll_pending: bool = false
var _base_attempts_left: int = BASE_ROLL_ATTEMPTS
var _roll_allowed: bool = true

## Временен gameplay RNG за прототипа до MatchSession wiring (#177).
## DiceView не хвърля сам — получава DiceRolledEvent (#161).
var _gameplay_rng: SeededRandomSource = SeededRandomSource.new(
		MatchConfig.generate_rng_seed())


func _ready() -> void:
	dice_button.pressed.connect(_on_dice_button_pressed)
	dice.dice_rolled.connect(_on_dice_rolled)
	dice.roll_requested.connect(_on_dice_button_pressed)

	for i in range(1, 7):
		var button: Button = debug_rolls.get_node("Roll%d" % i) as Button
		button.pressed.connect(_on_debug_roll_pressed.bind(i))

	_yellow_path = Classic15x15Board.player_route_grid_positions_for(PlayerId.YELLOW)
	_spawn_yellow_pawns()
	_start_yellow_turn()


func _spawn_yellow_pawns() -> void:
	var yellow_root := pawns_root.get_node_or_null("Yellow") as Node2D
	if yellow_root == null:
		yellow_root = Node2D.new()
		yellow_root.name = "Yellow"
		pawns_root.add_child(yellow_root)

	for child in yellow_root.get_children():
		yellow_root.remove_child(child)
		child.free()

	_yellow_pawns.clear()
	_yellow_pawn_states.clear()
	_selected_pawn = null
	_awaiting_pawn_choice = false

	var cells: Array[Vector2i] = Classic15x15Board.base_grid_positions_for(PlayerId.YELLOW)
	var tile_w: float = board.get_tile_display_width()

	for i in cells.size():
		var cell: Vector2i = cells[i]
		var cell_id: StringName = CellId.from_vec(cell)
		var logic: PawnState = PawnState.create_in_base(
				PawnId.for_player(PlayerId.YELLOW, i), cell_id)

		var pawn: PawnView = PAWN_SCENE.instantiate() as PawnView
		pawn.name = "Pawn%d" % (i + 1)
		pawn.pawn_id = logic.pawn_id
		pawn.player_id = PlayerId.YELLOW
		pawn.grid_pos = cell
		pawn.setup(YELLOW_PAWN_TEXTURE, tile_w)
		pawn.z_index = cell.x + cell.y + 1
		yellow_root.add_child(pawn)

		var local_pos: Vector2 = yellow_root.to_local(
			board.to_global(board.get_cell_local_position(cell))
		)
		pawn.set_rest_position(local_pos)
		pawn.clicked.connect(_on_pawn_clicked)
		_yellow_pawns.append(pawn)
		_yellow_pawn_states.append(logic)


func _logic_of(pawn: PawnView) -> PawnState:
	for logic in _yellow_pawn_states:
		if logic.pawn_id == pawn.pawn_id:
			return logic
	assert(false, "no PawnState for pawn_id=%s" % String(pawn.pawn_id))
	return null


func _start_yellow_turn() -> void:
	_current_player = PlayerId.YELLOW
	_turn_locked = false
	_extra_roll_pending = false
	_awaiting_pawn_choice = false
	_last_dice = 0
	_clear_selection()
	_stop_all_bobbing()
	_base_attempts_left = BASE_ROLL_ATTEMPTS if _all_pawns_in_base() else 1
	_roll_allowed = true
	turn_label.text = "Yellow's Turn"


func _on_dice_button_pressed() -> void:
	_try_roll_dice(0)


func _on_debug_roll_pressed(value: int) -> void:
	_try_roll_dice(value)


func _try_roll_dice(forced_value: int = 0) -> void:
	if _move_in_progress or _turn_locked or not _roll_allowed:
		return
	if _awaiting_pawn_choice:
		return
	if _current_player != PlayerId.YELLOW:
		return
	_roll_allowed = false
	var value: int = (
			forced_value if DiceState.is_face_value(forced_value)
			else _gameplay_rng.next_int(DiceState.VALUE_MIN, DiceState.VALUE_MAX)
	)
	# Прототип: локален RNG → DiceRolledEvent → DiceView (#161).
	# Целево: MatchSession публикува DiceRolledEvent след RollDiceCommand (#177).
	var rolled := DiceRolledEvent.create_rolled(_current_player, value)
	dice.present_dice_rolled(rolled)


func _on_dice_rolled(value: int) -> void:
	dice_result.text = str(value)
	_last_dice = value
	_clear_selection()
	_stop_all_bobbing()
	_awaiting_pawn_choice = false
	_roll_allowed = false

	var all_in_base := _all_pawns_in_base()

	if all_in_base:
		if value == 6:
			_extra_roll_pending = true
			_offer_moves_for_roll(value)
			return
		_base_attempts_left -= 1
		if _base_attempts_left <= 0:
			_end_turn_to_cyan()
			return
		_roll_allowed = true
		return

	# At least one pawn is on the board.
	if value == 6:
		_extra_roll_pending = true
	else:
		_extra_roll_pending = false

	var movable := _get_movable_pawns(value)
	if movable.is_empty():
		_finish_action_after_roll()
		return

	_awaiting_pawn_choice = true
	for pawn in movable:
		pawn.start_bob()


func _offer_moves_for_roll(value: int) -> void:
	var movable := _get_movable_pawns(value)
	if movable.is_empty():
		_finish_action_after_roll()
		return
	_awaiting_pawn_choice = true
	for pawn in movable:
		pawn.start_bob()


func _get_movable_pawns(value: int) -> Array[PawnView]:
	var result: Array[PawnView] = []
	for i in _yellow_pawns.size():
		var pawn: PawnView = _yellow_pawns[i]
		if not is_instance_valid(pawn):
			continue
		var logic: PawnState = _yellow_pawn_states[i]
		if logic.is_in_base():
			if value == 6 and _can_exit_to_spawn():
				result.append(pawn)
		elif _can_pawn_move(logic, value):
			result.append(pawn)
	return result


func _can_exit_to_spawn() -> bool:
	return true


func _can_pawn_move(logic: PawnState, steps: int) -> bool:
	var dest_index := _resolve_destination_index(logic.path_index, steps)
	if dest_index < 0:
		return false
	var dest_cell: Vector2i = _yellow_path[dest_index]
	# Blocking only applies inside the yellow safe zone.
	if Classic15x15Board.is_home_stretch_cell_of(PlayerId.YELLOW, CellId.from_vec(dest_cell)):
		var blocker := _pawn_on_cell(dest_cell)
		if blocker != null:
			var blocker_logic := _logic_of(blocker)
			if blocker_logic.pawn_id != logic.pawn_id:
				return false
	return true


func _resolve_destination_index(from_index: int, steps: int) -> int:
	if from_index < 0 or steps <= 0:
		return -1
	var remaining: int = (_yellow_path.size() - 1) - from_index
	if remaining <= 0:
		return -1

	var from_cell: Vector2i = _yellow_path[from_index]
	# Inside safe zone: exact dice only (e.g. 3 left => 1/2/3 ok, 4/5/6 not).
	if Classic15x15Board.is_home_stretch_cell_of(PlayerId.YELLOW, CellId.from_vec(from_cell)):
		if steps > remaining:
			return -1
		return from_index + steps

	# On the main path: may enter/finish with leftover steps clamped to path end.
	var advance: int = mini(steps, remaining)
	return from_index + advance


func _on_pawn_clicked(pawn: PawnView) -> void:
	if _move_in_progress or not _awaiting_pawn_choice:
		return
	if not pawn.is_selectable:
		return

	if _selected_pawn == pawn:
		await _confirm_pawn_action(pawn)
		return

	_clear_selection()
	_selected_pawn = pawn
	pawn.set_selected(true)


func _confirm_pawn_action(pawn: PawnView) -> void:
	_move_in_progress = true
	_awaiting_pawn_choice = false
	_stop_all_bobbing()
	_clear_selection()

	var logic: PawnState = _logic_of(pawn)
	if logic.is_in_base():
		await _exit_pawn_to_spawn(pawn, logic)
	else:
		await _move_pawn_steps(pawn, logic, _last_dice)

	_move_in_progress = false
	_finish_action_after_roll()


func _exit_pawn_to_spawn(pawn: PawnView, logic: PawnState) -> void:
	var spawn_cell: Vector2i = Classic15x15Board.spawn_grid_position_for(PlayerId.YELLOW)
	var yellow_root: Node2D = pawn.get_parent() as Node2D
	var target: Vector2 = yellow_root.to_local(
		board.to_global(board.get_cell_local_position(spawn_cell))
	)
	logic.exit_base_to_spawn(CellId.from_vec(spawn_cell))
	pawn.grid_pos = spawn_cell
	pawn.z_index = spawn_cell.x + spawn_cell.y + 1
	await pawn.move_to_local(target)


func _move_pawn_steps(pawn: PawnView, logic: PawnState, steps: int) -> void:
	var dest_index := _resolve_destination_index(logic.path_index, steps)
	if dest_index < 0:
		return

	var yellow_root: Node2D = pawn.get_parent() as Node2D
	for idx in range(logic.path_index + 1, dest_index + 1):
		var cell: Vector2i = _yellow_path[idx]
		var cell_id: StringName = CellId.from_vec(cell)
		var zone: int = (
				PawnZone.HOME_STRETCH
				if Classic15x15Board.is_home_stretch_cell_of(PlayerId.YELLOW, cell_id)
				else PawnZone.MAIN_PATH
		)
		var target: Vector2 = yellow_root.to_local(
			board.to_global(board.get_cell_local_position(cell))
		)
		logic.set_position(zone, idx, cell_id)
		pawn.grid_pos = cell
		pawn.z_index = cell.x + cell.y + 1
		await pawn.move_to_local(target, 0.18)


func _finish_action_after_roll() -> void:
	_clear_selection()
	_stop_all_bobbing()
	_awaiting_pawn_choice = false

	if _extra_roll_pending:
		_extra_roll_pending = false
		_roll_allowed = true
		return

	_end_turn_to_cyan()


func _end_turn_to_cyan() -> void:
	_turn_locked = true
	_roll_allowed = false
	_awaiting_pawn_choice = false
	_clear_selection()
	_stop_all_bobbing()
	turn_label.text = "Cyan player's turn"
	await get_tree().create_timer(2.0).timeout
	_start_yellow_turn()


func _all_pawns_in_base() -> bool:
	for logic in _yellow_pawn_states:
		if not logic.is_in_base():
			return false
	return true


func _get_base_pawns() -> Array[PawnView]:
	var result: Array[PawnView] = []
	for i in _yellow_pawns.size():
		var pawn: PawnView = _yellow_pawns[i]
		if is_instance_valid(pawn) and _yellow_pawn_states[i].is_in_base():
			result.append(pawn)
	return result


func _pawn_on_cell(cell: Vector2i) -> PawnView:
	for i in _yellow_pawns.size():
		var pawn: PawnView = _yellow_pawns[i]
		var logic: PawnState = _yellow_pawn_states[i]
		if is_instance_valid(pawn) and not logic.is_in_base() and pawn.grid_pos == cell:
			return pawn
	return null


func _stop_all_bobbing() -> void:
	for pawn in _yellow_pawns:
		if is_instance_valid(pawn):
			pawn.stop_bob()


func _clear_selection() -> void:
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		_selected_pawn.set_selected(false)
	_selected_pawn = null
