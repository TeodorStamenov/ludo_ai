class_name GameEngine
extends RefCounted
## Централна точка на domain логиката (docs/V1_ARCHITECTURE.md, раздел 4, 14).
##
## Приема команда, валидира я спрямо текущия GameState и RandomSource,
## прилага я и връща Dictionary с полета:
##
##   accepted : bool
##   state    : GameState
##   events   : Array[DomainEvent]
##   error    : String    (празно при успех)
##
## GameEngine не познава Node, сцени, сигнали, input, анимации, файлове,
## реклами или Android. Може да се тества изцяло без зареждане на Godot сцена.
##
## За v1 state може да се мутира вътрешно за производителност, но публичният
## договор е „команда → ново наблюдаемо състояние + събития".
##
## Делегира правилата на:
##   - MoveRules    (rules/move_rules.gd)
##   - StackRules   (rules/stack_rules.gd)
##   - CaptureRules (rules/capture_rules.gd)
##   - TurnRules    (rules/turn_rules.gd)
##   - FinishRules  (rules/finish_rules.gd)
##
## Пълната имплементация е обхваната от задача "Създаване на базов GameEngine".


func apply_command(state: GameState, command: GameCommand, rng: RandomSource) -> Dictionary:
	return {"accepted": false, "state": state, "events": [], "error": "not_implemented"}
