class_name PlayerId
extends RefCounted
## Стабилни идентификатори за четирите играчески места (seats).
##
## Цветовете съответстват на позициите в 15×15 дъската (docs/V1_ARCHITECTURE.md §4.6):
##   GREEN  — NW (горе-ляво,   grid col 2-3, row 2-3)
##   ORANGE — NE (горе-дясно,  grid col 11-12, row 2-3)
##   YELLOW — SE (долу-дясно,  grid col 11-12, row 11-12)
##   CYAN   — SW (долу-ляво,   grid col 2-3, row 11-12)
##
## Тези константи са единственият авторитетен source of truth за player_id стойностите.
## Domain, Application и Presentation ги ползват вместо inline string literals.
##
## player_id ≠ color/team (PlayerState ги пази поотделно), но в класическото Ludo
## seat и цвят са 1:1 за v1 — затова константите носят цветовото название.

const GREEN: StringName  = &"green"
const ORANGE: StringName = &"orange"
const YELLOW: StringName = &"yellow"
const CYAN: StringName   = &"cyan"

## Всички 4 player_id в ред по seat (0=GREEN, 1=ORANGE, 2=YELLOW, 3=CYAN).
const ALL: Array[StringName] = [GREEN, ORANGE, YELLOW, CYAN]

## Брой играчески места на дъската.
const COUNT: int = 4


## Връща true ако id е един от четирите валидни player_id.
static func is_valid(id: StringName) -> bool:
	return id == GREEN or id == ORANGE or id == YELLOW or id == CYAN


## Връща player_id по seat индекс (0–3). При невалиден индекс връща &"".
static func from_seat(seat: int) -> StringName:
	if seat >= 0 and seat < ALL.size():
		return ALL[seat]
	return &""


## Връща seat индекс (0–3) за даден player_id. При невалиден ID връща -1.
static func to_seat(id: StringName) -> int:
	for i in ALL.size():
		if ALL[i] == id:
			return i
	return -1
