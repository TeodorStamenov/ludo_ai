class_name StartMatchCommand
extends GameCommand
## Стартира нов мач с дадена конфигурация (docs/V1_ARCHITECTURE.md, раздел 4.3).
##
## Носи MatchConfig; GameEngine инициализира GameState от нея.

var config = null  # MatchConfig — typed as Variant to avoid circular preload


func _init(p_config = null) -> void:
	config = p_config
