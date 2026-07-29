class_name GiftRules
extends RefCounted
## Правила за появяване на подаръци (docs/V1_ARCHITECTURE.md §4.1 / §4.5 / §4.7;
## docs/V1_GAME_DESIGN.md §4.1; #201-#203).
##
## Появяване: seeded интервал от приети команди (§4.5 — един seed управлява
## "интервали и клетки за подаръци", същия като зара). Клетката се тегли
## измежду свободните клетки от main_loop — main_loop по конструкция никога
## не включва бази/home stretch/център (#203), тук само изключваме клетки,
## които вече имат подарък.
##
## Взимането (#204/#206) е в GameEngine — там пионката вече е приложила хода
## си и се проверява само финалната ѝ клетка.

## Мин/макс брой команди между появяванията на подарък. Не са балансирани
## game-design стойности — избрани за разумен ритъм в рамките на типичен
## 2–4p мач (десетки до стотици команди); лесно се преместват в content по-късно.
const MIN_INTERVAL := 8
const MAX_INTERVAL := 15


## Първият threshold (command_sequence) — извиква се веднъж при старт на мача.
func schedule_first_spawn(rng: RandomSource, from_sequence: int = 0) -> int:
	return from_sequence + rng.next_int(MIN_INTERVAL, MAX_INTERVAL)


## True ако state.command_sequence вече е достигнал/подминал next_gift_spawn_at.
func is_spawn_due(state: GameState) -> bool:
	return (
			state != null
			and state.next_gift_spawn_at > 0
			and state.command_sequence >= state.next_gift_spawn_at
	)


## Свободните клетки от main_loop, на които може да се появи подарък (#202/#203).
func free_spawn_cells(state: GameState) -> Array[StringName]:
	var free: Array[StringName] = []
	if state == null or not _uses_classic_board(state):
		return free
	for entry in Classic15x15Board.main_loop_cell_ids():
		var cell_id := StringName(str(entry))
		if state.get_gift_at(cell_id) == null:
			free.append(cell_id)
	return free


## Ако е due: презарежда следващия threshold, появява подарък на случайна
## свободна main_loop клетка и мутира state.gifts. Връща GiftSpawnedEvent,
## или null (не е due, или няма свободна клетка — threshold пак се презарежда,
## за да не проверяваме на всяка следваща команда докато дъската е пълна).
func spawn_if_due(
		state: GameState,
		rng: RandomSource,
		command_sequence: int
) -> GiftSpawnedEvent:
	if not is_spawn_due(state):
		return null
	state.next_gift_spawn_at = state.command_sequence + rng.next_int(MIN_INTERVAL, MAX_INTERVAL)
	var free := free_spawn_cells(state)
	if free.is_empty():
		return null
	var cell_id: StringName = rng.pick(free)
	var gift := GiftState.create_on_cell(cell_id, command_sequence)
	state.add_gift(gift)
	return GiftSpawnedEvent.create_from_state(gift, command_sequence)


func _uses_classic_board(state: GameState) -> bool:
	return (
			state.board_id == Classic15x15Board.BOARD_ID
			or state.board_id == BoardDefinition.DEFAULT_BOARD_ID
	)
