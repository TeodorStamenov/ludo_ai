extends TestCase
## Unit тестове за StubAdsService.

var svc: StubAdsService
var _dismissed_count: int = 0
var _granted_count: int = 0


func setUp() -> void:
	svc = StubAdsService.new()
	_dismissed_count = 0
	_granted_count = 0
	svc.reward_dismissed.connect(_on_dismissed)
	svc.reward_granted.connect(_on_granted)


func _on_dismissed() -> void:
	_dismissed_count += 1


func _on_granted(_bonus: Dictionary) -> void:
	_granted_count += 1


func test_is_ad_never_available() -> void:
	assert_false(svc.is_ad_available(), "stub always returns false")


func test_request_emits_dismissed_immediately() -> void:
	svc.request_rewarded_ad()
	assert_eq(_dismissed_count, 1, "reward_dismissed emitted once")
	assert_eq(_granted_count, 0, "reward_granted not emitted")


func test_multiple_requests_all_emit_dismissed() -> void:
	svc.request_rewarded_ad()
	svc.request_rewarded_ad()
	svc.request_rewarded_ad()
	assert_eq(_dismissed_count, 3, "dismissed 3 times")


func test_available_bonus_types_not_empty() -> void:
	var types := svc.get_available_bonus_types()
	assert_true(types.size() > 0, "bonus types defined in base AdsService")
	assert_true(types[0].has("type"), "first bonus has 'type' key")
