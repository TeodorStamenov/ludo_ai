class_name AdMobAdsService
extends AdsService
## AdMob rewarded реклами за Android export
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Изисква GodotAdMob плъгин (https://github.com/Poing-Studios/godot-admob-plugin).
## При липса на плъгин всички методи се държат като StubAdsService.
##
## Твърдо правило за v2: бонуси от реклами никога не важат в онлайн мачове.
##
## Конфигурация:
##   ad_unit_id — rewarded ad unit ID от AdMob конзолата
##               (за тест: "ca-app-pub-3940256099942544/5224354917")
##
## Privacy: изисква GDPR/UMP consent екран преди зареждане на реклами.

const _TEST_AD_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"

var ad_unit_id: String = _TEST_AD_UNIT_ID
var _admob: Node = null
var _ad_loaded: bool = false


func _init() -> void:
	_try_init_admob()


func _try_init_admob() -> void:
	if not Engine.has_singleton("AdMob"):
		push_warning("AdMobAdsService: AdMob singleton not found — running as stub")
		return
	_admob = Engine.get_singleton("AdMob")
	if _admob.has_signal("rewarded_ad_loaded"):
		_admob.rewarded_ad_loaded.connect(_on_ad_loaded)
	if _admob.has_signal("rewarded_ad_failed_to_load"):
		_admob.rewarded_ad_failed_to_load.connect(_on_ad_failed)
	if _admob.has_signal("rewarded_ad_earned_reward"):
		_admob.rewarded_ad_earned_reward.connect(_on_reward_earned)
	if _admob.has_signal("rewarded_ad_dismissed"):
		_admob.rewarded_ad_dismissed.connect(_on_ad_dismissed)
	_load_ad()


func is_ad_available() -> bool:
	return _admob != null and _ad_loaded


func request_rewarded_ad() -> void:
	if not is_ad_available():
		reward_dismissed.emit()
		return
	if _admob.has_method("show_rewarded"):
		_admob.show_rewarded()
	else:
		reward_dismissed.emit()


# --- AdMob callbacks ---

func _load_ad() -> void:
	if _admob and _admob.has_method("load_rewarded"):
		_admob.load_rewarded(ad_unit_id)


func _on_ad_loaded() -> void:
	_ad_loaded = true


func _on_ad_failed(_error_code: int) -> void:
	_ad_loaded = false


func _on_reward_earned(currency: String, amount: int) -> void:
	var available := get_available_bonus_types()
	var bonus: Dictionary = available[0] if not available.is_empty() else {}
	bonus["currency"] = currency
	bonus["amount"] = amount
	reward_granted.emit(bonus)
	_ad_loaded = false
	_load_ad()


func _on_ad_dismissed() -> void:
	_ad_loaded = false
	reward_dismissed.emit()
	_load_ad()
