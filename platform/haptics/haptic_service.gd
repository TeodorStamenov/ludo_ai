class_name HapticService
extends RefCounted
## Port интерфейс за тактилна обратна връзка
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Presentation слоят (HapticFeedback node) делегира тук, за да не познава
## директно Android API. Domain не познава HapticService изобщо.
##
## Три нива на интензивност, съответстващи на gameplay ситуации:
##   vibrate_light()  — фини взаимодействия (движение на пионка)
##   vibrate_medium() — по-важни ситуации (взимане на подарък, хвърляне на зар)
##   vibrate_heavy()  — значими моменти (взета/прибрана пионка, финиш)
##
## set_enabled(false) деактивира всички вибрации — извиква се при
## SettingsService.haptics_enabled = false.
##
## Имплементации:
##   - platform/haptics/android_haptic_service.gd  — production (Android)
##   - platform/haptics/editor_haptic_stub.gd       — no-op (editor / тестове)

var _enabled: bool = true


func set_enabled(value: bool) -> void:
	_enabled = value


func is_enabled() -> bool:
	return _enabled


func vibrate_light() -> void:
	pass


func vibrate_medium() -> void:
	pass


func vibrate_heavy() -> void:
	pass
