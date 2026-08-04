class_name AnimalId
extends RefCounted
## Стабилни идентификатори за животни-пионки (docs/V1_GAME_DESIGN.md §4.5,
## content/animals/, docs/V1_ARCHITECTURE.md §5.1: seats[].animal_id).
##
## Всеки seat в MatchConfig носи animal_id. Животното избира пасивните
## числови модификатори; темата/скинът не участват в правилата.
##
## v1 обем: 6 животни; 2 налични от старта (STARTER), останалите през кампанията.

const PIG: StringName    = &"pig"
const RABBIT: StringName = &"rabbit"
const DOG: StringName    = &"dog"
const COW: StringName    = &"cow"
const HEN: StringName    = &"hen"
const SHEEP: StringName  = &"sheep"

## Подразбиращо се животно за ново място (Match Setup / set_active_seats).
const DEFAULT: StringName = PIG

## Всички v1 animal_id.
const ALL: Array[StringName] = [PIG, RABBIT, DOG, COW, HEN, SHEEP]

## Животни, налични от старта без кампанийно отключване.
const STARTER: Array[StringName] = [PIG, RABBIT]

## Брой животни във v1.
const COUNT: int = 6


## Връща true ако id е един от валидните v1 animal_id.
static func is_valid(id: StringName) -> bool:
	return (
			id == PIG or id == RABBIT or id == DOG
			or id == COW or id == HEN or id == SHEEP
	)


## Връща true ако животното е налично от старта (без unlock).
static func is_starter(id: StringName) -> bool:
	return id == PIG or id == RABBIT
