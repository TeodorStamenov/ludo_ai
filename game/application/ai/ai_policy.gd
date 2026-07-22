class_name AIPolicy
extends RefCounted
## Интерфейс за стратегия за избор на ход от AI
## (docs/V1_ARCHITECTURE.md, раздел 5.3; V1_GAME_DESIGN.md, раздел 6).
##
## Договор:
##   choose_action(state_view: Dictionary, legal_actions: Array) -> GameCommand
##
## state_view е read-only речник на текущия GameState, произведен от
## GameState.to_view(). legal_actions е Array[GameCommand] — само валидни
## команди за активния играч в текущата TurnState фаза.
##
## AI оценява legal_actions по критерии: взимане, бягство от заплаха,
## подарък, образуване/пазене на купчина, прибиране. Различните нива
## балансират между оценка и случайност.
##
## Имплементации:
##   - EasyAIPolicy   — квази-случаен избор (ai/easy_ai_policy.gd)
##   - MediumAIPolicy — частична оценка   (ai/medium_ai_policy.gd)
##   - HardAIPolicy   — пълна оценка      (ai/hard_ai_policy.gd)


func choose_action(_state_view: Dictionary, _legal_actions: Array) -> GameCommand:
	push_error("AIPolicy.choose_action: не е имплементирано в базовия клас")
	return null
