class_name PowerUpResolver
extends RefCounted
## Интерфейс за power-up ефект (docs/V1_ARCHITECTURE.md, раздел 4.7).
##
## Договор:
##   resolve(context: PowerUpContext, state: GameState, rng: RandomSource) -> Array[DomainEvent]
##
## Pipeline при взимане на подарък:
##   1. Пионката завършва движение.
##   2. Проверява се подарък на крайната клетка.
##   3. Съдържанието се тегли чрез RNG.
##   4. Animal passive модифицира числовите параметри.
##   5. Ефектът се валидира.
##   6. Състоянието се променя и се излъчват събития.
##
## Няма match/if блок по power_up_id в различни скриптове; registry
## свързва power_up_id с конкретния resolver.
##
## Имплементации:
##   - TeleportEffect   (power_ups/teleport_effect.gd)
##   - ShieldEffect     (power_ups/shield_effect.gd)
##   - ExtraTurnEffect  (power_ups/extra_turn_effect.gd)
##   - PushEffect       (power_ups/push_effect.gd)
##
## Registry: PowerUpRegistry (power_ups/power_up_registry.gd) свързва
## PowerUpId → resolver instance — GameEngine никога не прави match/if по
## power_up_id (#207-#213).


## Прилага ефекта и връща поредицата от domain събития.
func resolve(context: PowerUpContext, state: GameState, rng: RandomSource) -> Array:
	return []  # override в имплементациите
