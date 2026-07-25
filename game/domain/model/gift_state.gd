class_name GiftState
extends RefCounted
## Активен подарък върху дъската в GameState.gifts[]
## (docs/V1_ARCHITECTURE.md, §4.1 / §4.4 / §4.7; docs/V1_GAME_DESIGN.md §4.1–4.2).
##
## Полета:
##   gift_id — стабилен идентификатор (GiftId формат "g_…")
##   cell_id — клетка от общото трасе (CellId); не screen позиция
##
## Правила:
##   - подаръкът се появява само върху общото трасе (PATH/SPAWN) — никога в
##     бази, home stretch или центъра; spawn rules / GameEngine го гарантират;
##   - съдържанието е скрито до взимане (GiftSpawned носи само gift_id + cell_id);
##   - power_up_id се тегли чрез RNG при колекциониране (§4.7), не се пази тук;
##   - никога два подаръка на една и съща клетка (уникалност по cell_id в gifts[]).
##
## Domain не използва Vector2 / NodePath — Presentation (GiftView) мапва cell_id.


## Стабилен идентификатор на подаръка (GiftId).
var gift_id: StringName = &""
## Клетка, върху която стои подаръкът (CellId); само main-path при валиден spawn.
var cell_id: StringName = &""


## Фабрика за пълно конфигуриран GiftState.
static func create(p_gift_id: StringName, p_cell_id: StringName) -> GiftState:
	var gift := GiftState.new()
	gift.gift_id = p_gift_id
	gift.cell_id = p_cell_id
	return gift


## Фабрика с генериран gift_id върху дадената клетка.
static func create_on_cell(p_cell_id: StringName) -> GiftState:
	return create(GiftId.generate(), p_cell_id)


func is_on_cell(p_cell_id: StringName) -> bool:
	return cell_id == p_cell_id


## Премества подаръка на друга клетка (рядко; spawn обикновено създава нов).
func set_cell(p_cell_id: StringName) -> void:
	cell_id = p_cell_id


## True ако полетата са в договорните self-contained граници (§4.1 / §12).
## Не проверява дали cell_id ∈ main_loop на BoardDefinition — това е за spawn rules.
## Центърът е забранен и тук, защото е единична именувана клетка извън трасето.
func is_valid() -> bool:
	if not GiftId.is_valid(gift_id):
		return false
	if not CellId.is_valid(cell_id):
		return false
	if CellId.is_center(cell_id):
		return false
	return true


## JSON-safe Dictionary: StringName → String. Без Vector2 / NodePath / power_up_id.
func to_dict() -> Dictionary:
	return {
		"gift_id": String(gift_id),
		"cell_id": String(cell_id),
	}


## Десериализация от Dictionary. Липсващи полета → подразбиращи се стойности.
static func from_dict(data: Dictionary) -> GiftState:
	var gift := GiftState.new()
	gift.gift_id = StringName(str(data.get("gift_id", "")))
	gift.cell_id = StringName(str(data.get("cell_id", "")))
	return gift


## Дълбоко копие през сериализация — без споделена референция.
func duplicate_state() -> GiftState:
	return from_dict(to_dict())


## True ако всички сериализируеми полета съвпадат.
func equals(other: GiftState) -> bool:
	if other == null:
		return false
	return gift_id == other.gift_id and cell_id == other.cell_id
