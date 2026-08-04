# content/animals/

Дефиниции на животни-пионки като Godot Resource файлове (`.tres`).

## Състояние (v1: 6 животни)

| Файл          | Животно  | Пасив | Спрайт | Пасив реализиран |
|---|---|---|---|---|
| `pig.tres`    | Прасе    | Подаръци се появяват по-често в близост | `rss/pawns/Pig.png` | ✅ `PigPassive` |
| `cow.tres`    | Крава    | Противник я избутва само с 1 клетка | `rss/pawns/Cow.png` | ✅ `CowPassive` |
| `hen.tres`    | Кокошка  | Щитът трае 1 ход по-дълго | `rss/pawns/Chicken.png` | ⏳ неутрален (базов `AnimalPassive`) |
| `sheep.tres`  | Овца     | *непроектиран* | `rss/pawns/Sheep.png` | ⏳ неутрален (базов `AnimalPassive`) |
| `rabbit.tres` | Заек     | Телепортът е +1 клетка | ❌ липсва арт | ❌ |
| `dog.tres`    | Куче     | Избутването е 3 клетки вместо 2 | ❌ липсва арт | ❌ |

2 налични от старта (`AnimalId.STARTER`); останалите се отключват чрез кампанията.

⚠️ Заекът и Кучето още нямат спрайт, затова нямат `.tres` запис — 
`AnimalRegistry.definition_for()` връща `null` за тях, а `sprite_for()` пада 
към `AnimalId.DEFAULT`. `AnimalDefinitionValidator.validate_roster()` ще ги 
рапортува като `ERR_MISSING_ANIMAL`, докато не се появи арт.

⚠️ Пасивите още не влияят на реалната игра — няма content loader, който да 
изгради `ModifierPipeline` за играч, и `PushEffect` консултира само 
атакуващия (не целта, от която зависи пасивът на Кравата).

## Структура на AnimalDefinition Resource

```
animal_id      : StringName
display_name   : String
passive_script : GDScript     # extends AnimalPassive
sprite         : Texture2D
animations     : Dictionary   # още неизползвано — няма SpriteFrames инфраструктура
colorblind_icon: Texture2D    # още неавторизирано — PawnView пада към процедурна форма
```

Имплементация: `animal_definition.gd`; валидация: `animal_definition_validator.gd`;
търсене по `animal_id`: `animal_registry.gd`.
