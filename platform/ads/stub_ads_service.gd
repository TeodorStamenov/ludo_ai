class_name StubAdsService
extends AdsService
## Stub имплементация на AdsService за editor и тестове
## (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Рекламите винаги са недостъпни. Извикването на request_rewarded_ad()
## незабавно излъчва reward_dismissed, без да блокира.
##
## Използвай тази имплементация:
##   - при стартиране в Godot editor
##   - в headless unit тестове
##   - на платформи без AdMob (PC, iOS при v1)


func is_ad_available() -> bool:
	return false


func request_rewarded_ad() -> void:
	reward_dismissed.emit()
