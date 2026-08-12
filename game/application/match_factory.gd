class_name MatchFactory
extends RefCounted
## Изгражда MatchSession от MatchConfig (docs/V1_ARCHITECTURE.md, раздел 5).
##
## Отговорности:
##   - валидира MatchConfig преди старт;
##   - инициализира GameState (или приема mid-match restore state);
##   - инициализира SeededRandomSource от rng_state / rng_seed;
##   - конструира PlayerController за всяко seat
##     (HumanController или AIController + AIPolicy);
##   - създава EventQueue и (при нужда) GameEngine;
##   - връща стартирана MatchSession;
##   - create_from_snapshot() — resume от active_match payload (#130).
##
## GameEngine може да се инжектира в _init за stub-ове в тестове.

var _engine: GameEngine = null


func _init(engine: GameEngine = null) -> void:
	_engine = engine


func create(config: MatchConfig, state: GameState = null) -> MatchSession:
	var session := create_unstarted(config, state)
	session.begin()
	return session


## Изгражда MatchSession БЕЗ да подава StartMatchCommand (§6.1 / #177) — за
## GameScreen, което трябва да bind-не GamePresenter преди първия
## events_published батч. Извикващият трябва да викне session.begin() след
## presenter.bind(session). create() = create_unstarted() + session.begin().
##
## rng: опционален инжектиран източник (debug ScriptedRandomSource). При null
## се строи детерминиран SeededRandomSource както обикновено.
func create_unstarted(
		config: MatchConfig,
		state: GameState = null,
		rng: RandomSource = null
) -> MatchSession:
	assert(config != null, "MatchFactory.create_unstarted: config не може да е null")
	assert(config.is_valid(), "MatchFactory.create_unstarted: невалиден MatchConfig")

	var resolved_state: GameState = (
			state if state != null else GameState.create_from_match_config(config))
	# Предпочита инжектиран RNG (debug), после GameState.rng_state при
	# mid-match restore (#60); иначе детерминиран RNG от MatchConfig.rng_seed.
	if rng == null:
		if resolved_state.has_rng_state():
			rng = resolved_state.create_random_source_from_state()
		else:
			rng = config.create_random_source()
	var engine: GameEngine = _engine if _engine != null else GameEngine.new()
	var controllers := _build_controllers(config)
	var event_queue := EventQueue.new()
	var session := MatchSession.new()
	session.prepare(config, resolved_state, engine, rng, controllers, event_queue)
	return session


## Resume от MatchSession.to_snapshot() / SaveRepository.active_match payload (§9).
## Null при невалиден snapshot — без частична инициализация.
func create_from_snapshot(snapshot: Dictionary) -> MatchSession:
	if not MatchSession.is_snapshot_valid(snapshot):
		push_error("MatchFactory.create_from_snapshot: невалиден snapshot")
		return null
	var state := GameState.from_dict(
			snapshot[MatchSession.SNAPSHOT_KEY_STATE] as Dictionary)
	if state == null or state.match_config == null or not state.match_config.is_valid():
		push_error("MatchFactory.create_from_snapshot: липсва валиден MatchConfig")
		return null
	var config: MatchConfig = state.match_config
	var rng: RandomSource = state.create_random_source_from_state()
	var engine: GameEngine = _engine if _engine != null else GameEngine.new()
	var controllers := _build_controllers(config)
	var session := MatchSession.new()
	if not session.restore_from_snapshot(
			snapshot, engine, rng, controllers, EventQueue.new()):
		push_error("MatchFactory.create_from_snapshot: restore_from_snapshot failed")
		return null
	return session


func _build_controllers(config: MatchConfig) -> Dictionary:
	var result: Dictionary = {}
	for seat: MatchConfig.SeatConfig in config.seats:
		var controller: PlayerController = _build_controller(seat)
		result[seat.player_id] = controller
	return result


func _build_controller(seat: MatchConfig.SeatConfig) -> PlayerController:
	match seat.controller_type:
		MatchConfig.ControllerType.HUMAN:
			return HumanController.new(seat.player_id)
		MatchConfig.ControllerType.AI:
			var policy := _build_ai_policy(seat.ai_difficulty)
			return AIController.new(seat.player_id, policy)
		MatchConfig.ControllerType.REMOTE:
			return RemoteController.new()
	push_error("MatchFactory: неизвестен controller_type %d" % seat.controller_type)
	return HumanController.new(seat.player_id)


func _build_ai_policy(difficulty: int) -> AIPolicy:
	match difficulty:
		AIDifficulty.EASY:
			return EasyAIPolicy.new()
		AIDifficulty.MEDIUM:
			return MediumAIPolicy.new()
		AIDifficulty.HARD:
			return HardAIPolicy.new()
	push_error("MatchFactory: неизвестна AI трудност %d, използвам Easy" % difficulty)
	return EasyAIPolicy.new()
