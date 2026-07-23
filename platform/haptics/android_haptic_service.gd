class_name AndroidHapticService
extends HapticService
## Android имплементация на HapticService
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Използва Input.vibrate_handheld() — наличен на всички мобилни платформи
## в Godot 4. За по-прецизни haptic паterns на Android (HapticFeedbackConstants)
## е необходим нативен плъгин — резервирано за по-късна задача.
##
## Продължителности (ms):
##   light  — 20 ms  (фини взаимодействия)
##   medium — 50 ms  (важни събития)
##   heavy  — 90 ms  (финиш, взимане)

const _DURATION_LIGHT_MS  := 20
const _DURATION_MEDIUM_MS := 50
const _DURATION_HEAVY_MS  := 90


func vibrate_light() -> void:
	if _enabled:
		Input.vibrate_handheld(_DURATION_LIGHT_MS)


func vibrate_medium() -> void:
	if _enabled:
		Input.vibrate_handheld(_DURATION_MEDIUM_MS)


func vibrate_heavy() -> void:
	if _enabled:
		Input.vibrate_handheld(_DURATION_HEAVY_MS)
