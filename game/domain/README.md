# game/domain/

Чистата игрова логика на Cosy Ludo, съгласно `docs/V1_ARCHITECTURE.md` (раздели 4 и 13).

## Ключово правило за зависимости

Domain **не познава** `Node`, сцени, сигнали, input, анимации, файлове, реклами или Android. Не импортира нищо от `game/application/`, `game/presentation/`, `platform/` или `app/`. Всичко тук може да се тества без стартиране на Godot сцена.

```text
Presentation ──► Application ──► Domain  ◄── (само Content дефиниции)
```

## Структура

| Директория   | Съдържание |
|---|---|
| `model/`     | `GameState`, `PlayerState`, `PawnState`, `TurnState`, `GiftState`, `MatchResult`, `MatchConfig`, `MatchConfigValidator`, `BoardDefinition`, `BoardDefinitionValidator` — стабилни data структури и валидация |
| `commands/`  | `GameCommand` и трите конкретни команди — носят намерение, не резултат |
| `events/`    | `DomainEvent` и конкретните факти за вече случили се промени |
| `rules/`     | `GameEngine` и отделните rule модули (движение, купчини, взимане, ход, финал) |
| `power_ups/` | `PowerUpResolver` интерфейс и четирите v1 ефекта |
| `modifiers/` | `AnimalPassive` интерфейс и `ModifierPipeline` |
| `rng/`       | `RandomSource` интерфейс и `SeededRandomSource` имплементация |

## Основен runtime поток

```text
GameCommand
    │
    ▼
GameEngine.validate_and_apply(state, command, rng)
    │
    ├──► нов GameState
    ├──► DomainEvent[]
    └──► CommandError (при невалиден ход)
```

## Файловете са scaffold

Всеки `.gd` файл тук е документиран scaffold. Отделните класове се имплементират в собствени задачи от roadmap-а (issues #29–#124).
