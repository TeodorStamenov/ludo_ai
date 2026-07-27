# game/application/

Application слой — use case оркестрация между Domain и Presentation,
съгласно `docs/V1_ARCHITECTURE.md` (раздели 5 и 13).

Walkthrough на целия мач (команди, класове, presentation gate):
`docs/MATCH_FLOW.md`.

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
| `event_queue.gd`          | FIFO буфер на DomainEvent-и; sequence acknowledge след presentation |
| `gameplay_journal.gd`     | Append-only journal на активния мач (replay / bug report / #132) |
| `deterministic_replay_runner.gd` | Headless replay от journal (seed + accepted commands → state hash / #137) |
| `match_simulator.gd`      | Headless пълен мач без сцена (AI + auto presentation gate / #139) |
| `controller/`             | PlayerController (интерфейс), Human, AI, Remote |
| `ai/`                     | AIPolicy (интерфейс), FirstLegal, Easy, Medium, Hard имплементации |
| `ports/`                  | Интерфейси към persistence, ads, settings, telemetry |

## MatchSession не е singleton

Създава се за конкретен мач от `MatchFactory` и се освобождава след Results.  
`AppFlow` (в `app/`) управлява жизнения му цикъл.

## Статус

`MatchSession` оркестрира мача според §5.2 (команди → GameEngine → events →
presentation gate → AI/human advance → MatchSummary). Външните команди влизат
само през `CommandBus.submit()` (HumanController.action_ready и AI advance).
`EventQueue` буферира DomainEvent-и FIFO; `events_presented` прави
`acknowledge(sequence)`. `GameplayJournal` се създава при start/restore (`get_journal()`); header-ът
записва MatchConfig, seed и content version (#133). Приетите и отхвърлените
команди (с причина) и state hash след всяка приета команда се записват в
journal при `receive_command` (#134–#136). `DeterministicReplayRunner` чете
journal-а (seed + accepted commands), прилага ги през `GameEngine` без
presentation gate и проверява state hash (#137). `MatchSimulator` върти
пълен AI мач без сцена: auto `events_presented` до `MATCH_FINISHED` (#139).
Останалите application класове се довършват в собствени roadmap задачи.
