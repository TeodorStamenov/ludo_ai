class_name SaveMigrationPipeline
extends RefCounted
## Пренася суров envelope (прочетен от диск) към мигриран payload
## (docs/V1_ARCHITECTURE.md §9; #249).
##
## Две независими нива на версиониране:
##   envelope schema_version — версионира {schema_version, saved_at, payload}
##     формàта на самия файл (тук, ENVELOPE_SCHEMA_VERSION).
##   payload schema_version  — версионира вътрешната форма на payload-а
##     (SettingsData.SCHEMA_VERSION / ProfileData.SCHEMA_VERSION) — това
##     остава грижа на съответния модел (Model.from_dict() го извиква сам,
##     огледално на GameState.migrate_dict()).
##
## Днес envelope форматът е само версия 1, без реални миграционни стъпки —
## pipeline-ът е извлечен и тестван изолирано, за да има готово, доказано
## място за следваща стъпка, вместо тази логика да се пише за пръв път под
## натиск, когато форматът реално се промени.
##
## Единствената реална стъпка засега (0 → 1) хваща файлове, записани преди
## envelope wrapper-а изобщо да съществува (гол payload dict, без
## schema_version/saved_at/payload ключове) — досегашният код би ги изгубил
## тихо (връщаше {} за липсващ "payload" ключ).

const ENVELOPE_SCHEMA_VERSION := 1


## True ако envelope-ът не е от бъдеща, непозната версия.
static func is_envelope_supported(envelope: Dictionary) -> bool:
	return int(envelope.get("schema_version", 0)) <= ENVELOPE_SCHEMA_VERSION


## Мигрира envelope-а до ENVELOPE_SCHEMA_VERSION и връща само payload частта.
## Празен envelope → празен Dictionary. Бъдещи версии (> ENVELOPE_SCHEMA_VERSION)
## не се мигрират — payload-ът им се връща както е, за caller-а да прецени.
static func migrate_envelope(envelope: Dictionary) -> Dictionary:
	if envelope.is_empty():
		return {}
	var migrated: Dictionary = envelope.duplicate(true)
	var version: int = int(migrated.get("schema_version", 0))
	if version > ENVELOPE_SCHEMA_VERSION:
		var future_payload: Variant = migrated.get("payload", {})
		return future_payload if future_payload is Dictionary else {}
	while version < ENVELOPE_SCHEMA_VERSION:
		migrated = _migrate_envelope_step(migrated, version)
		version += 1
		migrated["schema_version"] = version
	var payload: Variant = migrated.get("payload", {})
	return payload if payload is Dictionary else {}


static func _migrate_envelope_step(envelope: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			# Pre-envelope файл: целият прочетен dict Е payload-ът, не wrapper.
			# "payload" ключ вече присъства → envelope-ът просто е бил записан
			# без изричен schema_version (defensive, не би трябвало да стане
			# при нормален _atomic_write, но не е причина да го изгубим).
			if envelope.has("payload"):
				return envelope
			return {"payload": envelope}
		_:
			return envelope
