# content/animals/

Дефиниции на животни-пионки като Godot Resource файлове (`.tres`).

## Планирани файлове (v1: 5–6 животни)

| Файл          | Животно  | Пасив |
|---|---|---|
| `pig.tres`    | Прасе    | Подаръци се появяват по-често в близост |
| `rabbit.tres` | Заек     | Телепортът е +1 клетка |
| `dog.tres`    | Куче     | Избутването е 3 клетки вместо 2 |
| `cow.tres`    | Крава    | Противник я избутва само с 1 клетка |
| `hen.tres`    | Кокошка  | Щитът трае 1 ход по-дълго |

2 налични от старта; останалите се отключват чрез кампанията.

## Структура на AnimalDefinition Resource

```
animal_id      : StringName
display_name   : String
passive_script : GDScript     # extends AnimalPassive
sprite         : Texture2D
animations     : Dictionary
colorblind_icon: Texture2D
```

Имплементация: задача "Създаване на AnimalDefinition модел".
