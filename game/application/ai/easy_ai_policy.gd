class_name EasyAIPolicy
extends AIPolicy
## Лесно ниво AI: избира произволно валидно действие от legal_actions
## (docs/V1_GAME_DESIGN.md, раздел 6).
##
## Играе квази-случайно без никаква оценка на позицията.
## Подходящо за начинаещи и за тестване на случайни мачове.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func choose_action(_state_view: Dictionary, legal_actions: Array) -> GameCommand:
	if legal_actions.is_empty():
		return null
	return legal_actions[_rng.randi() % legal_actions.size()]
