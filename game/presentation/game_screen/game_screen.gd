class_name GameScreen
extends Node
## Корен на Game екрана (docs/V1_ARCHITECTURE.md, раздел 6).
##
## Единственият му вход е MatchConfig — не знае нищо за менютата.
## При старт инициализира GamePresenter с MatchSession от MatchFactory.
##
## Поток:
##   AppFlow.navigate_to_game(config)
##     → GameScreen._on_match_config_received(config)
##     → MatchFactory.build(config)  → MatchSession
##     → GamePresenter.bind(session)
##
## #177: свързва текущата ludo_game.tscn (Board/Pawns/UI/Camera2D — вече
## мигрирали към BoardView/PawnView/DiceView) към MatchSession + GamePresenter,
## вместо старата ръчна gameplay логика в scripts/ludo_game.gd.
##
## AppFlow/MainMenu/MatchSetup не съществуват още (§8) — до тогава start_match()
## приема хардкоднат default MatchConfig, за да остане екранът playable.
##
## Presentation gate (§3 / #177 фикс): MatchFactory.create_unstarted() +
## MatchSession.begin() след GamePresenter.bind() — иначе първият
## MatchStarted/TurnChanged батч няма абонат (MatchSession.start() го излъчва
## синхронно).

const PAWN_SCENE := preload("res://scenes/pawn.tscn")
const PAWN_TEXTURE := "res://rss/pawns/User05.png"

## Presentation-only цветова маркировка по seat (§6.3) — темата/skin-ът е
## content-driven по-късно (AnimalDefinition); засега еднакъв спрайт, tint по цвят.
const SEAT_TINT: Dictionary = {
	&"green": Color(0.55, 0.85, 0.45),
	&"orange": Color(0.95, 0.62, 0.25),
	&"yellow": Color(0.95, 0.85, 0.25),
	&"cyan": Color(0.35, 0.80, 0.85),
}

@onready var _board: BoardView = $Board
@onready var _pawns_root: Node2D = $Pawns
@onready var _dice_view: DiceView = $UI/DiceViewportContainer/SubViewport/DiceWorld/Dice
@onready var _dice_button: Button = $UI/DiceButton
@onready var _dice_result: Label = $UI/DiceResult
@onready var _turn_label: Label = $UI/TurnLabel
@onready var _debug_rolls: HBoxContainer = $UI/DebugRolls

var _presenter: GamePresenter = null
var _session: MatchSession = null


func _ready() -> void:
	# Debug-only forced rolls се решават на domain ниво (seeded RNG) — няма
	# authorized начин да инжектираме конкретно лице през RollDiceCommand.
	_debug_rolls.visible = false
	_debug_rolls.process_mode = Node.PROCESS_MODE_DISABLED

	start_match(_default_match_config())


## Единствен вход отвън (§6). AppFlow/MatchSetup ще викат това с истински config.
func start_match(config: MatchConfig) -> void:
	var factory := MatchFactory.new()
	_session = factory.create_unstarted(config)

	_presenter = GamePresenter.new()
	add_child(_presenter)
	_presenter.bind(_session)
	_presenter.set_board_view(_board)
	_presenter.set_dice_view(_dice_view)

	var animation_queue := AnimationQueue.new()
	add_child(animation_queue)
	_presenter.set_animation_queue(animation_queue)

	_spawn_pawn_views(_session.get_state())
	_wire_ui()

	# Presentation вече е bind-нат — безопасно да подадем StartMatchCommand.
	_session.begin()


func _wire_ui() -> void:
	if not _dice_button.pressed.is_connected(_on_dice_button_pressed):
		_dice_button.pressed.connect(_on_dice_button_pressed)
	if not _dice_view.dice_rolled.is_connected(_on_dice_rolled):
		_dice_view.dice_rolled.connect(_on_dice_rolled)
	_presenter.state_view_changed.connect(_on_state_view_changed)
	_presenter.human_action_available.connect(_on_human_action_available)
	_presenter.results_requested.connect(_on_results_requested)
	_session.invariant_violated.connect(_on_invariant_violated)
	_on_state_view_changed(_presenter.get_state_view())


func _on_dice_button_pressed() -> void:
	_dice_view.roll_requested.emit()


func _on_dice_rolled(value: int) -> void:
	_dice_result.text = str(value)


func _on_state_view_changed(state_view: Dictionary) -> void:
	var active_id := str(state_view.get("active_player_id", ""))
	if active_id.is_empty():
		return
	_turn_label.text = "%s's turn" % active_id.capitalize()


func _on_human_action_available(player_id: StringName, _legal_actions: Array) -> void:
	_turn_label.text = "%s's turn" % String(player_id).capitalize()


func _on_results_requested(summary: Dictionary) -> void:
	_dice_button.disabled = true
	var ranking: Array = summary.get("ranking", [])
	_turn_label.text = (
			"Match finished — winner: %s" % String(ranking[0]).capitalize()
			if not ranking.is_empty() else "Match finished"
	)


func _on_invariant_violated(description: String, _snapshot: Dictionary) -> void:
	_dice_button.disabled = true
	_turn_label.text = "Match stopped: %s" % description
	push_error("GameScreen: invariant_violated — %s" % description)


## Изгражда PawnView за всеки PawnState от старта на мача (всички в BASE).
## Позицията идва от BoardView.get_cell_position_by_id(cell_id) — стабилен
## cell_id, не hardcoded grid математика (§4.1 / §6.2).
func _spawn_pawn_views(state: GameState) -> void:
	for child in _pawns_root.get_children():
		_pawns_root.remove_child(child)
		child.free()

	for entry in state.players:
		var player := entry as PlayerState
		if player == null:
			continue
		var seat_root := Node2D.new()
		seat_root.name = String(player.player_id).capitalize()
		_pawns_root.add_child(seat_root)

		for pawn_entry in player.pawns:
			var pawn_state := pawn_entry as PawnState
			if pawn_state == null:
				continue
			var pawn_view: PawnView = PAWN_SCENE.instantiate() as PawnView
			pawn_view.name = String(pawn_state.pawn_id)
			pawn_view.pawn_id = pawn_state.pawn_id
			pawn_view.player_id = player.player_id
			seat_root.add_child(pawn_view)

			var tile_w: float = _board.get_tile_display_width()
			pawn_view.setup(PAWN_TEXTURE, tile_w)
			pawn_view.modulate = SEAT_TINT.get(player.player_id, Color.WHITE)
			pawn_view.set_rest_position(_local_position_for(seat_root, pawn_state.cell_id))
			_presenter.register_pawn_view(pawn_view)


func _local_position_for(parent_node: Node2D, cell_id: StringName) -> Vector2:
	var board_local: Vector2 = _board.get_cell_position_by_id(cell_id)
	var global_pos: Vector2 = _board.to_global(board_local)
	return parent_node.to_local(global_pos)


## MVP default до Match Setup екрана (§8): Human (Green) срещу Easy AI (Yellow),
## срещуположни бази (MatchConfig.DEFAULT_SEATS_2P).
static func _default_match_config() -> MatchConfig:
	var config := MatchConfig.create_two_player_opposite()
	config.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.DEFAULT)
	config.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.DEFAULT, AIDifficulty.EASY)
	return config
