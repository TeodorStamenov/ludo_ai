extends TestCase
## Unit тестове за HapticService йерархията.
##
## AndroidHapticService не може да се тества headless (вибрацията изисква
## физическо устройство), затова тестваме само HapticService базовия клас
## и EditorHapticStub, плюс set_enabled логиката.

var base_svc: HapticService
var editor_stub: EditorHapticStub


func setUp() -> void:
	base_svc = HapticService.new()
	editor_stub = EditorHapticStub.new()


# --- HapticService base ---

func test_enabled_by_default() -> void:
	assert_true(base_svc.is_enabled(), "enabled by default")


func test_set_enabled_false() -> void:
	base_svc.set_enabled(false)
	assert_false(base_svc.is_enabled(), "disabled after set_enabled(false)")


func test_set_enabled_toggle() -> void:
	base_svc.set_enabled(false)
	base_svc.set_enabled(true)
	assert_true(base_svc.is_enabled(), "re-enabled")


func test_base_vibrate_methods_do_not_crash() -> void:
	base_svc.vibrate_light()
	base_svc.vibrate_medium()
	base_svc.vibrate_heavy()
	assert_true(true, "no crash from base vibrate calls")


# --- EditorHapticStub ---

func test_stub_is_instance_of_haptic_service() -> void:
	assert_true(editor_stub is HapticService, "EditorHapticStub extends HapticService")


func test_stub_enabled_by_default() -> void:
	assert_true(editor_stub.is_enabled(), "stub enabled by default")


func test_stub_vibrate_does_not_crash() -> void:
	editor_stub.vibrate_light()
	editor_stub.vibrate_medium()
	editor_stub.vibrate_heavy()
	assert_true(true, "no crash from stub vibrate calls")


func test_stub_set_enabled_respected() -> void:
	editor_stub.set_enabled(false)
	assert_false(editor_stub.is_enabled(), "stub respects set_enabled")
