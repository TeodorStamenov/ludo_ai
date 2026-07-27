class_name MatchSimulator
extends RefCounted
## Headless симулация на пълен мач без Presentation / сцена
## (docs/V1_ARCHITECTURE.md §12 / §16.1; roadmap #139).
##
## Създава MatchSession с AI контролери, автоматично потвърждава
## presentation gate (events_presented) и върти до MATCH_FINISHED.
## Не зарежда сцени, не ползва Node/Control и не прилага правила сама —
## делегира на MatchSession → GameEngine.
##
## Подразбираща се политика: FirstLegalAIPolicy (детерминистична).
## Soft max_steps предпазва от безкрайни цикли; откриването на
## блокирали мачове като отделен инвариант е roadmap #141.


const KEY_OK := "ok"
const KEY_FINISHED := "finished"
const KEY_SUMMARY := "summary"
const KEY_STATE := "state"
const KEY_JOURNAL := "journal"
const KEY_COMMAND_COUNT := "command_count"
const KEY_STEPS := "steps"
const KEY_HIT_LIMIT := "hit_limit"
const KEY_ERROR := "error"

## Soft safety — достатъчно за нормален 2–4p мач; #141 ще стегне лимита.
const DEFAULT_MAX_STEPS := 100_000

var _engine: GameEngine = null
var _policy: AIPolicy = null


func _init(engine: GameEngine = null, policy: AIPolicy = null) -> void:
	_engine = engine
	_policy = policy


## Симулира мач до край (или max_steps). config трябва да е валиден.
## Всички seats получават AI контролери (human/remote се заменят за headless).
## match_id: празен → детерминистичен &"m_sim_{rng_seed}" (еднакъв seed → еднакъв hash).
func run(
		config: MatchConfig,
		max_steps: int = DEFAULT_MAX_STEPS,
		match_id: StringName = &""
) -> Dictionary:
	if config == null:
		return _failure("config is null")
	if not config.is_valid():
		return _failure("config failed is_valid()")
	if max_steps <= 0:
		return _failure("max_steps must be positive")

	var policy: AIPolicy = _policy if _policy != null else FirstLegalAIPolicy.new()
	var controllers := _build_controllers(config, policy)
	var engine: GameEngine = _engine if _engine != null else GameEngine.new()
	var rng: RandomSource = config.create_random_source()
	var resolved_id: StringName = (
			match_id if match_id != &""
			else StringName("m_sim_%d" % config.rng_seed))
	var state := GameState.create_from_match_config(config, resolved_id)
	var session := MatchSession.new()

	var summary_box: Dictionary = {"summary": {}}
	session.match_finished.connect(
			func(summary: Dictionary) -> void:
				summary_box["summary"] = summary
	)

	session.start(config, state, engine, rng, controllers, EventQueue.new())

	var steps := 0
	var hit_limit := false
	while session.is_active() or session.is_presentation_pending():
		if steps >= max_steps:
			hit_limit = true
			break
		if session.is_presentation_pending():
			session.events_presented(session.get_pending_sequence())
			steps += 1
			continue
		# Активен мач без pending и без AI ход → блокирал (няма legal actions).
		return _failure_session(
				"match stuck: active without pending presentation or AI action",
				session,
				summary_box["summary"],
				steps,
				false)

	var finished := not session.is_active() and session.get_state() != null \
			and session.get_state().is_finished()
	var summary: Dictionary = summary_box["summary"]
	if finished and summary.is_empty():
		summary = MatchResult.create_from_game_state(session.get_state()).to_dict()

	var journal := session.get_journal()
	var command_count := 0
	if journal != null:
		command_count = journal.get_accepted_commands().size()

	if hit_limit:
		return {
			KEY_OK: false,
			KEY_FINISHED: finished,
			KEY_SUMMARY: summary,
			KEY_STATE: session.get_state(),
			KEY_JOURNAL: journal,
			KEY_COMMAND_COUNT: command_count,
			KEY_STEPS: steps,
			KEY_HIT_LIMIT: true,
			KEY_ERROR: "hit max_steps (%d) before match finished" % max_steps,
		}

	if not finished:
		return _failure_session(
				"simulation ended without MATCH_FINISHED",
				session,
				summary,
				steps,
				false)

	return {
		KEY_OK: true,
		KEY_FINISHED: true,
		KEY_SUMMARY: summary,
		KEY_STATE: session.get_state(),
		KEY_JOURNAL: journal,
		KEY_COMMAND_COUNT: command_count,
		KEY_STEPS: steps,
		KEY_HIT_LIMIT: false,
		KEY_ERROR: "",
	}


## Удобен 2/3/4P AI-vs-AI MatchConfig за симулации (всички seats = AI).
static func make_ai_config(
		rng_seed: int,
		seat_count: int = 2,
		difficulty: int = AIDifficulty.EASY
) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.rng_seed = rng_seed
	cfg.set_active_seats(MatchConfig.default_seats_for_count(seat_count))
	var animals: Array[StringName] = AnimalId.ALL
	for i in cfg.seats.size():
		var seat: MatchConfig.SeatConfig = cfg.seats[i]
		var animal: StringName = animals[i % animals.size()]
		seat.configure(MatchConfig.ControllerType.AI, animal, difficulty)
	return cfg


func _build_controllers(config: MatchConfig, policy: AIPolicy) -> Dictionary:
	var controllers: Dictionary = {}
	for seat: MatchConfig.SeatConfig in config.seats:
		controllers[seat.player_id] = AIController.new(seat.player_id, policy)
	return controllers


func _failure(message: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_FINISHED: false,
		KEY_SUMMARY: {},
		KEY_STATE: null,
		KEY_JOURNAL: null,
		KEY_COMMAND_COUNT: 0,
		KEY_STEPS: 0,
		KEY_HIT_LIMIT: false,
		KEY_ERROR: message,
	}


func _failure_session(
		message: String,
		session: MatchSession,
		summary: Dictionary,
		steps: int,
		hit_limit: bool
) -> Dictionary:
	var journal: GameplayJournal = null
	var command_count := 0
	var state: GameState = null
	if session != null:
		journal = session.get_journal()
		state = session.get_state()
		if journal != null:
			command_count = journal.get_accepted_commands().size()
	return {
		KEY_OK: false,
		KEY_FINISHED: state != null and state.is_finished(),
		KEY_SUMMARY: summary,
		KEY_STATE: state,
		KEY_JOURNAL: journal,
		KEY_COMMAND_COUNT: command_count,
		KEY_STEPS: steps,
		KEY_HIT_LIMIT: hit_limit,
		KEY_ERROR: message,
	}
