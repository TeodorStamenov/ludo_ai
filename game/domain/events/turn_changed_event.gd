class_name TurnChangedEvent
extends DomainEvent
## Ходът е преминал към следващия активен играч (docs/V1_ARCHITECTURE.md, §4.4 / §11;
## docs/V1_GAME_DESIGN.md, §3.1 — допълнителен ход при 6 не произвежда TurnChanged).
##
## Описва вече настъпил факт: GameEngine е приключил хода на предишния играч
## (TURN_END) и е активирал следващия. Носи previous/new active_player_index и
## съответните PlayerId — не намерение и не UI текст.
##
## Типична верига: PawnMoved → … → TurnChanged.
## Extra roll / Extra Turn power-up остават при същия играч — без TurnChanged.
##
## previous_player_index == PLAYER_INDEX_NONE описва първата активация след
## MatchStarted (няма предишен активен играч).
##
## Presentation (GameHUD / GamePresenter) получава събитието и обновява индикацията
## за текущ играч; не решава реда на ходовете (§3 / §6.1).
##
## Сериализация (journal / replay / AnimationQueue):
##   envelope полетата от DomainEvent + "previous_player_index" + "new_player_index"
##   + "previous_player_id" + "new_player_id".
##   DomainEvent.from_dict не диспечира към този subclass — ползвай from_changed_dict.


## Съвпада с GameState.ACTIVE_PLAYER_NONE — няма предишен активен играч.
const PLAYER_INDEX_NONE: int = -1


## Индекс в GameState.players[] на предишния активен играч; PLAYER_INDEX_NONE ако няма.
var previous_player_index: int = PLAYER_INDEX_NONE
## Индекс в GameState.players[] на новия активен играч; PLAYER_INDEX_NONE преди попълване.
var new_player_index: int = PLAYER_INDEX_NONE
## PlayerId на предишния активен играч; празен при PLAYER_INDEX_NONE.
var previous_player_id: StringName = &""
## PlayerId на новия активен играч; празен преди попълване.
var new_player_id: StringName = &""


func _init(
		p_previous_player_index: int = PLAYER_INDEX_NONE,
		p_new_player_index: int = PLAYER_INDEX_NONE,
		p_previous_player_id: StringName = &"",
		p_new_player_id: StringName = &""
) -> void:
	previous_player_index = p_previous_player_index
	new_player_index = p_new_player_index
	previous_player_id = p_previous_player_id
	new_player_id = p_new_player_id
	event_type = TYPE_TURN_CHANGED


## Фабрика с payload + envelope command_sequence.
## Отделно име от DomainEvent.create — GDScript изисква съвпадаща сигнатура при override.
static func create_changed(
		p_previous_player_index: int,
		p_new_player_index: int,
		p_previous_player_id: StringName,
		p_new_player_id: StringName,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> TurnChangedEvent:
	var event := TurnChangedEvent.new(
			p_previous_player_index,
			p_new_player_index,
			p_previous_player_id,
			p_new_player_id)
	event.command_sequence = p_command_sequence
	return event


## Фабрика от GameState след смяна на активния играч.
## previous_player_index е индексът преди прехода; новият се чете от state.
## null state, липсващ нов играч или съвпадащи индекси → празен/невалиден payload.
static func create_from_state(
		state: GameState,
		p_previous_player_index: int,
		p_command_sequence: int = COMMAND_SEQUENCE_UNSET
) -> TurnChangedEvent:
	if state == null:
		return create_changed(
				PLAYER_INDEX_NONE, PLAYER_INDEX_NONE, &"", &"", p_command_sequence)
	var new_index: int = state.active_player_index
	if new_index < 0 or new_index == p_previous_player_index:
		return create_changed(
				PLAYER_INDEX_NONE, PLAYER_INDEX_NONE, &"", &"", p_command_sequence)
	var new_player := state.get_player_by_index(new_index)
	if new_player == null:
		return create_changed(
				PLAYER_INDEX_NONE, PLAYER_INDEX_NONE, &"", &"", p_command_sequence)
	var prev_id: StringName = &""
	if p_previous_player_index >= 0:
		var prev_player := state.get_player_by_index(p_previous_player_index)
		if prev_player == null:
			return create_changed(
					PLAYER_INDEX_NONE, PLAYER_INDEX_NONE, &"", &"", p_command_sequence)
		prev_id = prev_player.player_id
	return create_changed(
			p_previous_player_index,
			new_index,
			prev_id,
			new_player.player_id,
			p_command_sequence)


## True ако envelope-ът е валиден, новият индекс/id са валидни,
## previous ≠ new, и previous id е празен точно когато previous index е NONE.
func is_valid() -> bool:
	if not super.is_valid():
		return false
	if new_player_index < 0:
		return false
	if previous_player_index < PLAYER_INDEX_NONE:
		return false
	if previous_player_index == new_player_index:
		return false
	if not PlayerId.is_valid(new_player_id):
		return false
	if previous_player_index == PLAYER_INDEX_NONE:
		return previous_player_id == &""
	if not PlayerId.is_valid(previous_player_id):
		return false
	if previous_player_id == new_player_id:
		return false
	return true


## True ако това е първата активация (след MatchStarted, без предишен играч).
func is_initial_activation() -> bool:
	return previous_player_index == PLAYER_INDEX_NONE


## PlayerId на новия активен играч.
func get_active_player_id() -> StringName:
	return new_player_id


## JSON-safe Dictionary: envelope + индекси + player_id полета.
func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["previous_player_index"] = previous_player_index
	data["new_player_index"] = new_player_index
	data["previous_player_id"] = String(previous_player_id)
	data["new_player_id"] = String(new_player_id)
	return data


## Десериализация към TurnChangedEvent. Липсващи полета → подразбиращи се стойности.
## event_type винаги се форсира към TYPE_TURN_CHANGED.
## Отделно от DomainEvent.from_dict (което не диспечира към subclass).
static func from_changed_dict(data: Dictionary) -> TurnChangedEvent:
	var event := TurnChangedEvent.new(
			int(data.get("previous_player_index", PLAYER_INDEX_NONE)),
			int(data.get("new_player_index", PLAYER_INDEX_NONE)),
			StringName(str(data.get("previous_player_id", ""))),
			StringName(str(data.get("new_player_id", ""))))
	event.command_sequence = int(data.get("command_sequence", COMMAND_SEQUENCE_UNSET))
	event.event_type = TYPE_TURN_CHANGED
	return event


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_event() -> DomainEvent:
	return from_changed_dict(to_dict())


## True ако envelope и payload полетата съвпадат.
func equals(other: DomainEvent) -> bool:
	if other == null or not (other is TurnChangedEvent):
		return false
	if not super.equals(other):
		return false
	var other_changed := other as TurnChangedEvent
	return (
			previous_player_index == other_changed.previous_player_index
			and new_player_index == other_changed.new_player_index
			and previous_player_id == other_changed.previous_player_id
			and new_player_id == other_changed.new_player_id
	)
