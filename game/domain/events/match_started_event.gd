class_name MatchStartedEvent
extends DomainEvent
## Мачът е стартиран с дадена конфигурация (docs/V1_ARCHITECTURE.md, §4.4 / §5.1 / §11).
##
## Описва вече настъпил факт: StartMatchCommand е приет и GameEngine е
## инициализирал GameState. Носи match_id и MatchConfig — не намерение.
##
## Presentation / statistics / save наблюдават събитието без да дублират правилата.
## Match Setup и Campaign водят до един и същ MatchStarted през един MatchConfig (§16.7).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "match_id" + "config" (MatchConfig.to_dict()).
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_started_dict.

## Идентификатор на стартирания мач (MatchId); празен преди попълване.
var match_id: StringName = &""
## Конфигурацията, с която мачът е започнал; null преди попълване.
var config: MatchConfig = null


func _init(p_match_id: StringName = &"", p_config: MatchConfig = null) -> void:
	match_id = p_match_id
	config = p_config
	event_type = TYPE_MATCH_STARTED


## Фабрика с match_id + MatchConfig + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_started(
		p_match_id: StringName,
		p_config: MatchConfig,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> MatchStartedEvent:
	var event := MatchStartedEvent.new(p_match_id, p_config)
	event.command_sequence = p_command_sequence
	return event


## True ако envelope-ът е валиден, match_id е валиден MatchId
## и config е не-null валиден MatchConfig.
## Празен / счупен match_id или null / невалиден config → false.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not MatchId.is_valid(match_id):
		return false
	if config == null:
		return false
	return config.is_valid()


## JSON-safe Dictionary: envelope + match_id + вложен config payload.
## Липсващ config → празен Dictionary (round-trip → null config).
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["match_id"] = String(match_id)
	if config != null:
		data["config"] = config.to_dict()
	else:
		data["config"] = {}
	return data


## Десериализация към MatchStartedEvent. Липсващ/празен config → null.
## event_type винаги се форсира към TYPE_MATCH_STARTED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_started_dict(data: Dictionary) -> MatchStartedEvent:
	var event := MatchStartedEvent.new(
			StringName(str(data.get("match_id", ""))),
			null)
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_MATCH_STARTED
	var cfg_data = data.get("config", {})
	if cfg_data is Dictionary and not (cfg_data as Dictionary).is_empty():
		event.config = MatchConfig.from_dict(cfg_data)
	else:
		event.config = null
	return event


## Дълбоко копие през сериализация — без споделена референция към MatchConfig.
func duplicate_event() -> DomainEvent:
	return from_started_dict(to_dict())


## True ако envelope, match_id и MatchConfig payload съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is MatchStartedEvent):
		return false
	if not super.equals(other):
		return false
	var other_started := other as MatchStartedEvent
	if match_id != other_started.match_id:
		return false
	if config == null and other_started.config == null:
		return true
	if config == null or other_started.config == null:
		return false
	return config.equals(other_started.config)
