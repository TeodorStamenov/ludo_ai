class_name HardAIPolicy
extends AIPolicy
## Трудно ниво AI: оценява всички стратегически критерии
## (docs/V1_GAME_DESIGN.md, раздел 6).
##
## Оценява:
##   - взимане на противник (най-висок приоритет)
##   - бягство от заплаха
##   - взимане на подарък
##   - образуване или запазване на купчина
##   - прибиране на пионка в home stretch
##   - придвижване напред (тай-бреак)
##
## Scoring ключове в action (GameCommand метаданни от GameEngine):
##   captures_opponent: bool
##   escapes_threat:    bool
##   lands_on_gift:     bool
##   forms_stack:       bool
##   enters_finish:     bool
##   target_path_index: int  (за тай-бреак)
##
## При равни оценки избира произволно (за да не е предсказуем).

const SCORE_CAPTURE: int = 200
const SCORE_ESCAPE: int = 150
const SCORE_GIFT: int = 100
const SCORE_FORM_STACK: int = 80
const SCORE_ENTER_FINISH: int = 120
const SCORE_FORWARD: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func choose_action(state_view: Dictionary, legal_actions: Array) -> GameCommand:
	if legal_actions.is_empty():
		return null

	var best_score: int = -1
	var best_actions: Array = []

	for action: GameCommand in legal_actions:
		var score := _score_action(state_view, action)
		if score > best_score:
			best_score = score
			best_actions = [action]
		elif score == best_score:
			best_actions.append(action)

	return best_actions[_rng.randi() % best_actions.size()]


func _score_action(_state_view: Dictionary, action: GameCommand) -> int:
	if not action is MovePawnCommand:
		return 0

	var score := 0

	if action.has_meta("captures_opponent") and action.get_meta("captures_opponent"):
		score += SCORE_CAPTURE

	if action.has_meta("escapes_threat") and action.get_meta("escapes_threat"):
		score += SCORE_ESCAPE

	if action.has_meta("lands_on_gift") and action.get_meta("lands_on_gift"):
		score += SCORE_GIFT

	if action.has_meta("forms_stack") and action.get_meta("forms_stack"):
		score += SCORE_FORM_STACK

	if action.has_meta("enters_finish") and action.get_meta("enters_finish"):
		score += SCORE_ENTER_FINISH

	if action.has_meta("target_path_index"):
		score += int(action.get_meta("target_path_index")) * SCORE_FORWARD

	return score
