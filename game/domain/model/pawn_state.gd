class_name PawnState
extends RefCounted
## Логическо положение на пионка — не пикселна позиция (docs/V1_ARCHITECTURE.md, раздел 4.1).
##
## Полета: pawn_id, zone (BASE|MAIN_PATH|HOME_STRETCH|FINISHED),
##         path_index, cell_id, shield_turns_remaining
##
## cell_id е стабилен идентификатор; Presentation го преобразува към Vector2.
##
## Пълната имплементация е обхваната от задача "Създаване на PawnState модел".
