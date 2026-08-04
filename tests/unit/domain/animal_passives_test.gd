extends TestCase
## Unit тестове за конкретните AnimalPassive имплементации (content/animals/README.md).
##
## Покрива: PigPassive (по-голямо gift spawn тегло), CowPassive (максимум 1
## клетка при избутване като цел). И двата са изолирани, тествани градивни
## елементи — wiring в GiftRules / PushEffect.target остава отделна задача
## (виж коментарите в pig_passive.gd / cow_passive.gd).


# --- PigPassive ---

func test_pig_passive_extends_animal_passive() -> void:
	var passive := PigPassive.new()
	assert_not_null(passive)
	assert_true(passive is AnimalPassive,
			"PigPassive трябва да extends AnimalPassive")


func test_pig_passive_increases_gift_spawn_weight() -> void:
	var passive := PigPassive.new()
	var result := passive.modify_gift_spawn_weight(1.0)
	assert_true(result > 1.0,
			"Прасето трябва да увеличава базовото gift spawn тегло")


func test_pig_passive_scales_proportionally_with_base() -> void:
	var passive := PigPassive.new()
	var doubled := passive.modify_gift_spawn_weight(2.0)
	var single := passive.modify_gift_spawn_weight(1.0)
	assert_true(absf(doubled - single * 2.0) < 0.0001,
			"Модификаторът трябва да е мултипликативен, не константна добавка")


func test_pig_passive_other_hooks_stay_passthrough() -> void:
	var passive := PigPassive.new()
	assert_eq(passive.modify_teleport_distance(4), 4,
			"Прасето не пипа телепорт разстоянието")
	assert_eq(passive.modify_push_distance(2), 2,
			"Прасето не пипа push разстоянието")
	assert_eq(passive.modify_shield_duration(1), 1,
			"Прасето не пипа продължителността на щита")


# --- CowPassive ---

func test_cow_passive_extends_animal_passive() -> void:
	var passive := CowPassive.new()
	assert_not_null(passive)
	assert_true(passive is AnimalPassive,
			"CowPassive трябва да extends AnimalPassive")


func test_cow_passive_caps_push_distance_at_one() -> void:
	var passive := CowPassive.new()
	assert_eq(passive.modify_push_distance(2), 1,
			"Кравата отстъпва само 1 клетка вместо базовите 2")


func test_cow_passive_never_increases_push_distance() -> void:
	var passive := CowPassive.new()
	assert_eq(passive.modify_push_distance(5), 1,
			"По-голяма базова стойност пак трябва да се ограничи до 1")
	assert_eq(passive.modify_push_distance(0), 0,
			"0 остава 0 — няма избутване, което да се ограничава")


func test_cow_passive_other_hooks_stay_passthrough() -> void:
	var passive := CowPassive.new()
	assert_eq(passive.modify_teleport_distance(4), 4,
			"Кравата не пипа телепорт разстоянието")
	assert_eq(passive.modify_shield_duration(1), 1,
			"Кравата не пипа продължителността на щита")
	assert_true(absf(passive.modify_gift_spawn_weight(1.0) - 1.0) < 0.0001,
			"Кравата не пипа gift spawn теглото")


# --- ModifierPipeline интеграция (verify chaining, mirrors power_up_test.gd конвенцията) ---

func test_pipeline_chains_pig_and_cow_together() -> void:
	var pipeline := ModifierPipeline.new()
	pipeline.add(PigPassive.new())
	pipeline.add(CowPassive.new())
	assert_true(pipeline.modify_gift_spawn_weight(1.0) > 1.0)
	assert_eq(pipeline.modify_push_distance(2), 1)
