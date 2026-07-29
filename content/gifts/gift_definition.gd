class_name GiftDefinition
extends Resource
## Authoring формат за запис от gift-pool-а: кой power-up и с каква
## относителна тежест участва в RNG избора при взимане на подарък
## (docs/V1_ARCHITECTURE.md §4.7 стъпка 3; docs/V1_GAME_DESIGN.md §4.1–4.2; #197).
##
## GiftState (game/domain/model/gift_state.gd) е рунтайм инстанция на дъската
## (gift_id + cell_id, съдържанието скрито до взимане); GiftDefinition е
## content-описанието на пула от възможни съдържания и техните тежести.
##
## Визуалният skin на самата (все още незакрита) кутия е в
## BoardThemeDefinition.gift_visual (§7) — GiftDefinition описва само
## съдържание, не презентация.

@export var power_up_id: StringName = &""
## Относителна тежест за RNG избор (§4.7 / AnimalPassive.modify_gift_spawn_weight).
@export var spawn_weight: float = 1.0


func is_valid() -> bool:
	if power_up_id == &"":
		return false
	return spawn_weight > 0.0
