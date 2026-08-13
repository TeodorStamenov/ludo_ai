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
##
## #251: _ready() първо проверява за запазен active_match.json
## (SaveRepository.has_match_snapshot) и продължава от него (_resume_match),
## преди да падне към нов мач (start_match).

const PAWN_SCENE := preload("res://scenes/pawn.tscn")

@onready var _board: BoardView = $Board
@onready var _pawns_root: Node2D = $Pawns
@onready var _dice_view: DiceView = $UI/DiceViewportContainer/SubViewport/DiceWorld/Dice
@onready var _dice_button: Button = $UI/DiceButton
@onready var _dice_result: Label = $UI/DiceResult
@onready var _turn_label: Label = $UI/TurnLabel
@onready var _debug_rolls: HBoxContainer = $UI/DebugRolls
@onready var _debug_power_ups: HBoxContainer = $UI/DebugPowerUps
@onready var _debug_setup_panel: VBoxContainer = $UI/DebugSetup
@onready var _debug_mode_pawns: Button = $UI/DebugSetup/ModeRow/ModePawns
@onready var _debug_mode_gifts: Button = $UI/DebugSetup/ModeRow/ModeGifts
@onready var _debug_start_button: Button = $UI/DebugSetup/ActionRow/StartButton
@onready var _debug_clear_button: Button = $UI/DebugSetup/ActionRow/ClearButton
@onready var _debug_setup_status: Label = $UI/DebugSetup/SetupStatus

var _presenter: GamePresenter = null
var _session: MatchSession = null
var _action_log: MatchActionLog = null
## animal_id → AnimalDefinition (content/animals/*.tres, #233).
var _animals := AnimalRegistry.new()
## Auto-save на активния мач (#250) + resume при старт (#251).
var _save_repository: SaveRepository = LocalSaveRepository.new()
## Debug-only: подменя зара / power-up-а. null извън debug build.
var _scripted_rng: ScriptedRandomSource = null
## Debug-only: визуална подредба на дъската преди старт. null извън debug build.
var _debug_setup: DebugScenarioSetup = null


func _ready() -> void:
	# Целият developer инструментариум е зад DebugMode — в release build
	# панелите се скриват и не получават input.
	var debug_enabled: bool = DebugMode.is_authorized()
	for panel in [_debug_rolls, _debug_power_ups, _debug_setup_panel]:
		panel.visible = debug_enabled
		panel.process_mode = (
				Node.PROCESS_MODE_INHERIT if debug_enabled
				else Node.PROCESS_MODE_DISABLED)

	if _try_resume_active_match():
		return
	start_match(_default_match_config())


## Единствен вход отвън (§6). AppFlow/MatchSetup ще викат това с истински config.
func start_match(config: MatchConfig) -> void:
	var factory := MatchFactory.new()
	# В debug build gameplay случайността минава през ScriptedRandomSource, за
	# да могат бутоните да заредят конкретен зар / power-up. Обвитият източник
	# остава детерминираният seeded RNG, така че мачът е възпроизводим.
	_scripted_rng = (
			ScriptedRandomSource.new(config.create_random_source())
			if DebugMode.is_authorized() else null)
	_session = factory.create_unstarted(config, null, _scripted_rng)
	var gifts_root := _bind_session_presentation()

	if DebugMode.is_authorized():
		# begin() се отлага — първо подреждаме дъската, после Старт (виж
		# _on_debug_start_requested за причината подредбата да се прилага
		# СЛЕД StartMatchCommand).
		_enter_debug_setup(gifts_root)
		return

	# Presentation вече е bind-нат — безопасно да подадем StartMatchCommand.
	_session.begin()


## #251: продължава прекъснат мач от запазен snapshot вместо да стартира нов.
## Пропуска debug подредбата — мачът вече е в ход, няма какво да се подрежда.
func _resume_match(snapshot: Dictionary) -> void:
	var factory := MatchFactory.new()
	_session = factory.create_from_snapshot(snapshot)
	if _session == null:
		push_error("GameScreen: create_from_snapshot неуспешен въпреки валиден snapshot")
		start_match(_default_match_config())
		return
	_bind_session_presentation()
	_debug_setup_panel.visible = false
	# resume() (не begin() — StartMatchCommand би презаписал прогреса от
	# нулата) вика _advance() СЕГА, след като Presentation вече е свързан.
	# Ако се извика по-рано (вътре в restore_from_snapshot), AI командата /
	# awaiting_human_action се излъчват преди някой да слуша и се губят
	# безследно — мачът замръзва трайно (_pending_sequence never acked).
	_session.resume()


## #251: ако има запазен активен мач, продължава от него. Връща true ако е
## продължил (тогава _ready() не бива да вика start_match() отгоре).
func _try_resume_active_match() -> bool:
	if not _save_repository.has_match_snapshot():
		return false
	var snapshot := _save_repository.load_match_snapshot()
	if not MatchSession.is_snapshot_valid(snapshot):
		push_warning("GameScreen: невалиден active_match.json — стартирам нов мач")
		_save_repository.clear_match_snapshot()
		return false
	_resume_match(snapshot)
	return true


## Споделената презентационна обвръзка за фрешо стартирана И възстановена
## сесия (#251) — _session трябва вече да е зададена. Връща gifts_root, за да
## може start_match() да го подаде на debug подредбата (само за fresh старт).
func _bind_session_presentation() -> Node2D:
	# Темата е presentation-only (#234) — идва от match_config-а на сесията,
	# еднакво за нов и възстановен мач; BoardThemeRegistry пада към
	# ThemeId.DEFAULT, ако все още няма собствен .tres.
	var match_config: MatchConfig = _session.get_state().match_config
	if match_config != null:
		_board.theme_id = match_config.theme_id

	# Auto-save на всяка стабилна фаза + изчистване при край на мача (#250).
	_session.set_save_repository(_save_repository)

	_action_log = MatchActionLog.new()
	_action_log.begin(_session.get_state().match_id)

	_presenter = GamePresenter.new()
	add_child(_presenter)
	_presenter.bind(_session)
	_presenter.set_board_view(_board)
	_presenter.set_dice_view(_dice_view)

	var animation_queue := AnimationQueue.new()
	add_child(animation_queue)
	_presenter.set_animation_queue(animation_queue)
	# Turn label чака AnimationQueue да довърши батча (напр. зар анимация), не
	# суровия events_published сигнал — иначе текстът сменя играча преди
	# анимацията на зара да е приключила визуално (bug report).
	animation_queue.all_done.connect(_on_animation_all_done)

	var gifts_root := Node2D.new()
	gifts_root.name = "Gifts"
	# $Pawns носи z_index=10 (сцена) — гифтовете трябва да стоят над пионките,
	# особено по време на reveal анимацията при вземане (#221), когато и
	# двете временно седят на същата клетка.
	gifts_root.z_index = 20
	add_child(gifts_root)
	_presenter.set_gifts_root(gifts_root)

	_spawn_pawn_views(_session.get_state())
	_wire_ui()
	return gifts_root


func _wire_ui() -> void:
	if not _dice_button.pressed.is_connected(_on_dice_button_pressed):
		_dice_button.pressed.connect(_on_dice_button_pressed)
	if not _dice_view.dice_rolled.is_connected(_on_dice_rolled):
		_dice_view.dice_rolled.connect(_on_dice_rolled)
	# awaiting_human_action (и оттам state_view_changed/human_action_available)
	# се излъчва само за human seats — MatchSession._advance() го пропуска за
	# autonomous (AI) controllers. TurnChangedEvent идва за всеки ход, независимо
	# от controller_type, затова тук слушаме директно session.events_published.
	_session.events_published.connect(_on_session_events_published)
	_session.command_rejected.connect(_on_session_command_rejected)
	_session.match_finished.connect(_on_session_match_finished)
	_presenter.results_requested.connect(_on_results_requested)
	_session.invariant_violated.connect(_on_invariant_violated)
	_update_turn_label(_session.get_state())


# ── Debug инструментариум (само при DebugMode.is_authorized) ──────────────────

## Влиза в режим подредба и свързва debug панелите. begin() се вика чак при
## натиснат „Старт" (_on_debug_start_requested).
func _enter_debug_setup(gifts_root: Node2D) -> void:
	_debug_setup = DebugScenarioSetup.new()
	_debug_setup.name = "DebugScenarioSetup"
	add_child(_debug_setup)
	_debug_setup.start_requested.connect(_on_debug_start_requested)
	_debug_setup.enter(_board, _pawn_view_map(), gifts_root)

	for i in _debug_rolls.get_child_count():
		var roll_button := _debug_rolls.get_child(i) as Button
		if roll_button != null:
			roll_button.pressed.connect(_on_debug_roll_pressed.bind(i + 1))

	for i in _debug_power_ups.get_child_count():
		var power_up_button := _debug_power_ups.get_child(i) as Button
		if power_up_button != null and i < PowerUpId.ALL.size():
			power_up_button.pressed.connect(
					_on_debug_power_up_pressed.bind(PowerUpId.ALL[i]))

	_debug_mode_pawns.pressed.connect(_on_debug_mode_pressed.bind(DebugScenarioSetup.Mode.PAWNS))
	_debug_mode_gifts.pressed.connect(_on_debug_mode_pressed.bind(DebugScenarioSetup.Mode.GIFTS))
	_debug_start_button.pressed.connect(_on_debug_start_requested)
	_debug_clear_button.pressed.connect(_on_debug_clear_pressed)
	_dice_button.disabled = true


## StartMatchCommand изгражда GameState от нулата (GameEngine._apply_start_match),
## затова подредбата се прилага СЛЕД begin(), синхронно в същия call stack —
## преди AI таймер да е успял да реагира.
func _on_debug_start_requested() -> void:
	if _debug_setup == null or not _debug_setup.is_active():
		return

	_session.begin()
	var state: GameState = _session.get_state()

	if not _debug_setup.apply_to_state(state):
		# Частично приложената подредба не се чисти ръчно: повторно натискане на
		# „Старт" вика begin() отново, а StartMatchCommand изгражда ново чисто
		# състояние, върху което намеренията се прилагат наново.
		_debug_setup_status.text = "Невалидна подредба: %s" % _debug_setup.get_last_error()
		push_warning("DebugScenarioSetup: %s" % _debug_setup.get_last_error())
		return

	# begin_player_turn е изчислил base_attempts_remaining при всички пионки в
	# база — след подредбата се преизчислява. Ходът остава AWAITING_ROLL, а
	# единственото легално действие там е хвърляне, затова вече излъченият
	# awaiting_human_action prompt остава валиден.
	TurnRules.new().begin_player_turn(
			state, state.active_player_index, maxi(state.turn.turn_number, 1))

	_debug_setup.exit()
	_debug_setup_panel.visible = false
	_dice_button.disabled = false

	# clear_pawn_views() ПРЕДИ пресъздаването: _spawn_pawn_views освобождава
	# старите PawnView-ове, а GamePresenter.register_pawn_view не проверява
	# is_instance_valid — без това би пипнал вече освободени инстанции.
	_presenter.clear_pawn_views()
	_spawn_pawn_views(state)
	_present_state_gifts(state)
	_update_turn_label(state)


## Показва подаръците от състоянието през нормалния snap път на binder-а.
func _present_state_gifts(state: GameState) -> void:
	var binder: EventViewBinder = _presenter.get_event_binder()
	if binder == null:
		return
	for entry in state.gifts:
		var gift := entry as GiftState
		if gift != null:
			binder.present(GiftSpawnedEvent.create_from_state(gift, 0))


func _on_debug_roll_pressed(face: int) -> void:
	if _scripted_rng == null:
		return
	var adapter := DebugDiceAdapter.create_authorized()
	if adapter == null:
		return
	_scripted_rng.force_next_face(adapter.request_forced_face(face))


func _on_debug_power_up_pressed(power_up_id: StringName) -> void:
	if _scripted_rng == null:
		return
	_scripted_rng.force_next_power_up(power_up_id)


func _on_debug_mode_pressed(mode: int) -> void:
	if _debug_setup == null:
		return
	_debug_setup.set_mode(mode)
	_debug_mode_pawns.button_pressed = mode == DebugScenarioSetup.Mode.PAWNS
	_debug_mode_gifts.button_pressed = mode == DebugScenarioSetup.Mode.GIFTS


func _on_debug_clear_pressed() -> void:
	if _debug_setup == null:
		return
	_debug_setup.clear_arrangement(_session.get_state())
	_debug_setup_status.text = "Подреди дъската, после Старт"


## pawn_id → PawnView за всички живи пионки под $Pawns.
func _pawn_view_map() -> Dictionary:
	var result: Dictionary = {}
	for seat_root in _pawns_root.get_children():
		for child in seat_root.get_children():
			var pawn := child as PawnView
			if pawn != null:
				result[pawn.pawn_id] = pawn
	return result


func _on_dice_button_pressed() -> void:
	_dice_view.roll_requested.emit()


func _on_dice_rolled(value: int) -> void:
	_dice_result.text = str(value)


func _on_session_events_published(sequence: int, events: Array) -> void:
	if _action_log != null:
		_action_log.record_events(sequence, events)


## AnimationQueue.all_done — батчът вече е изигран визуално (#169), безопасно
## е да покажем текущия активен играч (bug report: не по-рано, докато зар/друга
## анимация все още тече). GamePresenter._on_animation_all_done (свързан преди
## този listener) може вече да е показал "Match finished" през
## _on_results_requested — не го презаписвай.
func _on_animation_all_done(_sequence: int) -> void:
	var state := _session.get_state()
	if state != null and state.is_finished():
		return
	_update_turn_label(state)


func _on_session_command_rejected(command: GameCommand, reason: String) -> void:
	if _action_log != null:
		_action_log.record_rejected(command, reason)


func _on_session_match_finished(_summary: Dictionary) -> void:
	if _action_log != null:
		_action_log.end()
		_action_log = null


func _exit_tree() -> void:
	if _action_log != null:
		_action_log.end()
		_action_log = null


func _update_turn_label(state: GameState) -> void:
	if state == null:
		return
	var active_id := state.get_active_player_id()
	if active_id == &"":
		return
	_turn_label.text = "%s's turn" % String(active_id).capitalize()


func _on_results_requested(summary: Dictionary) -> void:
	_dice_button.disabled = true
	var ranking: Array = summary.get("ranking", [])
	if not ranking.is_empty():
		_turn_label.text = "Match finished — winner: %s" % String(ranking[0]).capitalize()
	else:
		_turn_label.text = "Match finished"


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

		# Спрайтът идва от животното на seat-а (AnimalDefinition.sprite, #233),
		# не от controller_type — човек и AI с едно и също животно изглеждат
		# еднакво, точно както в Match Setup.
		var seat_config := (
				state.match_config.get_seat(player.player_id)
				if state.match_config != null else null)
		var animal_id: StringName = (
				seat_config.animal_id if seat_config != null else AnimalId.DEFAULT)
		var sprite: Texture2D = _animals.sprite_for(animal_id)
		var colorblind_icon: Texture2D = _colorblind_icon_for(animal_id)

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
			pawn_view.setup(sprite, tile_w)
			if colorblind_icon != null:
				pawn_view.set_colorblind_icon(colorblind_icon)
			# grid_pos/z_index: PawnView поддържа тези сама след първия ход
			# (_apply_cell_pose), но при spawn трябва да ги зададем ръчно —
			# иначе z_index=0 губи срещу tiles с по-висок painter's-algorithm ред
			# (случва се видимо само за seats в долната/дясната половина, напр. yellow).
			pawn_view.grid_pos = CellId.to_vec(pawn_state.cell_id)
			pawn_view.z_index = pawn_view.grid_pos.x + pawn_view.grid_pos.y + 1
			pawn_view.set_rest_position(_local_position_for(seat_root, pawn_state.cell_id))
			_presenter.register_pawn_view(pawn_view)


## Colorblind икона от AnimalDefinition (§6.3). null → PawnView пада към
## процедурна форма по player_id; записите още нямат авторизирани икони.
func _colorblind_icon_for(animal_id: StringName) -> Texture2D:
	var definition := _animals.definition_for(animal_id)
	if definition == null:
		return null
	return definition.colorblind_icon


func _local_position_for(parent_node: Node2D, cell_id: StringName) -> Vector2:
	var board_local: Vector2 = _board.get_cell_position_by_id(cell_id)
	var global_pos: Vector2 = _board.to_global(board_local)
	return parent_node.to_local(global_pos)


## MVP default до Match Setup екрана (§8): Human (Green) срещу Easy AI (Yellow),
## срещуположни бази (MatchConfig.DEFAULT_SEATS_2P).
static func _default_match_config() -> MatchConfig:
	var config := MatchConfig.create_two_player_opposite()
	# Различни животни на двата seat-а — спрайтът вече идва от AnimalDefinition
	# (#233), така че еднакво животно би направило страните неразличими.
	config.configure_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, AnimalId.PIG)
	config.configure_seat(
			PlayerId.YELLOW, MatchConfig.ControllerType.AI, AnimalId.COW, AIDifficulty.EASY)
	return config
