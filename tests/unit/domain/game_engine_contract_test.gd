extends TestCase
## Unit тестове за публичния договор на GameEngine.
##
## Верифицира: структура на отговора, архитектурни ограничения (domain слой)
## и демонстрира разширения на GUT assertion API добавени с задача #12.
##
## Критични инварианти (docs/V1_ARCHITECTURE.md, раздел 12):
##   - невалидна команда не променя state или RNG;
##   - GameEngine е в game/domain/ и extends RefCounted.


var _engine: GameEngine
var _state: GameState
var _rng: SeededRandomSource


func before_each() -> void:
	_engine = GameEngine.new()
	_state = GameState.new()
	_rng = SeededRandomSource.new(42)


# ── Архитектурни ограничения ──────────────────────────────────────────────────

func test_game_engine_extends_ref_counted() -> void:
	assert_is(_engine, RefCounted,
			"GameEngine трябва да extends RefCounted — domain слой без Node")


func test_game_engine_script_is_in_domain() -> void:
	var path: String = _engine.get_script().resource_path
	assert_string_contains(path, "game/domain/",
			"GameEngine трябва да е в game/domain/")
	assert_false(path.contains("application/"),
			"GameEngine не трябва да е в application/")
	assert_false(path.contains("presentation/"),
			"GameEngine не трябва да е в presentation/")


# ── Публичен договор на apply_command ─────────────────────────────────────────

func test_apply_command_returns_dictionary() -> void:
	var cmd := GameCommand.new()
	var result: Variant = _engine.apply_command(_state, cmd, _rng)
	assert_typeof(result, TYPE_DICTIONARY,
			"apply_command трябва да връща Dictionary")


func test_apply_command_result_has_accepted_key() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_has(result, "accepted",
			"Резултатът трябва да съдържа ключ 'accepted'")


func test_apply_command_result_has_state_key() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_has(result, "state",
			"Резултатът трябва да съдържа ключ 'state'")


func test_apply_command_result_has_events_key() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_has(result, "events",
			"Резултатът трябва да съдържа ключ 'events'")


func test_apply_command_result_has_error_key() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_has(result, "error",
			"Резултатът трябва да съдържа ключ 'error'")


func test_apply_command_accepted_is_bool() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_typeof(result["accepted"], TYPE_BOOL,
			"'accepted' трябва да е bool")


func test_apply_command_events_is_array() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_typeof(result["events"], TYPE_ARRAY,
			"'events' трябва да е Array")


func test_apply_command_error_is_string() -> void:
	var result: Dictionary = _engine.apply_command(_state, GameCommand.new(), _rng)
	assert_typeof(result["error"], TYPE_STRING,
			"'error' трябва да е String")


# ── RNG инвариант ─────────────────────────────────────────────────────────────

func test_invalid_command_does_not_advance_rng() -> void:
	## Инвариант: невалидна команда не консумира RNG entropy.
	## Верифицираме чрез сравнение на state преди и след reject.
	var rng_a := SeededRandomSource.new(100)
	var rng_b := SeededRandomSource.new(100)

	_engine.apply_command(_state, GameCommand.new(), rng_a)

	# При stub reject-ване, rng_b трябва да е в същото начално положение.
	# Когато GameEngine е имплементиран изцяло, само rejected команди не трябва
	# да консумират entropy.
	var state_a := rng_a.get_state()
	var state_b := rng_b.get_state()

	# Stub имплементацията не използва RNG → state_a == state_b (начален).
	assert_eq(state_a, state_b,
			"Stub GameEngine не трябва да консумира RNG entropy")


# ── Демо на разширения GUT API (задача #12) ───────────────────────────────────

func test_gut_assert_gt() -> void:
	assert_gt(6, 5, "6 > 5")
	assert_gt(100, 0, "100 > 0")


func test_gut_assert_lt() -> void:
	assert_lt(1, 6, "1 < 6")


func test_gut_assert_between_dice_roll() -> void:
	var rng := SeededRandomSource.new(7)
	for _i in 50:
		var roll := rng.next_int(1, 6)
		assert_between(roll, 1, 6, "Зарът трябва да е в [1, 6]")


func test_gut_assert_almost_eq() -> void:
	assert_almost_eq(0.1 + 0.2, 0.3, 0.0001, "Floating-point sum близо до 0.3")


func test_gut_assert_has_and_does_not_have() -> void:
	var valid_phases: Array[StringName] = [
		&"AWAITING_ROLL", &"AWAITING_MOVE", &"RESOLVING_MOVE",
		&"RESOLVING_POWER_UP", &"TURN_END", &"MATCH_FINISHED",
	]
	assert_has(valid_phases, &"AWAITING_ROLL")
	assert_has(valid_phases, &"MATCH_FINISHED")
	assert_does_not_have(valid_phases, &"INVALID_PHASE",
			"'INVALID_PHASE' не трябва да е валидна фаза")


func test_gut_assert_string_helpers() -> void:
	var path := "res://game/domain/rules/game_engine.gd"
	assert_string_starts_with(path, "res://")
	assert_string_ends_with(path, ".gd")
	assert_string_contains(path, "domain")


func test_gut_pending_example() -> void:
	pending("Пълното поведение изисква имплементиран GameEngine (задача #15)")
