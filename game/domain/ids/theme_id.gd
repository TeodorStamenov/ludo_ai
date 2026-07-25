class_name ThemeId
extends RefCounted
## Стабилни идентификатори за визуални теми на дъската (docs/V1_GAME_DESIGN.md §2 / §5.1,
## content/themes/, docs/V1_ARCHITECTURE.md §5.1: theme_id).
##
## MatchConfig носи theme_id. Темата е presentation-only: текстури, цветове,
## particles, звуци и gift skin. Смяната на тема не променя gameplay правилата.
##
## v1 обем: 2 теми; Jungle е налична от старта (STARTER), Desert се отключва
## през кампанията.

const JUNGLE: StringName = &"jungle"
const DESERT: StringName = &"desert"

## Подразбираща се тема за нов мач (Match Setup / MatchConfig._init).
const DEFAULT: StringName = JUNGLE

## Всички v1 theme_id.
const ALL: Array[StringName] = [JUNGLE, DESERT]

## Теми, налични от старта без кампанийно отключване.
const STARTER: Array[StringName] = [JUNGLE]

## Брой теми във v1.
const COUNT: int = 2


## Връща true ако id е един от валидните v1 theme_id.
static func is_valid(id: StringName) -> bool:
	return id == JUNGLE or id == DESERT


## Връща true ако темата е налична от старта (без unlock).
static func is_starter(id: StringName) -> bool:
	return id == JUNGLE
