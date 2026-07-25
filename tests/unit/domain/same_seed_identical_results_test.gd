class_name SameSeedIdenticalResultsTest
extends TestCase
## Unit тестове за инварианта „еднакъв seed → еднакви резултати“
## (Task #32 / docs/V1_ARCHITECTURE.md §4.5, §12, §16).
##
## Критичен инвариант:
##   еднакъв seed + еднакви извиквания = еднаква последователност
##   (основа за replay, save/restore, debug и бъдещ authoritative сървър).
##
## Покрива production SeededRandomSource и MatchConfig.create_random_source()
## без Stub/Null/Adapter и без симулация на GameEngine.


const _DICE_MIN := 1
const _DICE_MAX := 6
const _GIFT_CONTENTS: Array = [&"teleport", &"shield", &"extra_turn", &"push"]
const _GIFT_CELLS: Array = [3, 7, 12, 18, 24, 31]


# ── Помощни: симулират domain RNG потребление от §4.5 ─────────────────────────

## Един „ход“: зар + клетка за подарък + съдържание + параметър на power-up.
func _consume_turn_draws(rng: RandomSource) -> Dictionary:
	return {
		"dice": rng.next_int(_DICE_MIN, _DICE_MAX),
		"gift_cell": rng.pick(_GIFT_CELLS),
		"gift_content": rng.pick(_GIFT_CONTENTS),
		"power_up_param": rng.next_int(0, 100),
	}


func _run_match_stream(seed_val: int, turns: int) -> Array:
	var rng := SeededRandomSource.new(seed_val)
	var stream: Array = []
	for _i in turns:
		stream.append(_consume_turn_draws(rng))
	return stream


func _run_dice_stream(seed_val: int, rolls: int) -> Array:
	var rng := SeededRandomSource.new(seed_val)
	var stream: Array = []
	for _i in rolls:
		stream.append(rng.next_int(_DICE_MIN, _DICE_MAX))
	return stream


# ── Основен инвариант: еднакъв seed → еднакви резултати ───────────────────────

func test_same_seed_produces_identical_dice_sequence() -> void:
	const SEED := 12345
	var a := _run_dice_stream(SEED, 100)
	var b := _run_dice_stream(SEED, 100)
	assert_eq(a, b,
			"Еднакъв seed трябва да даде идентична зар последователност")
	assert_eq(a.size(), 100)
	for roll in a:
		assert_true(roll >= _DICE_MIN and roll <= _DICE_MAX,
				"зар трябва да е в [1, 6], got %s" % str(roll))


func test_same_seed_produces_identical_match_stream() -> void:
	## §4.5: един seed управлява зар, подаръци и power-up параметри.
	const SEED := 987654321
	var a := _run_match_stream(SEED, 40)
	var b := _run_match_stream(SEED, 40)
	assert_eq(a, b,
			"Еднакъв seed + еднакви domain извиквания → идентичен match stream")


func test_same_seed_identical_across_many_independent_runs() -> void:
	const SEED := 424242
	const RUNS := 5
	var reference := _run_match_stream(SEED, 25)
	for run_i in RUNS:
		var replay := _run_match_stream(SEED, 25)
		assert_eq(replay, reference,
				"Независим run #%d със същия seed трябва да съвпада" % run_i)


func test_same_seed_produces_identical_final_rng_state() -> void:
	const SEED := 55555
	const DRAWS := 30
	var rng_a := SeededRandomSource.new(SEED)
	var rng_b := SeededRandomSource.new(SEED)
	for _i in DRAWS:
		rng_a.next_int(1, 6)
		rng_b.next_int(1, 6)
	assert_eq(rng_a.get_state(), rng_b.get_state(),
			"След еднакви извиквания get_state() трябва да е идентичен")


func test_recreate_from_seed_alone_replays_sequence() -> void:
	## Replay без restore: само seed (DoD §16.3 основа).
	const SEED := 20260725
	var original := SeededRandomSource.new(SEED)
	var expected: Array = []
	for _i in 50:
		expected.append(original.next_int(0, 1000))

	var recreated := SeededRandomSource.new(SEED)
	var actual: Array = []
	for _i in 50:
		actual.append(recreated.next_int(0, 1000))

	assert_eq(actual, expected,
			"Нова инстанция със същия seed трябва да възпроизведе целия поток")


# ── MatchConfig.create_random_source() ────────────────────────────────────────

func test_match_config_same_rng_seed_produces_identical_results() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 777777

	var stream_a: Array = []
	var rng_a := cfg.create_random_source()
	for _i in 20:
		stream_a.append(_consume_turn_draws(rng_a))

	var stream_b: Array = []
	var rng_b := cfg.create_random_source()
	for _i in 20:
		stream_b.append(_consume_turn_draws(rng_b))

	assert_eq(stream_a, stream_b,
			"MatchConfig.create_random_source() с еднакъв rng_seed → еднакви резултати")


func test_serialized_match_config_same_seed_replays_identically() -> void:
	var cfg := MatchConfig.new()
	cfg.rng_seed = 314159
	cfg.add_seat(PlayerId.GREEN, MatchConfig.ControllerType.HUMAN, &"pig")
	cfg.add_seat(PlayerId.YELLOW, MatchConfig.ControllerType.AI, &"cow")
	var restored := MatchConfig.from_dict(cfg.to_dict())

	assert_eq(restored.rng_seed, cfg.rng_seed)
	assert_eq(
			_run_match_stream(cfg.rng_seed, 15),
			_run_match_stream(restored.rng_seed, 15),
			"Сериализиран MatchConfig.rng_seed трябва да даде същия stream")


# ── Независимост и контрол ────────────────────────────────────────────────────

func test_independent_instances_with_same_seed_stay_in_lockstep() -> void:
	var rng_a := SeededRandomSource.new(111)
	var rng_b := SeededRandomSource.new(111)
	for step in 40:
		var va := rng_a.next_int(1, 6)
		var vb := rng_b.next_int(1, 6)
		assert_eq(va, vb,
				"lockstep step %d: еднакъв seed трябва да държи инстанциите синхронни" % step)


func test_consuming_one_instance_does_not_affect_fresh_same_seed() -> void:
	var live := SeededRandomSource.new(999)
	for _i in 20:
		live.next_int(0, 1_000_000)
	var advanced_state := live.get_state()

	var fresh := SeededRandomSource.new(999)
	var initial_state := fresh.get_state()

	assert_ne(advanced_state["state"], initial_state["state"],
			"консумацията на една инстанция не трябва да измества нова със същия seed")
	var reference := SeededRandomSource.new(999)
	assert_eq(fresh.next_int(0, 1_000_000), reference.next_int(0, 1_000_000),
			"нова инстанция със същия seed започва от началото на последователността")


func test_different_seeds_produce_different_results() -> void:
	var a := _run_match_stream(1, 30)
	var b := _run_match_stream(2, 30)
	assert_ne(a, b,
			"Различни seed-ове трябва да дадат различни резултати (негативен контрол)")


func test_long_sequence_remains_deterministic() -> void:
	const SEED := 8675309
	const ROLLS := 500
	var a := _run_dice_stream(SEED, ROLLS)
	var b := _run_dice_stream(SEED, ROLLS)
	assert_eq(a, b,
			"Дълга последователност (500) трябва да остане детерминирана при еднакъв seed")


func test_polymorphic_random_source_same_seed_is_deterministic() -> void:
	var rng_a: RandomSource = SeededRandomSource.new(333)
	var rng_b: RandomSource = SeededRandomSource.new(333)
	var seq_a: Array = []
	var seq_b: Array = []
	for _i in 25:
		seq_a.append(rng_a.next_int(1, 6))
		seq_a.append(rng_a.pick(_GIFT_CONTENTS))
		seq_b.append(rng_b.next_int(1, 6))
		seq_b.append(rng_b.pick(_GIFT_CONTENTS))
	assert_eq(seq_a, seq_b,
			"Полиморфен RandomSource API трябва да пази детерминизма при еднакъв seed")
