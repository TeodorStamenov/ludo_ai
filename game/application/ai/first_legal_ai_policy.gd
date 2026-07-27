class_name FirstLegalAIPolicy
extends AIPolicy
## Детерминистична AI политика: винаги избира първото legal action.
##
## Предназначена за headless симулации и replay-стабилни тестове
## (docs/V1_ARCHITECTURE.md §12 / §16.1; roadmap #139).
## Заедно със SeededRandomSource дава еднакъв seed → еднакъв мач.


func choose_action(_state_view: Dictionary, legal_actions: Array) -> GameCommand:
	if legal_actions.is_empty():
		return null
	return legal_actions[0] as GameCommand
