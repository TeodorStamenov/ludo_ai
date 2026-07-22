class_name MovePawnCommand
extends GameCommand
## Заявка за преместване на пионка (docs/V1_ARCHITECTURE.md, раздел 4.3).
##
## Носи player_id и pawn_id; GameEngine изчислява дестинацията от
## текущия TurnState (хвърлен зар) и BoardDefinition.
## Валидно само в TurnState.AWAITING_MOVE за активния играч.

var pawn_id: StringName = &""


func _init(p_player_id: StringName = &"", p_pawn_id: StringName = &"") -> void:
	player_id = p_player_id
	pawn_id = p_pawn_id
