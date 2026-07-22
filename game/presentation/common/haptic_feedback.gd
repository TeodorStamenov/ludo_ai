class_name HapticFeedback
extends Node
## Тактилна обратна връзка при gameplay събития на Android
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Делегира към HapticService (platform/haptics/), така Presentation
## не познава Android API директно.
##
## Включва се при: хвърляне на зар, взимане на пионка, взимане на подарък,
## завършване на пионка.
##
## Деактивира се напълно при SettingsService.haptics_enabled = false.
##
## Имплементации на HapticService:
##   - AndroidHapticService — production (platform/haptics/)
##   - EditorHapticStub     — в editor и тестове (no-op)
##
## Пълната имплементация е обхваната от задача "Създаване на HapticService интерфейс".
