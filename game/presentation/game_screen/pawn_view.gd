class_name PawnView
extends Node2D
## Визуален представител на една пионка (docs/V1_ARCHITECTURE.md, раздел 6.3).
##
## Съдържа само:
##   - pawn_id                          — стабилен идентификатор
##   - визуален asset / animal / skin   — текстура или AnimatedSprite2D
##   - анимации: idle, selected, move, stack, sleep/home
##   - colorblind marker                — форма/икона освен цвят
##   - hit target за touch/mouse input
##
## Логическите in_base, path_index, shield, valid_move са в PawnState.
## PawnView не пази нито едно gameplay состояние.
##
## Пълната имплементация е обхваната от задача
## "Рефакториране на текущия pawn.gd до PawnView".
