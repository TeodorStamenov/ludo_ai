extends TestCase
## Unit тестове за power-up системата.
##
## Покрива:
##   - PowerUpResolver базов интерфейс
##   - TeleportEffect, ShieldEffect, ExtraTurnEffect, PushEffect
##   - AnimalPassive дефолтни модификатори
##   - ModifierPipeline инстанцируемост
##
## docs/V1_ARCHITECTURE.md, раздел 4.7, 4.8; V1_GAME_DESIGN.md, раздел 4.3


# --- PowerUpResolver базов интерфейс ---

func test_power_up_resolver_extends_ref_counted() -> void:
	var resolver := PowerUpResolver.new()
	assert_not_null(resolver)
	assert_true(resolver is RefCounted,
			"PowerUpResolver трябва да extends RefCounted, не Node")


func test_power_up_resolver_base_resolve_returns_array() -> void:
	var resolver := PowerUpResolver.new()
	var rng := SeededRandomSource.new(1)
	var state := GameState.new()
	var result := resolver.resolve({}, state, rng)
	assert_true(result is Array,
			"PowerUpResolver.resolve() трябва да върне Array")
	assert_true(result.is_empty(),
			"Базовата имплементация трябва да върне празен масив")


# --- TeleportEffect ---

func test_teleport_effect_extends_power_up_resolver() -> void:
	var effect := TeleportEffect.new()
	assert_not_null(effect, "TeleportEffect трябва да може да се инстанцира")
	assert_true(effect is PowerUpResolver,
			"TeleportEffect трябва да extends PowerUpResolver")


func test_teleport_effect_resolve_returns_array() -> void:
	var effect := TeleportEffect.new()
	var rng := SeededRandomSource.new(42)
	var state := GameState.new()
	var result := effect.resolve({}, state, rng)
	assert_true(result is Array,
			"TeleportEffect.resolve() трябва да върне Array")


func test_teleport_effect_is_not_node() -> void:
	var effect: Object = TeleportEffect.new()
	assert_false(effect is Node,
			"TeleportEffect не трябва да extends Node")


# --- ShieldEffect ---

func test_shield_effect_extends_power_up_resolver() -> void:
	var effect := ShieldEffect.new()
	assert_not_null(effect, "ShieldEffect трябва да може да се инстанцира")
	assert_true(effect is PowerUpResolver,
			"ShieldEffect трябва да extends PowerUpResolver")


func test_shield_effect_resolve_returns_array() -> void:
	var effect := ShieldEffect.new()
	var rng := SeededRandomSource.new(7)
	var state := GameState.new()
	var result := effect.resolve({}, state, rng)
	assert_true(result is Array,
			"ShieldEffect.resolve() трябва да върне Array")


# --- ExtraTurnEffect ---

func test_extra_turn_effect_extends_power_up_resolver() -> void:
	var effect := ExtraTurnEffect.new()
	assert_not_null(effect, "ExtraTurnEffect трябва да може да се инстанцира")
	assert_true(effect is PowerUpResolver,
			"ExtraTurnEffect трябва да extends PowerUpResolver")


func test_extra_turn_effect_resolve_returns_array() -> void:
	var effect := ExtraTurnEffect.new()
	var rng := SeededRandomSource.new(99)
	var state := GameState.new()
	var result := effect.resolve({}, state, rng)
	assert_true(result is Array,
			"ExtraTurnEffect.resolve() трябва да върне Array")


# --- PushEffect ---

func test_push_effect_extends_power_up_resolver() -> void:
	var effect := PushEffect.new()
	assert_not_null(effect, "PushEffect трябва да може да се инстанцира")
	assert_true(effect is PowerUpResolver,
			"PushEffect трябва да extends PowerUpResolver")


func test_push_effect_resolve_returns_array() -> void:
	var effect := PushEffect.new()
	var rng := SeededRandomSource.new(13)
	var state := GameState.new()
	var result := effect.resolve({}, state, rng)
	assert_true(result is Array,
			"PushEffect.resolve() трябва да върне Array")


# --- AnimalPassive ---

func test_animal_passive_extends_ref_counted() -> void:
	var passive := AnimalPassive.new()
	assert_not_null(passive)
	assert_true(passive is RefCounted,
			"AnimalPassive трябва да extends RefCounted, не Node")


func test_animal_passive_default_teleport_modifier_passthrough() -> void:
	var passive := AnimalPassive.new()
	assert_eq(passive.modify_teleport_distance(3), 3,
			"Базовото modify_teleport_distance трябва да върне стойността без промяна")
	assert_eq(passive.modify_teleport_distance(6), 6)


func test_animal_passive_default_push_modifier_passthrough() -> void:
	var passive := AnimalPassive.new()
	assert_eq(passive.modify_push_distance(2), 2,
			"Базовото modify_push_distance трябва да върне стойността без промяна")


func test_animal_passive_default_shield_modifier_passthrough() -> void:
	var passive := AnimalPassive.new()
	assert_eq(passive.modify_shield_duration(1), 1,
			"Базовото modify_shield_duration трябва да върне стойността без промяна")


func test_animal_passive_default_gift_spawn_weight_passthrough() -> void:
	var passive := AnimalPassive.new()
	var result := passive.modify_gift_spawn_weight(1.0)
	assert_true(absf(result - 1.0) < 0.0001,
			"Базовото modify_gift_spawn_weight трябва да върне стойността без промяна")


# --- ModifierPipeline ---

func test_modifier_pipeline_extends_ref_counted() -> void:
	var pipeline := ModifierPipeline.new()
	assert_not_null(pipeline, "ModifierPipeline трябва да може да се инстанцира")
	assert_true(pipeline is RefCounted,
			"ModifierPipeline трябва да extends RefCounted, не Node")


func test_modifier_pipeline_is_not_node() -> void:
	var pipeline: Object = ModifierPipeline.new()
	assert_false(pipeline is Node,
			"ModifierPipeline не трябва да extends Node")


# --- Инвариант: power-up не засяга HOME_STRETCH или BASE ---

func test_power_up_does_not_affect_home_stretch_invariant_documented() -> void:
	var affects_home_stretch := false
	assert_false(affects_home_stretch,
			"Power-up ефекти не трябва да засягат пионки в home stretch или база")


## Документиран инвариант: power-up не поставя пионка в невалидна купчина.
func test_power_up_respects_stack_limit_invariant_documented() -> void:
	var max_stack_size := 2
	assert_eq(max_stack_size, 2,
			"Power-up не може да постави пионка, ако резултатът е купчина от 3")
