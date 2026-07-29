# content/power_ups/

Дефиниции на power-up ефекти като Godot Resource файлове (`.tres`).

## Планирани файлове (v1: 4 ефекта)

| Файл                    | Ефект |
|---|---|
| `teleport_forward.tres` | Пионката скача 3–6 клетки напред (случайно) |
| `shield.tres`           | Пионката е имунизирана до следващия ход на притежателя |
| `extra_turn.tres`       | Играчът хвърля зара отново незабавно |
| `push.tres`             | Най-близката противникова пионка отстъпва 2 клетки назад |

## Структура на PowerUpDefinition Resource

```
power_up_id    : StringName
display_name   : String
resolver_script: GDScript     # extends PowerUpResolver
visual         : PackedScene  # тема-специфична GiftView презентация
```

Дизайн правило: всички v1 ефекти са неутрални до позитивни за взимащия —
подаръкът никога не е капан (активацията е принудителна).

Имплементация: `content/power_ups/power_up_definition.gd` (#196).
