class_name GameCommand
extends RefCounted
## Базов клас за всички команди към GameEngine (docs/V1_ARCHITECTURE.md, раздел 4.3).
##
## Командата носи намерение, но не резултат.
## Например клиентът не изпраща „зарът е 6", а RollDiceCommand;
## резултатът се генерира от авторитетния RNG в GameEngine.
##
## Всяка команда ще носи match_id, player_id, sequence (и auth token за v2).
##
## Имплементации:
##   - StartMatchCommand  (commands/start_match_command.gd)
##   - RollDiceCommand    (commands/roll_dice_command.gd)
##   - MovePawnCommand    (commands/move_pawn_command.gd)
##
## Пълната имплементация е обхваната от задача "Създаване на базов GameCommand клас".
