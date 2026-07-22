class_name TurnState
extends RefCounted
## Изрична state machine на хода (docs/V1_ARCHITECTURE.md, раздел 4.2).
##
## Фази:
##   MATCH_START → AWAITING_ROLL → AWAITING_MOVE → RESOLVING_MOVE
##   → RESOLVING_POWER_UP → TURN_END → AWAITING_ROLL → … → MATCH_FINISHED
##
## Пази: текуща фаза, хвърлен резултат, оставащи опити при всички пионки
## в база, право на допълнително хвърляне, валидни команди/пионки,
## пореден номер на хода.
##
## Пълната имплементация е обхваната от задача "Създаване на TurnState модел".
