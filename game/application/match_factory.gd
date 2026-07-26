class_name MatchFactory
extends RefCounted
## Изгражда MatchSession от MatchConfig (docs/V1_ARCHITECTURE.md, раздел 5).
##
## Отговорности:
##   - валидира MatchConfig преди старт;
##   - инициализира SeededRandomSource от rng_seed;
##   - конструира PlayerController за всяко seat
##     (HumanController или AIController + AIPolicy);
##   - създава EventQueue;
##   - връща готова за старт MatchSession.
##
## Не създава GameState или GameEngine — те се инжектират отвън,
## за да може unit тестовете да подменят имплементацията.

var _engine: GameEngine = null


func _init(engine: GameEngine = null) -> void:
	_engine = engine


func create(config: MatchConfig, state: GameState = null) -> MatchSession:
	assert(config != null, "MatchFactory.create: config не може да е null")
	assert(config.is_valid(), "MatchFactory.create: невалиден MatchConfig")

	# Предпочита GameState.rng_state при mid-match restore (#60);
	# иначе детерминиран RNG от MatchConfig.rng_seed.
	var rng: RandomSource
	if state != null and state.has_rng_state():
		rng = state.create_random_source_from_state()
	else:
		rng = config.create_random_source()
	var controllers := _build_controllers(config)
	var event_queue := EventQueue.new()
	var session := MatchSession.new()
	session.start(config, state, _engine, rng, controllers, event_queue)
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
