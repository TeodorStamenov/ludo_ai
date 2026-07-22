# game/application/

Application слой — use case оркестрация между Domain и Presentation,
съгласно `docs/V1_ARCHITECTURE.md` (раздели 5 и 13).

## Правило за зависимости

Application може да импортира от `game/domain/` и `content/`.  
**Не импортира** от `game/presentation/`, `app/` или Godot-специфични Node типове.  
Platform adapters достига само чрез port интерфейсите в `ports/`.

```text
Presentation ──► Application ──► Domain
                     │
               ports/ (интерфейси)
                     │
               platform/ (имплементации)
```

## Структура

| Файл / директория         | Роля |
|---|---|
| `match_config.gd`         | Единственият договор между менютата и Game Screen |
| `match_session.gd`        | Притежава GameState, GameEngine, RNG; оркестрира мача |
| `match_factory.gd`        | Строи MatchSession от MatchConfig |
| `command_bus.gd`          | Единственото входно гнездо за GameCommand-и |
| `event_queue.gd`          | Буферира DomainEvent-и за Presentation |
| `controller/`             | PlayerController (интерфейс), Human, AI, Remote |
| `ai/`                     | AIPolicy (интерфейс), Easy, Medium, Hard имплементации |
| `ports/`                  | Интерфейси към persistence, ads, settings, telemetry |

## MatchSession не е singleton

Създава се за конкретен мач от `MatchFactory` и се освобождава след Results.  
`AppFlow` (в `app/`) управлява жизнения му цикъл.

## Файловете са scaffold

Отделните класове се имплементират в собствени задачи от roadmap-а
(issues #20–#131 и #181–#195).
