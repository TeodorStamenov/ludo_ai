class_name MatchFinishedEvent
extends DomainEvent
## Мачът е завършил с пълно класиране (docs/V1_ARCHITECTURE.md, §4.1 / §4.4 / §5.2 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 — победител = 1-во място; при 3–4 играчи ranking
## е стабилен след последното място).
##
## Описва вече настъпил факт: GameEngine е преместил GameState.phase → FINISHED
## след като всички активни играчи са в ranking[]. Носи match_id и финалния
## ranking (PlayerId, index 0 = 1-во) — не намерение, не UI текст / XP.
##
## Типична верига: … → PlayerRanked → MatchFinished.
## MatchSession наблюдава събитието и произвежда MatchSummary (§5.2);
## Presentation (Results) не решава края на мача (§3 / §8).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "match_id" + "ranking" (Array[String]).
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_finished_dict.


## Идентификатор на завършилия мач (MatchId); празен преди попълване.
var match_id: StringName = &""
## PlayerId в ред на класиране (0 = 1-во място); празен преди попълване.
var ranking: Array = []


func _init(
		p_match_id: StringName = &"",
		p_ranking: Array = []
) -> void:
	match_id = p_match_id
	ranking = _normalize_ranking(p_ranking)
	event_type = TYPE_MATCH_FINISHED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_finished(
		p_match_id: StringName,
		p_ranking: Array,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> MatchFinishedEvent:
	var event := MatchFinishedEvent.new(p_match_id, p_ranking)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от GameState след phase → FINISHED с пълен ranking.
## null state, незавършен мач или непълен/невалиден ranking → празен/невалиден payload.
static func create_from_state(
		state: GameState,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> MatchFinishedEvent:
	if state == null or not state.is_finished():
		return create_finished(&"", [], p_command_sequence)
	if state.ranking.size() != state.player_count():
		return create_finished(&"", [], p_command_sequence)
	if state.ranking.is_empty():
		return create_finished(&"", [], p_command_sequence)
	return create_finished(
			state.match_id,
			state.get_ranked_player_ids(),
			p_command_sequence)


## True ако envelope-ът е валиден, match_id е валиден MatchId,
## ranking има 2..4 уникални валидни PlayerId.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not MatchId.is_valid(match_id):
		return false
	var count: int = ranking.size()
	if count < GameState.MIN_PLAYERS or count > GameState.MAX_PLAYERS:
		return false
	var seen: Dictionary = {}
	for entry in ranking:
		var player_id := StringName(str(entry))
		if not PlayerId.is_valid(player_id):
			return false
		if seen.has(player_id):
			return false
		seen[player_id] = true
	return true


## PlayerId на победителя (ranking[0]), или &"" ако липсва.
func get_winner_id() -> StringName:
	if ranking.is_empty():
		return &""
	return StringName(str(ranking[0]))


## True ако player_id е 1-во място.
func is_winner(player_id: StringName) -> bool:
	return player_id != &"" and get_winner_id() == player_id


## 1-based място за player_id, или 0 ако липсва в ranking.
func get_rank_of(player_id: StringName) -> int:
	var id_str := String(player_id)
	for i in ranking.size():
		if str(ranking[i]) == id_str:
			return i + PlayerState.RANK_FIRST
	return PlayerState.RANK_UNRANKED


## Брой класирани играчи.
func player_count() -> int:
	return ranking.size()


## PlayerId в каноничен ред (копие).
func get_ranked_player_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in ranking:
		ids.append(StringName(str(entry)))
	return ids


## JSON-safe Dictionary: envelope + match_id + ranking като Array[String].
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["match_id"] = String(match_id)
	var ranked: Array = []
	for entry in ranking:
		ranked.append(str(entry))
	data["ranking"] = ranked
	return data


## Десериализация към MatchFinishedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_MATCH_FINISHED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_finished_dict(data: Dictionary) -> MatchFinishedEvent:
	var ranking_data = data.get("ranking", [])
	var ranking_raw: Array = ranking_data if ranking_data is Array else []
	var event := MatchFinishedEvent.new(
			StringName(str(data.get("match_id", ""))),
			ranking_raw)
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_MATCH_FINISHED
	return event


## Дълбоко копие през сериализация — без споделена референция към ranking.
func duplicate_event() -> DomainEvent:
	return from_finished_dict(to_dict())


## True ако envelope, match_id и ranking съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is MatchFinishedEvent):
		return false
	if not super.equals(other):
		return false
	var other_finished := other as MatchFinishedEvent
	if match_id != other_finished.match_id:
		return false
	if ranking.size() != other_finished.ranking.size():
		return false
	for i in ranking.size():
		if str(ranking[i]) != str(other_finished.ranking[i]):
			return false
	return true


static func _normalize_ranking(entries: Array) -> Array:
	var normalized: Array = []
	for entry in entries:
		normalized.append(StringName(str(entry)))
	return normalized
