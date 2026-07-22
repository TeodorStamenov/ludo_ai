class_name MediumAIPolicy
extends AIPolicy
## Средно ниво AI: балансиран между оценка и случайност
## (docs/V1_GAME_DESIGN.md, раздел 6).
##
## Оценява: взимане на противник, бягство от заплаха, взимане на подарък.
## Игнорира: стратегии за купчини и прибиране — за разлика от HardAIPolicy.
## При равни оценки избира произволно.
##
## Scoring ключове в state_view (произведен от GameState.to_view()):
##   "active_player":   { "pawns": [PawnView...] }
##   "opponents":       [{ "pawns": [PawnView...] }]
##   "gifts":           [{ "cell_id": StringName }]
##
## PawnView: { "pawn_id", "zone", "path_index", "cell_id", "shield_turns_remaining" }
##
## legal_actions е Array[GameCommand]. При MovePawnCommand scoring ползва
## "target_path_index" и "captures_opponent" полета ако са налични,
## иначе пада на случаен избор.

const SCORE_CAPTURE: int = 100
const SCORE_GIFT: int = 60
const SCORE_ESCAPE_THREAT: int = 80
const SCORE_DEFAULT: int = 0

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
		return SCORE_DEFAULT

	var score := SCORE_DEFAULT

	if action.has_meta("captures_opponent") and action.get_meta("captures_opponent"):
		score += SCORE_CAPTURE

	if action.has_meta("lands_on_gift") and action.get_meta("lands_on_gift"):
		score += SCORE_GIFT

	if action.has_meta("escapes_threat") and action.get_meta("escapes_threat"):
		score += SCORE_ESCAPE_THREAT

	return score
