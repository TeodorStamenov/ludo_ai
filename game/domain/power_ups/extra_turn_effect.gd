class_name ExtraTurnEffect
extends PowerUpResolver
## Още един ход: играчът незабавно получава право на допълнително хвърляне
## (docs/V1_GAME_DESIGN.md, §4.3; #210).
##
## Мутира turn.extra_roll_pending директно — TurnRules.resolve_after_power_up
## (извикан веднага след resolve() от GameEngine._apply_move_pawn) го проверява
## и превключва към AWAITING_ROLL вместо TURN_END, точно както при хвърлен
## зар 6 (YEL-013). Не произвежда собствено DomainEvent — PowerUpResolvedEvent
## + следващото TurnChanged/ValidMovesChanged вече го отразяват.


func resolve(context: PowerUpContext, state: GameState, rng: RandomSource) -> Array:
	if state == null or state.turn == null:
		return []
	var pawn := state.get_pawn(context.pawn_id)
	if pawn == null or not pawn.is_on_main_path():
		return []
	state.turn.grant_extra_roll()
	return []
