class_name RemoteController
extends PlayerController
## Placeholder за v2 remote player контролер
## (docs/V1_ARCHITECTURE.md, раздели 5.3, 11).
##
## Във v2 преобразува мрежово съобщение към GameCommand и го предава
## през CommandBus.submit() — без промяна в правилата или view event обработката.
##
## v2 трансформация:
##   HumanController → NetworkClient → Authoritative MatchSession → GameEngine
##
## is_autonomous() е true: MatchSession го третира като агент, който
## ще извика CommandBus.submit() сам когато получи мрежово съобщение.


func is_autonomous() -> bool:
	return true


func get_action(_state_view: Dictionary, _legal_actions: Array) -> GameCommand:
	push_error("RemoteController.get_action: не трябва да се извиква; " +
			"командата идва от мрежовия слой чрез CommandBus.submit()")
	return null
