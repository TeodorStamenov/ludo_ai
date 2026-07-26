class_name PlayerRankedEvent
extends DomainEvent
## Играч е класиран след прибиране на всичките си пионки (docs/V1_ARCHITECTURE.md,
## §4.1 / §4.4 / §11 / §12; docs/V1_GAME_DESIGN.md, §3.1 — победител = 1-во място;
## при 3–4 играчи мачът продължава за останалите места).
##
## Описва вече настъпил факт: GameEngine е извикал GameState.rank_player() след
## последната прибрана пионка. Носи player_id и rank (1-based) — не намерение и
## не UI текст / XP.
##
## Типична верига: PawnMoved → PawnFinished → PlayerRanked → … / MatchFinished.
## Presentation (Results / GameHUD) наблюдава събитието; не решава класирането
## (§3 / §8). ranking[] в GameState остава source of truth.
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "player_id" + "rank".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_ranked_dict.


## Класираният играч (PlayerId); празен преди попълване.
var player_id: StringName = &""
## Място 1..PlayerState.RANK_MAX; PlayerState.RANK_UNRANKED преди попълване.
var rank: int = PlayerState.RANK_UNRANKED


func _init(
		p_player_id: StringName = &"",
		p_rank: int = PlayerState.RANK_UNRANKED
) -> void:
	player_id = p_player_id
	rank = p_rank
	event_type = TYPE_PLAYER_RANKED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_ranked(
		p_player_id: StringName,
		p_rank: int,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PlayerRankedEvent:
	var event := PlayerRankedEvent.new(p_player_id, p_rank)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от GameState след rank_player(): чете PlayerState.rank за player_id.
## null state, некласиран / липсващ играч → празен/невалиден payload.
static func create_from_state(
		state: GameState,
		p_player_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> PlayerRankedEvent:
	if state == null or not PlayerId.is_valid(p_player_id):
		return create_ranked(&"", PlayerState.RANK_UNRANKED, p_command_sequence)
	if not state.is_ranked(p_player_id):
		return create_ranked(&"", PlayerState.RANK_UNRANKED, p_command_sequence)
	var player := state.get_player(p_player_id)
	if player == null or not player.is_ranked():
		return create_ranked(&"", PlayerState.RANK_UNRANKED, p_command_sequence)
	return create_ranked(p_player_id, player.rank, p_command_sequence)


## True ако envelope-ът е валиден, player_id е валиден PlayerId
## и rank е в [RANK_FIRST, RANK_MAX] (не UNRANKED).
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not PlayerId.is_valid(player_id):
		return false
	if rank < PlayerState.RANK_FIRST or rank > PlayerState.RANK_MAX:
		return false
	return true


## True ако класирането е 1-во място (победител по §3.1).
func is_winner() -> bool:
	return rank == PlayerState.RANK_FIRST


## JSON-safe Dictionary: envelope + player_id + rank.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["player_id"] = String(player_id)
	data["rank"] = rank
	return data


## Десериализация към PlayerRankedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_PLAYER_RANKED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_ranked_dict(data: Dictionary) -> PlayerRankedEvent:
	var event := PlayerRankedEvent.new(
			StringName(str(data.get("player_id", ""))),
			int(data.get("rank", PlayerState.RANK_UNRANKED)))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_PLAYER_RANKED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_ranked_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is PlayerRankedEvent):
		return false
	if not super.equals(other):
		return false
	var other_ranked := other as PlayerRankedEvent
	return player_id == other_ranked.player_id and rank == other_ranked.rank
