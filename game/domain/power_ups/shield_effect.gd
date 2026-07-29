class_name ShieldEffect
extends PowerUpResolver
## Щит: пионката не може да бъде взета до началото на следващия ход на притежателя
## (docs/V1_GAME_DESIGN.md, §4.3; #209).
##
## Base продължителност: 1 (PawnState.apply_shield + TurnRules._tick_owner_shields
## намаляват с 1 при всяко начало на собствен ход — виж ShieldAppliedEvent).
## Animal passive може да удължи продължителността (напр. Кокошка: +1 ход) чрез
## ModifierPipeline.modify_shield_duration.

const BASE_DURATION := 1


func resolve(context: PowerUpContext, state: GameState, rng: RandomSource) -> Array:
	var events: Array = []
	var pawn := state.get_pawn(context.pawn_id)
	if pawn == null or not pawn.is_on_main_path():
		return events

	var duration: int = context.modifiers.modify_shield_duration(BASE_DURATION)
	if duration <= 0:
		return events

	pawn.apply_shield(duration)
	events.append(ShieldAppliedEvent.create_applied(
			pawn.pawn_id, duration, context.command_sequence))
	return events
