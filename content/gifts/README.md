# content/gifts/

Тегловни записи за пула от възможни подаръчни съдържания като Godot Resource
файлове (`.tres`). Не бъркай с `game/domain/model/gift_state.gd` — това е
рунтайм инстанция на активен подарък на дъската (gift_id + cell_id), докато
`GiftDefinition` тук описва самия пул от възможни съдържания и относителните
им тежести за RNG избора (docs/V1_ARCHITECTURE.md §4.7 стъпка 3).

## Планирани файлове (v1: 4 записа, по един на power-up)

| Файл                       | power_up_id       |
|---|---|
| `teleport_forward.tres`    | `teleport_forward` |
| `shield.tres`              | `shield`            |
| `extra_turn.tres`          | `extra_turn`        |
| `push.tres`                | `push`              |

## Структура на GiftDefinition Resource

```
power_up_id  : StringName
spawn_weight : float
```

Визуалният skin на самата (все още незакрита) кутия е в
`BoardThemeDefinition.gift_visual` (`content/themes/`), не тук.

Имплементация: `content/gifts/gift_definition.gd` (#197).
