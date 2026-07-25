class_name StartMatchCommand
extends GameCommand
## Стартира нов мач с дадена конфигурация (docs/V1_ARCHITECTURE.md, раздел 4.3).
##
## Носи MatchConfig; GameEngine инициализира GameState от нея.

var config: MatchConfig = null


func _init(p_config: MatchConfig = null) -> void:
	config = p_config
