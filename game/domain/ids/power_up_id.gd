class_name PowerUpId
extends RefCounted
## Стабилни идентификатори за четирите v1 power-up ефекта
## (docs/V1_GAME_DESIGN.md §4.3; docs/V1_ARCHITECTURE.md §4.7).
##
## Registry (game/domain/power_ups/power_up_registry.gd) свързва тези id-та
## с конкретния PowerUpResolver — няма match/if блок по низ низ различни места.

const TELEPORT_FORWARD: StringName = &"teleport_forward"
const SHIELD: StringName = &"shield"
const EXTRA_TURN: StringName = &"extra_turn"
const PUSH: StringName = &"push"

## Всички v1 power-up id-та, за равномерния RNG избор при взимане (§4.7 стъпка 3).
const ALL: Array[StringName] = [TELEPORT_FORWARD, SHIELD, EXTRA_TURN, PUSH]


static func is_valid(id: StringName) -> bool:
	return id in ALL
