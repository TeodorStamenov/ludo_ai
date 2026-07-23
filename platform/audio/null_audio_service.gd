class_name NullAudioService
extends RefCounted
## No-op Audio Service адаптер — placeholder до пълната реализация
## (docs/V1_ARCHITECTURE.md, раздел 8 — AudioService autoload).
##
## Пълната имплементация (music/SFX routing, AudioStreamPlayer pool,
## bus настройки) е обхваната от задача "Създаване на AudioService autoload".
##
## Всички методи са no-op и не предизвикват грешки, за да може
## Bootstrap да инициализира AudioService без да се нарушава стартът.

func play_sfx(_sound_id: StringName) -> void:
	pass


func play_music(_track_id: StringName) -> void:
	pass


func stop_music() -> void:
	pass


func set_sfx_volume(_linear: float) -> void:
	pass


func set_music_volume(_linear: float) -> void:
	pass


func set_sfx_enabled(_value: bool) -> void:
	pass


func set_music_enabled(_value: bool) -> void:
	pass
