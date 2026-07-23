extends TestCase
## Unit тестове за NullAudioService — no-op placeholder адаптер.
##
## Всички методи са no-op и не трябва да предизвикват грешки.

var svc: NullAudioService


func setUp() -> void:
	svc = NullAudioService.new()


func test_is_ref_counted() -> void:
	assert_true(svc is RefCounted, "NullAudioService extends RefCounted")


func test_play_sfx_does_not_crash() -> void:
	svc.play_sfx(&"coin")
	svc.play_sfx(&"")
	assert_true(true, "play_sfx no crash")


func test_play_music_does_not_crash() -> void:
	svc.play_music(&"menu_theme")
	svc.play_music(&"")
	assert_true(true, "play_music no crash")


func test_stop_music_does_not_crash() -> void:
	svc.stop_music()
	assert_true(true, "stop_music no crash")


func test_set_sfx_volume_does_not_crash() -> void:
	svc.set_sfx_volume(0.0)
	svc.set_sfx_volume(0.5)
	svc.set_sfx_volume(1.0)
	assert_true(true, "set_sfx_volume no crash")


func test_set_music_volume_does_not_crash() -> void:
	svc.set_music_volume(0.0)
	svc.set_music_volume(0.75)
	svc.set_music_volume(1.0)
	assert_true(true, "set_music_volume no crash")


func test_set_sfx_enabled_does_not_crash() -> void:
	svc.set_sfx_enabled(true)
	svc.set_sfx_enabled(false)
	assert_true(true, "set_sfx_enabled no crash")


func test_set_music_enabled_does_not_crash() -> void:
	svc.set_music_enabled(true)
	svc.set_music_enabled(false)
	assert_true(true, "set_music_enabled no crash")


func test_all_methods_chainable_without_state_change() -> void:
	svc.play_sfx(&"test")
	svc.play_music(&"test")
	svc.set_sfx_volume(0.3)
	svc.set_music_volume(0.7)
	svc.set_sfx_enabled(false)
	svc.set_music_enabled(false)
	svc.stop_music()
	assert_true(true, "sequence of calls does not crash")
