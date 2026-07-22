class_name AdsService
extends RefCounted
## Port интерфейс за rewarded реклами (docs/V1_ARCHITECTURE.md, раздел 10).
##
## Domain не познава AdMob. Преди мач Application пита AdsService
## и при успешна награда добавя валидиран pre_match_bonus към MatchConfig.
##
## Твърдо правило за v2: бонуси от реклами никога не важат в онлайн мачове.
##
## pre_match_bonus речник (примери от V1_GAME_DESIGN.md раздел 5.4):
##   { "type": "shield_start",  "pawn_count": 1 }
##   { "type": "double_xp",     "duration_matches": 1 }
##
## Имплементации:
##   - platform/ads/stub_ads_service.gd   — editor и тестове (винаги unavailable)
##   - platform/ads/admob_ads_service.gd  — Android export

signal reward_granted(bonus: Dictionary)
signal reward_dismissed


func is_ad_available() -> bool:
	return false


func request_rewarded_ad() -> void:
	push_error("AdsService.request_rewarded_ad: не е имплементирано")
	reward_dismissed.emit()


func get_available_bonus_types() -> Array:
	return [
		{ "type": "shield_start", "label": "Щит за пионка" },
		{ "type": "double_xp",    "label": "Двойно XP" },
	]
